#!/usr/bin/env python3
# ==========================================
# xray-api.py
# MODULE: PYTHON API BACKEND (MULTI-NODE SUPPORT)
# ==========================================

from flask import Flask, request, jsonify
import json, os, subprocess, uuid, datetime, base64, random, string
import urllib.request

app = Flask(__name__)

API_KEY_FILE = '/usr/local/etc/xray/api_key.conf'
API_AUTH_FILE = '/usr/local/etc/xray/api_auth.conf'
XRAY_CONF = '/usr/local/etc/xray/config.json'
EXP_FILE = '/usr/local/etc/xray/expiry.txt'
LIMIT_FILE = '/usr/local/etc/xray/limit.txt'
LOCKED_FILE = '/usr/local/etc/xray/locked.json'
ENV_FILE = '/usr/local/etc/srpcom/env.conf'
BOT_CONF = '/usr/local/etc/xray/bot_setting.conf'
LICENSE_FILE = '/usr/local/etc/srpcom/license.info'

SSH_EXP = '/usr/local/etc/srpcom/ssh_expiry.txt'
SSH_LIMIT = '/usr/local/etc/srpcom/ssh_limit.txt'
L2TP_EXP = '/usr/local/etc/srpcom/l2tp_expiry.txt'
CHAP_SECRETS = '/etc/ppp/chap-secrets'

def get_env(key):
    try:
        with open(ENV_FILE, 'r') as f:
            for line in f:
                if line.startswith(f"{key}="):
                    return line.split('=', 1)[1].strip().strip('"').strip("'")
    except: return "UNKNOWN"
    return "UNKNOWN"

DOMAIN = get_env("DOMAIN")
IP_ADD = get_env("IP_ADD")

def get_api_key():
    try:
        with open(API_KEY_FILE, 'r') as f: return f.read().strip()
    except: return "DEFAULT_KEY"

def check_auth():
    # Baca status ON/OFF
    auth_status = "OFF"
    try:
        if os.path.exists(API_AUTH_FILE):
            with open(API_AUTH_FILE, 'r') as f:
                auth_status = f.read().strip()
    except:
        pass
        
    # Jika status OFF, loloskan semua request (bypass auth)
    if auth_status == "OFF":
        return True
        
    # Jika status ON, verifikasi header x-api-key
    return request.headers.get('x-api-key') == get_api_key()

def is_license_active():
    try:
        if os.path.exists(LICENSE_FILE):
            with open(LICENSE_FILE, 'r') as f:
                content = f.read()
                if 'STATUS="EXPIRED"' in content:
                    return False
    except:
        pass
    return True

@app.before_request
def check_license_lock():
    # Mencegat semua request yang merubah database (add, del, renew, trial, lock, change)
    if request.method in ['POST', 'DELETE']:
        mutating_paths = ['/add-', '/del-', '/renew-', '/trial-', '/lock-', '/change-uuid']
        if any(p in request.path for p in mutating_paths):
            if not is_license_active():
                return jsonify({"stdout": "❌ AKSES DITOLAK: Masa aktif Lisensi Autoscript untuk Node Server ini telah habis. Eksekusi dibatalkan."}), 403

def load_json(p):
    if not os.path.exists(p): return {}
    with open(p, 'r') as f: return json.load(f)

def save_json(p, d):
    with open(p, 'w') as f: json.dump(d, f, indent=2)

def restart_xray(): subprocess.run(['systemctl', 'restart', 'xray'])
def restart_l2tp(): subprocess.run(['systemctl', 'restart', 'ipsec', 'xl2tpd'])

def send_telegram(text):
    try:
        bot_token, chat_id, autosend = "", "", "OFF"
        if os.path.exists(BOT_CONF):
            with open(BOT_CONF, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line.startswith('BOT_TOKEN='): bot_token = line.split('=', 1)[1].strip('"').strip("'")
                    elif line.startswith('CHAT_ID='): chat_id = line.split('=', 1)[1].strip('"').strip("'")
                    elif line.startswith('AUTOSEND_STATUS='): autosend = line.split('=', 1)[1].strip('"').strip("'")

        if autosend == "ON" and bot_token and chat_id:
            url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
            payload = {"chat_id": chat_id, "text": text, "parse_mode": "Markdown"}
            req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})
            urllib.request.urlopen(req, timeout=5)
    except: pass

def remove_from_txt(filepath, user):
    if not os.path.exists(filepath): return
    with open(filepath, "r") as f: lines = f.readlines()
    with open(filepath, "w") as f:
        for line in lines:
            if not line.startswith(user + " "): f.write(line)

# ==========================================
# REMOTE NODE FEATURES (MONITOR, LIST, BACKUP)
# ==========================================
@app.route('/user_legend/list-accounts/<protocol>', methods=['GET'])
def list_accounts(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    result = []
    if protocol in ['vmess', 'vless', 'trojan']:
        cfg = load_json(XRAY_CONF)
        target_users = []
        for ib in cfg.get('inbounds', []):
            if ib.get('protocol') == protocol:
                for c in ib['settings'].get('clients', []):
                    email = c.get('email')
                    if email: target_users.append(email)
        exp_data = {}
        if os.path.exists(EXP_FILE):
            with open(EXP_FILE, 'r') as f:
                for line in f:
                    p = line.strip().split()
                    if len(p) >= 2: exp_data[p[0]] = p[1]
        for u in target_users:
            exp = exp_data.get(u, "Lifetime")
            result.append(f"• `{u}` (Exp: {exp})")
    elif protocol == 'ssh' and os.path.exists(SSH_EXP):
        with open(SSH_EXP, 'r') as f:
            for line in f:
                p = line.strip().split()
                if len(p) >= 3: result.append(f"• `{p[0]}` (Exp: {p[2]})")
    elif protocol == 'l2tp' and os.path.exists(L2TP_EXP):
        with open(L2TP_EXP, 'r') as f:
            for line in f:
                p = line.strip().split()
                if len(p) >= 3: result.append(f"• `{p[0]}` (Exp: {p[2]})")

    if not result:
        return jsonify({"stdout": f"Belum ada akun aktif untuk protokol {protocol.upper()}."})
    text = f"📋 *LIST ACCOUNT {protocol.upper()}*\n━━━━━━━━━━━━━━━━━━━━\n" + "\n".join(result)
    return jsonify({"stdout": text})

@app.route('/user_legend/monitor-xray', methods=['GET'])
def monitor_xray():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    try:
        ip_data = {}
        if os.path.exists('/var/log/xray/access.log'):
            try:
                out = subprocess.run(['tail', '-n', '3000', '/var/log/xray/access.log'], capture_output=True, text=True)
                for line in out.stdout.splitlines():
                    if 'accepted' in line and '127.0.0.1' not in line:
                        parts = line.split()
                        if len(parts) >= 7:
                            user, ip = parts[6], parts[2].replace('tcp:', '').replace('udp:', '').split(':')[0]
                            if user not in ip_data: ip_data[user] = set()
                            ip_data[user].add(ip)
            except: pass

        stats = {}
        try:
            out = subprocess.run(['/usr/local/bin/xray', 'api', 'statsquery', '--server=127.0.0.1:10085'], capture_output=True, text=True)
            for item in json.loads(out.stdout).get('stat', []):
                np = item['name'].split('>>>')
                if len(np) >= 4 and np[0] == 'user':
                    user, t_type = np[1], np[3]
                    if user not in stats: stats[user] = {'downlink': 0, 'uplink': 0}
                    stats[user][t_type] = item.get('value', 0)
        except: pass

        limits = {}
        if os.path.exists(LIMIT_FILE):
            with open(LIMIT_FILE, 'r') as f:
                for line in f:
                    p = line.strip().split()
                    if len(p) >= 3: limits[p[0]] = {'ip': int(p[1]), 'quota': int(p[2])}

        all_users = set(list(stats.keys()) + list(ip_data.keys()))
        if not all_users: return jsonify({"stdout": "Belum ada data pemakaian Xray."})

        res = "📈 *XRAY MONITORING*\n━━━━━━━━━━━━━━━━━━━━\n"
        for u in sorted(all_users):
            active_ips = len(ip_data.get(u, set()))
            lim_ip = limits.get(u, {}).get('ip', 0)
            lim_ip_str = str(lim_ip) if lim_ip > 0 else 'Unli'
            
            tot_gb = ((stats.get(u, {}).get('downlink', 0) + stats.get(u, {}).get('uplink', 0)) / 1048576) / 1024
            lim_q = limits.get(u, {}).get('quota', 0)
            lim_q_str = f"{lim_q} GB" if lim_q > 0 else 'Unli'
            
            res += f"👤 *{u}*\n├ IP Aktif : {active_ips} / {lim_ip_str}\n└ Kuota : {tot_gb:.2f} GB / {lim_q_str}\n\n"
        return jsonify({"stdout": res})
    except Exception as e: return jsonify({"stdout": f"Error: {e}"})

@app.route('/user_legend/monitor-ssh', methods=['GET'])
def monitor_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    try:
        res = "💻 *SSH MONITORING*\n━━━━━━━━━━━━━━━━━━━━\n"
        out = subprocess.run('netstat -tnpa', shell=True, capture_output=True, text=True)
        active_users = []
        for line in out.stdout.splitlines():
            if 'ESTABLISHED' in line and ('dropbear' in line or 'sshd' in line):
                parts = line.split()
                if len(parts) >= 7:
                    pid = parts[6].split('/')[0]
                    ip = parts[4].split(':')[0]
                    try:
                        u_out = subprocess.run(['ps', '-o', 'user=', '-p', pid], capture_output=True, text=True)
                        user = u_out.stdout.strip()
                        if user and user != 'root': active_users.append(f"👤 `{user}` | 🌐 {ip}")
                    except: pass
        if not active_users: return jsonify({"stdout": res + "Belum ada user aktif."})
        return jsonify({"stdout": res + "\n".join(active_users)})
    except Exception as e: return jsonify({"stdout": f"Error: {e}"})

@app.route('/user_legend/sys-backup', methods=['GET'])
def sys_backup():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    now_str = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = f"/tmp/srpcom-backup-{now_str}.tar.gz"
    files = [XRAY_CONF, EXP_FILE, LIMIT_FILE, L2TP_EXP, SSH_EXP, SSH_LIMIT, CHAP_SECRETS]
    valid = [f for f in files if os.path.exists(f)]
    if valid:
        subprocess.run(['tar', '-czf', backup_file, '-C', '/'] + [f.lstrip('/') for f in valid])
        with open(backup_file, 'rb') as doc:
            encoded = base64.b64encode(doc.read()).decode('utf-8')
        os.remove(backup_file)
        return jsonify({"filename": f"srpcom-backup-{now_str}.tar.gz", "data": encoded})
    return jsonify({"stdout": "Tidak ada data untuk dibackup."})

# ==========================================
# XRAY ENDPOINTS
# ==========================================
def generate_account_detail(protocol, user, uid, exp_date_str, is_trial=False, limit_ip=0, limit_quota=0):
    trial_txt = " TRIAL" if is_trial else ""
    lim_ip_str = f"{limit_ip} IP" if limit_ip > 0 else "Unlimited"
    lim_q_str = f"{limit_quota} GB" if limit_quota > 0 else "Unlimited"
    
    if protocol == 'vmess':
        tls_dict = {"v":"2","ps":user,"add":DOMAIN,"port":"443","id":uid,"aid":"0","net":"ws","type":"none","host":DOMAIN,"path":"/vmessws","tls":"tls","sni":DOMAIN}
        none_tls_dict = {"v":"2","ps":user,"add":DOMAIN,"port":"80","id":uid,"aid":"0","net":"ws","type":"none","host":DOMAIN,"path":"/vmessws","tls":"","sni":""}
        link_tls = "vmess://" + base64.b64encode(json.dumps(tls_dict, separators=(',', ':')).encode('utf-8')).decode('utf-8')
        link_none = "vmess://" + base64.b64encode(json.dumps(none_tls_dict, separators=(',', ':')).encode('utf-8')).decode('utf-8')
    elif protocol == 'vless':
        link_tls = f"vless://{uid}@{DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host={DOMAIN}&type=ws&sni={DOMAIN}#{user}"
        link_none = f"vless://{uid}@{DOMAIN}:80?path=/vlessws&security=none&encryption=none&host={DOMAIN}&type=ws#{user}"
    elif protocol == 'trojan':
        link_tls = f"trojan://{uid}@{DOMAIN}:443?path=/trojanws&security=tls&host={DOMAIN}&type=ws&sni={DOMAIN}#{user}"
        link_none = ""

    msg_cli = (
        f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/{protocol.upper()} WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Remarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\n"
        f"Port TLS : 443\nPort NONE-TLS : 80\n{'Password' if protocol == 'trojan' else 'ID'} : {uid}\n"
        f"Network : Websocket\nWebsocket Path : /{protocol}ws\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Limit IP : {lim_ip_str}\nLimit Kuota : {lim_q_str}\n━━━━━━━━━━━━━━━━━━━━\n"
        f"LINK WS TLS : {link_tls}\n{'━━━━━━━━━━━━━━━━━━━━' if protocol != 'trojan' else ''}\n"
        f"{'LINK WS NONE-TLS : ' + link_none if protocol != 'trojan' else ''}\n"
        f"━━━━━━━━━━━━━━━━━━━━\nExpired On : {exp_date_str} WIB"
    )

    msg_tg = (
        f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/{protocol.upper()} WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Remarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\n"
        f"Port TLS : 443\nPort NONE-TLS : 80\n{'Password' if protocol == 'trojan' else 'ID'} : `{uid}`\n"
        f"Network : Websocket\nWebsocket Path : /{protocol}ws\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Limit IP : {lim_ip_str}\nLimit Kuota : {lim_q_str}\n━━━━━━━━━━━━━━━━━━━━\n"
        f"LINK WS TLS : `{link_tls}`\n{'━━━━━━━━━━━━━━━━━━━━' if protocol != 'trojan' else ''}\n"
        f"{'LINK WS NONE-TLS : `' + link_none + '`' if protocol != 'trojan' else ''}\n"
        f"━━━━━━━━━━━━━━━━━━━━\nExpired On : {exp_date_str} WIB"
    )
    
    return msg_cli, msg_tg

@app.route('/user_legend/add-<protocol>ws', methods=['POST'])
def add_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user, exp = data.get('user'), int(data.get('exp', 30))
    limit_ip, limit_quota = int(data.get('limit_ip', 0)), int(data.get('limit_quota', 0))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    
    # Cek dan Auto-increment nama user
    original_user = user
    counter = 2
    def is_xray_user(u):
        if not os.path.exists(EXP_FILE): return False
        with open(EXP_FILE, 'r') as f:
            for line in f:
                if line.startswith(u + " "): return True
        return False
    
    while is_xray_user(user):
        user = f"{original_user}{counter}"
        counter += 1
        
    uid = str(uuid.uuid4())
    dt = datetime.datetime.now() + datetime.timedelta(days=exp)
    cfg = load_json(XRAY_CONF)
    for ib in cfg.get('inbounds', []):
        if ib.get('protocol') == protocol:
            cls = ib['settings']['clients']
            if protocol == 'trojan': cls.append({'password': uid, 'email': user})
            else:
                c = {'id': uid, 'email': user}
                if protocol == 'vmess': c['alterId'] = 0
                cls.append(c)
    save_json(XRAY_CONF, cfg)
    dt_str = dt.strftime('%Y-%m-%d %H:%M:%S')
    with open(EXP_FILE, 'a') as f: f.write(f"{user} {dt_str}\n")
    with open(LIMIT_FILE, 'a') as f: f.write(f"{user} {limit_ip} {limit_quota}\n")
    restart_xray()
    
    msg_cli, msg_tg = generate_account_detail(protocol, user, uid, dt_str, False, limit_ip, limit_quota)
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_cli, "stdout_tg": msg_tg})

@app.route('/user_legend/trial-<protocol>ws', methods=['POST'])
def trial_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    
    exp_min = 60 
    limit_ip = int(data.get('limit_ip', 1))
    
    # PERBAIKAN: Format Jam-Menit-Detik + 1 Karakter Random
    rand_char = random.choice(string.ascii_lowercase)
    user = f"trialsrp-{datetime.datetime.now().strftime('%H%M%S')}{rand_char}"
    
    uid = str(uuid.uuid4())
    dt = datetime.datetime.now() + datetime.timedelta(minutes=exp_min)
    cfg = load_json(XRAY_CONF)
    for ib in cfg.get('inbounds', []):
        if ib.get('protocol') == protocol:
            cls = ib['settings']['clients']
            if protocol == 'trojan': cls.append({'password': uid, 'email': user})
            else:
                c = {'id': uid, 'email': user}
                if protocol == 'vmess': c['alterId'] = 0
                cls.append(c)
    save_json(XRAY_CONF, cfg)
    dt_str = dt.strftime('%Y-%m-%d %H:%M:%S')
    with open(EXP_FILE, 'a') as f: f.write(f"{user} {dt_str}\n")
    with open(LIMIT_FILE, 'a') as f: f.write(f"{user} {limit_ip} 1\n")
    restart_xray()
    
    msg_cli, msg_tg = generate_account_detail(protocol, user, uid, dt_str, True, limit_ip, 1)
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_cli, "stdout_tg": msg_tg})

@app.route('/user_legend/detail-<protocol>ws', methods=['GET', 'POST'])
def detail_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    cfg = load_json(XRAY_CONF)
    uid = None
    for ib in cfg.get('inbounds', []):
        if ib.get('protocol') == protocol:
            for c in ib['settings']['clients']:
                if c.get('email') == user:
                    uid = c.get('id') if protocol != 'trojan' else c.get('password')
                    break
    if uid:
        exp_date_str, limit_ip, limit_q = "Lifetime", 0, 0
        if os.path.exists(EXP_FILE):
            with open(EXP_FILE, 'r') as f:
                for line in f:
                    if line.startswith(user + ' '): exp_date_str = line.strip().split(' ', 1)[1]; break
        if os.path.exists(LIMIT_FILE):
            with open(LIMIT_FILE, 'r') as f:
                for line in f:
                    if line.startswith(user + ' '):
                        p = line.strip().split()
                        if len(p) >= 3: limit_ip, limit_q = int(p[1]), int(p[2]); break
                        
        msg_cli, msg_tg = generate_account_detail(protocol, user, uid, exp_date_str, False, limit_ip, limit_q)
        return jsonify({"stdout": msg_cli, "stdout_tg": msg_tg})
    return jsonify({"stdout": f"Error: User {user} tidak ditemukan!"})

@app.route('/user_legend/del-<protocol>ws', methods=['DELETE', 'POST'])
def del_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    cfg = load_json(XRAY_CONF)
    found = False
    for ib in cfg.get('inbounds', []):
        if ib.get('protocol') == protocol:
            cls = ib['settings'].get('clients', [])
            ib['settings']['clients'] = [c for c in cls if c.get('email') != user]
            if len(cls) != len(ib['settings']['clients']): found = True
    if found:
        save_json(XRAY_CONF, cfg)
        remove_from_txt(EXP_FILE, user)
        remove_from_txt(LIMIT_FILE, user)
        restart_xray()
        return jsonify({"stdout": f"✅ Akun Xray '{user}' berhasil dihapus!"})
    return jsonify({"stdout": f"❌ Gagal: Akun '{user}' tidak ditemukan."})

@app.route('/user_legend/renew-<protocol>ws', methods=['POST'])
def renew_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user, exp = (request.json or {}).get('user'), int((request.json or {}).get('exp', 30))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    dt_str = "Error"
    found = False
    if os.path.exists(EXP_FILE):
        with open(EXP_FILE, "r") as f: lines = f.readlines()
        with open(EXP_FILE, "w") as f:
            for line in lines:
                if line.startswith(user + " "):
                    dt = datetime.datetime.now() + datetime.timedelta(days=exp)
                    dt_str = dt.strftime('%Y-%m-%d %H:%M:%S')
                    f.write(f"{user} {dt_str}\n")
                    found = True
                else: f.write(line)
    if found:
        return jsonify({"stdout": f"✅ Akun '{user}' berhasil diperpanjang!\nExpired baru: {dt_str} WIB"})
    return jsonify({"stdout": f"❌ Gagal: Akun '{user}' tidak ditemukan di sistem Xray."})


# ==========================================
# SSH ENDPOINTS
# ==========================================
@app.route('/user_legend/add-ssh', methods=['POST'])
def add_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user, password, exp = data.get('user'), data.get('password', '123'), int(data.get('exp', 30))
    limit_ip = int(data.get('limit_ip', 0))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    
    # Cek dan Auto-increment nama user
    original_user = user
    counter = 2
    while subprocess.run(['id', user], capture_output=True).returncode == 0:
        user = f"{original_user}{counter}"
        counter += 1
    
    dt = datetime.datetime.now() + datetime.timedelta(days=exp)
    exp_date, exp_time = dt.strftime('%Y-%m-%d'), dt.strftime('%H:%M:%S')
    
    subprocess.run(['useradd', '-e', exp_date, '-s', '/bin/false', '-M', user])
    subprocess.run(f"echo '{user}:{password}' | chpasswd", shell=True)
    
    with open(SSH_EXP, 'a') as f: f.write(f"{user} {password} {exp_date} {exp_time}\n")
    with open(SSH_LIMIT, 'a') as f: f.write(f"{user} {limit_ip}\n")
    
    lim_str = f"{limit_ip} IP" if limit_ip > 0 else "Unlimited"
    
    msg_cli = (
        f"━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Remarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\n"
        f"Username : {user}\nPassword : {password}\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Port OpenSSH : 22\nPort Dropbear : 109, 143\n"
        f"Port SSH-WS TLS : 443 (Path: /sshws)\nPort SSH-WS NTLS : 80 (Path: /sshws)\n"
        f"Port UDP Custom : 7100, 7200, 7300\nPort OVPN UDP : 2200\nPort OVPN TCP : 1194\n"
        f"━━━━━━━━━━━━━━━━━━━━\nLimit IP : {lim_str}\n━━━━━━━━━━━━━━━━━━━━\n"
        f"LINK OVPN UDP : http://{DOMAIN}/ovpn/udp.ovpn\n"
        f"LINK OVPN TCP : http://{DOMAIN}/ovpn/tcp.ovpn\n━━━━━━━━━━━━━━━━━━━━\n"
        f"EXPIRED ON : {exp_date} {exp_time} WIB"
    )
    msg_tg = (
        f"━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Remarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\n"
        f"Username : `{user}`\nPassword : `{password}`\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Port OpenSSH : 22\nPort Dropbear : 109, 143\n"
        f"Port SSH-WS TLS : 443 (Path: /sshws)\nPort SSH-WS NTLS : 80 (Path: /sshws)\n"
        f"Port UDP Custom : 7100, 7200, 7300\nPort OVPN UDP : 2200\nPort OVPN TCP : 1194\n"
        f"━━━━━━━━━━━━━━━━━━━━\nLimit IP : {lim_str}\n━━━━━━━━━━━━━━━━━━━━\n"
        f"LINK OVPN UDP : `http://{DOMAIN}/ovpn/udp.ovpn`\n"
        f"LINK OVPN TCP : `http://{DOMAIN}/ovpn/tcp.ovpn`\n━━━━━━━━━━━━━━━━━━━━\n"
        f"EXPIRED ON : {exp_date} {exp_time} WIB"
    )
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_cli, "stdout_tg": msg_tg})

@app.route('/user_legend/del-ssh', methods=['DELETE', 'POST'])
def del_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    subprocess.run(['userdel', '-f', user])
    remove_from_txt(SSH_EXP, user)
    remove_from_txt(SSH_LIMIT, user)
    return jsonify({"stdout": f"✅ Akun SSH '{user}' berhasil dihapus!"})

@app.route('/user_legend/renew-ssh', methods=['POST'])
def renew_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user, exp = (request.json or {}).get('user'), int((request.json or {}).get('exp', 30))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    
    found, dt_str = False, ""
    if os.path.exists(SSH_EXP):
        with open(SSH_EXP, "r") as f: lines = f.readlines()
        with open(SSH_EXP, "w") as f:
            for line in lines:
                if line.startswith(user + " "):
                    parts = line.strip().split()
                    pw = parts[1] if len(parts) > 1 else "123"
                    dt = datetime.datetime.now() + datetime.timedelta(days=exp)
                    exp_date, exp_time = dt.strftime('%Y-%m-%d'), dt.strftime('%H:%M:%S')
                    f.write(f"{user} {pw} {exp_date} {exp_time}\n")
                    subprocess.run(['chage', '-E', exp_date, user])
                    dt_str = f"{exp_date} {exp_time}"
                    found = True
                else: f.write(line)
    if found: return jsonify({"stdout": f"✅ Akun SSH '{user}' diperpanjang!\nExpired baru: {dt_str} WIB"})
    return jsonify({"stdout": f"❌ Gagal: Akun SSH '{user}' tidak ditemukan."})

@app.route('/user_legend/detail-ssh', methods=['GET', 'POST'])
def detail_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    
    found = False
    msg_cli = f"❌ Akun SSH '{user}' tidak ditemukan."
    msg_tg = msg_cli
    
    if os.path.exists(SSH_EXP):
        with open(SSH_EXP, "r") as f:
            for line in f:
                if line.startswith(user + " "):
                    parts = line.strip().split()
                    pw, dt_str = parts[1], f"{parts[2]} {parts[3]}"
                    limit_ip = 0
                    if os.path.exists(SSH_LIMIT):
                        with open(SSH_LIMIT, "r") as fl:
                            for ll in fl:
                                if ll.startswith(user + " "): limit_ip = int(ll.strip().split()[1])
                    lim_str = f"{limit_ip} IP" if limit_ip > 0 else "Unlimited"
                    
                    msg_cli = (
                        f"━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\n"
                        f"Remarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\n"
                        f"Username : {user}\nPassword : {pw}\n━━━━━━━━━━━━━━━━━━━━\n"
                        f"Limit IP : {lim_str}\n━━━━━━━━━━━━━━━━━━━━\n"
                        f"LINK OVPN UDP : http://{DOMAIN}/ovpn/udp.ovpn\n"
                        f"LINK OVPN TCP : http://{DOMAIN}/ovpn/tcp.ovpn\n━━━━━━━━━━━━━━━━━━━━\n"
                        f"EXPIRED ON : {dt_str} WIB"
                    )
                    msg_tg = (
                        f"━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\n"
                        f"Remarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\n"
                        f"Username : `{user}`\nPassword : `{pw}`\n━━━━━━━━━━━━━━━━━━━━\n"
                        f"Limit IP : {lim_str}\n━━━━━━━━━━━━━━━━━━━━\n"
                        f"LINK OVPN UDP : `http://{DOMAIN}/ovpn/udp.ovpn`\n"
                        f"LINK OVPN TCP : `http://{DOMAIN}/ovpn/tcp.ovpn`\n━━━━━━━━━━━━━━━━━━━━\n"
                        f"EXPIRED ON : {dt_str} WIB"
                    )
                    found = True
                    break
    return jsonify({"stdout": msg_cli, "stdout_tg": msg_tg})

@app.route('/user_legend/trial-ssh', methods=['POST'])
def trial_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    
    exp_min = 60 
    limit_ip = int(data.get('limit_ip', 1))
    
    # PERBAIKAN: Format Jam-Menit-Detik + 1 Karakter Random
    rand_char = random.choice(string.ascii_lowercase)
    user = f"trialsrp-{datetime.datetime.now().strftime('%H%M%S')}{rand_char}"
    
    password = "1"
    
    dt = datetime.datetime.now() + datetime.timedelta(minutes=exp_min)
    exp_date, exp_time = dt.strftime('%Y-%m-%d'), dt.strftime('%H:%M:%S')
    
    subprocess.run(['useradd', '-e', exp_date, '-s', '/bin/false', '-M', user])
    subprocess.run(f"echo '{user}:{password}' | chpasswd", shell=True)
    
    with open(SSH_EXP, 'a') as f: f.write(f"{user} {password} {exp_date} {exp_time}\n")
    with open(SSH_LIMIT, 'a') as f: f.write(f"{user} {limit_ip}\n")
    
    msg_cli = (
        f"━━━━━━━━━━━━━━━━━━━━\n❖ TRIAL SSH & OVPN ❖\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Username : {user}\nPassword : {password}\n"
        f"Domain : {DOMAIN}\nIP : {IP_ADD}\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Limit IP : {limit_ip} IP\n━━━━━━━━━━━━━━━━━━━━\n"
        f"EXPIRED ON : {exp_date} {exp_time} WIB"
    )
    msg_tg = (
        f"━━━━━━━━━━━━━━━━━━━━\n❖ TRIAL SSH & OVPN ❖\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Username : `{user}`\nPassword : `{password}`\n"
        f"Domain : {DOMAIN}\nIP : {IP_ADD}\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Limit IP : {limit_ip} IP\n━━━━━━━━━━━━━━━━━━━━\n"
        f"EXPIRED ON : {exp_date} {exp_time} WIB"
    )
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_cli, "stdout_tg": msg_tg})

# ==========================================
# L2TP ENDPOINTS
# ==========================================
@app.route('/user_legend/add-l2tp', methods=['POST'])
def add_l2tp():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user, password, exp = data.get('user'), data.get('password', '123'), int(data.get('exp', 30))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    
    # Cek dan Auto-increment nama user
    original_user = user
    counter = 2
    def is_l2tp_user(u):
        if not os.path.exists(CHAP_SECRETS): return False
        with open(CHAP_SECRETS, 'r') as f:
            return f'"{u}" l2tpd' in f.read()
            
    while is_l2tp_user(user):
        user = f"{original_user}{counter}"
        counter += 1

    dt = datetime.datetime.now() + datetime.timedelta(days=exp)
    exp_date, exp_time = dt.strftime('%Y-%m-%d'), dt.strftime('%H:%M:%S')
    
    with open(CHAP_SECRETS, 'a') as f: f.write(f'"{user}" l2tpd "{password}" *\n')
    with open(L2TP_EXP, 'a') as f: f.write(f"{user} {password} {exp_date} {exp_time}\n")
    restart_l2tp()
    
    msg_cli = (
        f"━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Remarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\n"
        f"IPsec PSK : srpcom_vpn\nUsername : {user}\nPassword : {password}\n"
        f"━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : {exp_date} {exp_time} WIB"
    )
    msg_tg = (
        f"━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\n"
        f"Remarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\n"
        f"IPsec PSK : `srpcom_vpn`\nUsername : `{user}`\nPassword : `{password}`\n"
        f"━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : {exp_date} {exp_time} WIB"
    )
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_cli, "stdout_tg": msg_tg})

@app.route('/user_legend/del-l2tp', methods=['DELETE', 'POST'])
def del_l2tp():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    
    found = False
    if os.path.exists(CHAP_SECRETS):
        with open(CHAP_SECRETS, "r") as f: lines = f.readlines()
        with open(CHAP_SECRETS, "w") as f:
            for line in lines:
                if not line.startswith(f'"{user}" l2tpd'): f.write(line)
                else: found = True
    remove_from_txt(L2TP_EXP, user)
    if found:
        restart_l2tp()
        return jsonify({"stdout": f"✅ Akun L2TP '{user}' berhasil dihapus!"})
    return jsonify({"stdout": f"❌ Gagal: Akun L2TP '{user}' tidak ditemukan."})

@app.route('/user_legend/renew-l2tp', methods=['POST'])
def renew_l2tp():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user, exp = (request.json or {}).get('user'), int((request.json or {}).get('exp', 30))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    
    found, dt_str = False, ""
    if os.path.exists(L2TP_EXP):
        with open(L2TP_EXP, "r") as f: lines = f.readlines()
        with open(L2TP_EXP, "w") as f:
            for line in lines:
                if line.startswith(user + " "):
                    parts = line.strip().split()
                    pw = parts[1] if len(parts) > 1 else "123"
                    dt = datetime.datetime.now() + datetime.timedelta(days=exp)
                    exp_date, exp_time = dt.strftime('%Y-%m-%d'), dt.strftime('%H:%M:%S')
                    f.write(f"{user} {pw} {exp_date} {exp_time}\n")
                    dt_str = f"{exp_date} {exp_time}"
                    found = True
                else: f.write(line)
    if found: return jsonify({"stdout": f"✅ Akun L2TP '{user}' diperpanjang!\nExpired baru: {dt_str} WIB"})
    return jsonify({"stdout": f"❌ Gagal: Akun L2TP '{user}' tidak ditemukan."})

@app.route('/user_legend/detail-l2tp', methods=['GET', 'POST'])
def detail_l2tp():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    
    found = False
    msg_cli = f"❌ Akun L2TP '{user}' tidak ditemukan."
    msg_tg = msg_cli
    
    if os.path.exists(L2TP_EXP):
        with open(L2TP_EXP, "r") as f:
            for line in f:
                if line.startswith(user + " "):
                    parts = line.strip().split()
                    pw, dt_str = parts[1], f"{parts[2]} {parts[3]}"
                    
                    msg_cli = (
                        f"━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\n"
                        f"Remarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\n"
                        f"IPsec PSK : srpcom_vpn\nUsername : {user}\nPassword : {pw}\n"
                        f"━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : {dt_str} WIB"
                    )
                    msg_tg = (
                        f"━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\n"
                        f"Remarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\n"
                        f"IPsec PSK : `srpcom_vpn`\nUsername : `{user}`\nPassword : `{pw}`\n"
                        f"━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : {dt_str} WIB"
                    )
                    found = True
                    break
    return jsonify({"stdout": msg_cli, "stdout_tg": msg_tg})

@app.route('/user_legend/trial-l2tp', methods=['POST'])
def trial_l2tp():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    return jsonify({"stdout": "L2TP Trial created (Demo via API)"})

# ==========================================
# LOCK ENDPOINTS (AUTOKILL)
# ==========================================
@app.route('/user_legend/lock-ssh', methods=['POST'])
def lock_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    if user: subprocess.run(['usermod', '-L', user])
    return jsonify({"stdout": "Locked"})

@app.route('/user_legend/lock-xray', methods=['POST', 'GET'])
def lock_xray():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user') if request.method == 'POST' else request.args.get('user')
    if not user and request.json: user = request.json.get('user')
    
    if user:
        locked = {}
        if os.path.exists(LOCKED_FILE):
            with open(LOCKED_FILE, 'r') as f:
                try: locked = json.load(f)
                except: pass
        locked[user] = "Locked by Autokill"
        save_json(LOCKED_FILE, locked)
    return jsonify({"stdout": "Locked"})

@app.route('/user_legend/cek-xray', methods=['GET'])
def cek_xray():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    out = subprocess.run(['systemctl', 'is-active', 'xray'], capture_output=True, text=True).stdout.strip()
    return jsonify({"stdout": f"Xray status: {out}, Domain: {DOMAIN}"})

@app.route('/user_legend/change-uuid', methods=['POST'])
def change_uuid():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    old_uuid = data.get('uuidold')
    new_uuid = data.get('uuidnew')
    if not old_uuid or not new_uuid: return jsonify({"stdout": "Error: uuidold and uuidnew required"}), 400
    
    cfg = load_json(XRAY_CONF)
    found = False
    for ib in cfg.get('inbounds', []):
        if ib.get('protocol') in ['vmess', 'vless']:
            for c in ib['settings'].get('clients', []):
                if c.get('id') == old_uuid:
                    c['id'] = new_uuid
                    found = True
        elif ib.get('protocol') == 'trojan':
            for c in ib['settings'].get('clients', []):
                if c.get('password') == old_uuid:
                    c['password'] = new_uuid
                    found = True
                    
    if found:
        save_json(XRAY_CONF, cfg)
        restart_xray()
        return jsonify({"stdout": f"✅ UUID berhasil diganti menjadi {new_uuid}."})
    return jsonify({"stdout": f"❌ UUID lama '{old_uuid}' tidak ditemukan di sistem."})

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
