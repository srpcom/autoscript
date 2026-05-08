#!/usr/bin/env python3
# ==========================================
# xray-api.py
# MODULE: PYTHON API BACKEND
# Menangani API request antara website billing dan server Xray, L2TP, SSH
# ==========================================

from flask import Flask, request, jsonify
import json, os, subprocess, uuid, datetime, base64
import urllib.request

app = Flask(__name__)

# Konfigurasi Path File Modular
API_KEY_FILE = '/usr/local/etc/xray/api_key.conf'
XRAY_CONF = '/usr/local/etc/xray/config.json'
EXP_FILE = '/usr/local/etc/xray/expiry.txt'
LOCK_FILE = '/usr/local/etc/xray/locked.json'
ENV_FILE = '/usr/local/etc/srpcom/env.conf'
BOT_CONF = '/usr/local/etc/xray/bot_setting.conf'

CHAP_SECRETS = '/etc/ppp/chap-secrets'
L2TP_EXP = '/usr/local/etc/srpcom/l2tp_expiry.txt'
IPSEC_PSK = "srpcom_vpn"

SSH_EXP = '/usr/local/etc/srpcom/ssh_expiry.txt'

# Fungsi untuk membaca Domain dan IP dari konfigurasi bash environment
def get_env(key):
    try:
        if not os.path.exists(ENV_FILE): return "UNKNOWN"
        with open(ENV_FILE, 'r') as f:
            for line in f:
                if line.startswith(f"{key}="): return line.split('=', 1)[1].strip().strip('"').strip("'")
    except: pass
    return "UNKNOWN"

DOMAIN = get_env("DOMAIN")
IP_ADD = get_env("IP_ADD")

def get_api_key():
    try:
        with open(API_KEY_FILE, 'r') as f: return f.read().strip()
    except: return "DEFAULT_KEY"

def check_auth():
    return request.headers.get('x-api-key') == get_api_key()

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

def generate_account_detail(protocol, user, uid, exp_date_str, is_trial=False):
    trial_txt = " TRIAL" if is_trial else ""
    if protocol == 'vmess':
        tls_dict = {"v":"2","ps":user,"add":DOMAIN,"port":"443","id":uid,"aid":"0","net":"ws","type":"none","host":DOMAIN,"path":"/vmessws","tls":"tls","sni":DOMAIN}
        none_tls_dict = {"v":"2","ps":user,"add":DOMAIN,"port":"80","id":uid,"aid":"0","net":"ws","type":"none","host":DOMAIN,"path":"/vmessws","tls":"","sni":""}
        link_tls = "vmess://" + base64.b64encode(json.dumps(tls_dict, separators=(',', ':')).encode('utf-8')).decode('utf-8')
        link_none = "vmess://" + base64.b64encode(json.dumps(none_tls_dict, separators=(',', ':')).encode('utf-8')).decode('utf-8')
        msg_web = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : {uid}\nNetwork : Websocket\nWebsocket Path : /vmessws\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : {link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : {link_none}\n━━━━━━━━━━━━━━━━━━━━\n"
        msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : `{uid}`\nNetwork : Websocket\nWebsocket Path : /vmessws\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : `{link_tls}`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : `{link_none}`\n━━━━━━━━━━━━━━━━━━━━\n"
    elif protocol == 'vless':
        link_tls = f"vless://{uid}@{DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host={DOMAIN}&type=ws&sni={DOMAIN}#{user}"
        link_none = f"vless://{uid}@{DOMAIN}:80?path=/vlessws&security=none&encryption=none&host={DOMAIN}&type=ws#{user}"
        msg_web = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : {uid}\nNetwork : Websocket\nWebsocket Path : /vlessws\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : {link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : {link_none}\n━━━━━━━━━━━━━━━━━━━━\n"
        msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : `{uid}`\nNetwork : Websocket\nWebsocket Path : /vlessws\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : `{link_tls}`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : `{link_none}`\n━━━━━━━━━━━━━━━━━━━━\n"
    elif protocol == 'trojan':
        link_tls = f"trojan://{uid}@{DOMAIN}:443?path=/trojanws&security=tls&host={DOMAIN}&type=ws&sni={DOMAIN}#{user}"
        msg_web = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPassword : {uid}\nNetwork : Websocket\nWebsocket Path : /trojanws\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : {link_tls}\n━━━━━━━━━━━━━━━━━━━━\n"
        msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPassword : `{uid}`\nNetwork : Websocket\nWebsocket Path : /trojanws\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : `{link_tls}`\n━━━━━━━━━━━━━━━━━━━━\n"
        
    msg_web_final = msg_web + f"Expired On : {exp_date_str} WIB"
    msg_tg_final = msg_tg + f"EXPIRED ON : {exp_date_str} WIB"
    return msg_web_final, msg_tg_final

# ===============================================
# ROUTE API: XRAY (VMESS, VLESS, TROJAN)
# ===============================================

@app.route('/user_legend/add-<protocol>ws', methods=['POST'])
def add_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    exp = int(data.get('exp', 30))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
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
    restart_xray()
    msg_web, msg_tg = generate_account_detail(protocol, user, uid, dt_str)
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_web})

@app.route('/user_legend/trial-<protocol>ws', methods=['POST'])
def trial_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    exp_min = int(data.get('exp', 60))
    user = f"trialsrp-{datetime.datetime.now().strftime('%m%d%H%M')}"
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
    restart_xray()
    msg_web, msg_tg = generate_account_detail(protocol, user, uid, dt_str, True)
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_web})

@app.route('/user_legend/del-<protocol>ws', methods=['DELETE'])
def del_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    cfg = load_json(XRAY_CONF)
    for ib in cfg.get('inbounds', []):
        if ib.get('protocol') == protocol:
            ib['settings']['clients'] = [c for c in ib['settings']['clients'] if c.get('email') != user]
    save_json(XRAY_CONF, cfg)
    if os.path.exists(EXP_FILE):
        with open(EXP_FILE, 'r') as f: lines = f.readlines()
        with open(EXP_FILE, 'w') as f:
            for line in lines:
                if not line.startswith(user + ' '): f.write(line)
    restart_xray()
    return jsonify({"stdout": f"Success: {user} deleted."})

@app.route('/user_legend/renew-<protocol>ws', methods=['POST'])
def renew_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    add_days = int(data.get('exp', 30))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    updated = False
    if os.path.exists(EXP_FILE):
        with open(EXP_FILE, 'r') as f: lines = f.readlines()
        with open(EXP_FILE, 'w') as f:
            for line in lines:
                if line.startswith(user + ' '):
                    parts = line.strip().split()
                    if len(parts) >= 3:
                        curr_dt = datetime.datetime.strptime(f"{parts[1]} {parts[2]}", '%Y-%m-%d %H:%M:%S')
                        new_dt = curr_dt + datetime.timedelta(days=add_days)
                        f.write(f"{user} {new_dt.strftime('%Y-%m-%d %H:%M:%S')}\n")
                        updated = True
                        continue
                f.write(line)
    if updated: return jsonify({"stdout": f"Success: {user} renewed."})
    return jsonify({"stdout": f"Error: User {user} not found."})

@app.route('/user_legend/detail-<protocol>ws', methods=['GET', 'POST'])
def detail_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    cfg = load_json(XRAY_CONF)
    uid = None
    for ib in cfg.get('inbounds', []):
        if ib.get('protocol') == protocol:
            for c in ib['settings']['clients']:
                if c.get('email') == user:
                    uid = c.get('id') if protocol != 'trojan' else c.get('password')
                    break
    if uid:
        exp_date_str = "Lifetime / No Exp"
        if os.path.exists(EXP_FILE):
            with open(EXP_FILE, 'r') as f:
                for line in f:
                    if line.startswith(user + ' '):
                        parts = line.strip().split(' ', 1)
                        if len(parts) > 1: exp_date_str = parts[1]
                        break
        msg_web, _ = generate_account_detail(protocol, user, uid, exp_date_str)
        return jsonify({"stdout": msg_web})
    return jsonify({"stdout": "Error: User not found"})

# ===============================================
# ROUTE API: L2TP / IPSEC
# ===============================================

@app.route('/user_legend/add-l2tp', methods=['POST'])
def api_add_l2tp():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    password = data.get('password', str(uuid.uuid4())[:8])
    exp = int(data.get('exp', 30))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    if os.path.exists(CHAP_SECRETS):
        with open(CHAP_SECRETS, 'r') as f:
            if f'"{user}"' in f.read(): return jsonify({"stdout": "Error: User already exists"}), 400
    dt = datetime.datetime.now() + datetime.timedelta(days=exp)
    dt_str = dt.strftime('%Y-%m-%d %H:%M:%S')
    with open(CHAP_SECRETS, 'a') as f: f.write(f'"{user}" l2tpd "{password}" *\n')
    if not os.path.exists(os.path.dirname(L2TP_EXP)): os.makedirs(os.path.dirname(L2TP_EXP), exist_ok=True)
    with open(L2TP_EXP, 'a') as f: f.write(f"{user} {password} {dt_str}\n")
    restart_l2tp()
    msg_web = f"━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nIPsec PSK : {IPSEC_PSK}\nUsername : {user}\nPassword : {password}\n━━━━━━━━━━━━━━━━━━━━\nExpired On : {dt_str} WIB"
    msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nIPsec PSK : `{IPSEC_PSK}`\nUsername : `{user}`\nPassword : `{password}`\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : {dt_str} WIB"
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_web})

@app.route('/user_legend/del-l2tp', methods=['DELETE'])
def api_del_l2tp():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    if os.path.exists(CHAP_SECRETS):
        with open(CHAP_SECRETS, 'r') as f: lines = f.readlines()
        with open(CHAP_SECRETS, 'w') as f:
            for line in lines:
                if not line.startswith(f'"{user}" l2tpd'): f.write(line)
    if os.path.exists(L2TP_EXP):
        with open(L2TP_EXP, 'r') as f: lines = f.readlines()
        with open(L2TP_EXP, 'w') as f:
            for line in lines:
                if not line.startswith(user + ' '): f.write(line)
    restart_l2tp()
    return jsonify({"stdout": f"Success: {user} deleted."})

@app.route('/user_legend/renew-l2tp', methods=['POST'])
def api_renew_l2tp():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    add_days = int(data.get('exp', 30))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    updated = False
    if os.path.exists(L2TP_EXP):
        with open(L2TP_EXP, 'r') as f: lines = f.readlines()
        with open(L2TP_EXP, 'w') as f:
            for line in lines:
                if line.startswith(user + ' '):
                    parts = line.strip().split()
                    if len(parts) >= 4:
                        curr_pass = parts[1]
                        curr_dt = datetime.datetime.strptime(f"{parts[2]} {parts[3]}", '%Y-%m-%d %H:%M:%S')
                        new_dt = curr_dt + datetime.timedelta(days=add_days)
                        f.write(f"{user} {curr_pass} {new_dt.strftime('%Y-%m-%d %H:%M:%S')}\n")
                        updated = True
                        continue
                f.write(line)
    if updated: return jsonify({"stdout": f"Success: {user} renewed."})
    return jsonify({"stdout": f"Error: User {user} not found."})

@app.route('/user_legend/detail-l2tp', methods=['GET', 'POST'])
def api_detail_l2tp():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    if os.path.exists(L2TP_EXP):
        with open(L2TP_EXP, 'r') as f:
            for line in f:
                if line.startswith(user + ' '):
                    parts = line.strip().split()
                    if len(parts) >= 4:
                        password = parts[1]
                        dt_str = f"{parts[2]} {parts[3]}"
                        msg_web = f"━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nIPsec PSK : {IPSEC_PSK}\nUsername : {user}\nPassword : {password}\n━━━━━━━━━━━━━━━━━━━━\nExpired On : {dt_str} WIB"
                        return jsonify({"stdout": msg_web})
    return jsonify({"stdout": "Error: User not found."})

# ===============================================
# ROUTE API: SSH & OVPN
# ===============================================

@app.route('/user_legend/add-ssh', methods=['POST'])
def api_add_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    password = data.get('password', str(uuid.uuid4())[:8])
    exp = int(data.get('exp', 30))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    
    # Check if user exists in linux
    check_user = subprocess.run(['id', user], capture_output=True)
    if check_user.returncode == 0: return jsonify({"stdout": "Error: User already exists"}), 400
    
    dt = datetime.datetime.now() + datetime.timedelta(days=exp)
    dt_str = dt.strftime('%Y-%m-%d %H:%M:%S')
    exp_date_only = dt.strftime('%Y-%m-%d')
    
    # Create linux user
    subprocess.run(['useradd', '-e', exp_date_only, '-s', '/bin/false', '-M', user])
    subprocess.run(f'echo "{user}:{password}" | chpasswd', shell=True)
    
    # Write to SSH Expiry list
    if not os.path.exists(os.path.dirname(SSH_EXP)): os.makedirs(os.path.dirname(SSH_EXP), exist_ok=True)
    with open(SSH_EXP, 'a') as f: f.write(f"{user} {password} {dt_str}\n")
    
    msg_web = f"━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : {user}\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nUsername : {user}\nPassword : {password}\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH : 22\nPort Dropbear : 109, 143\nPort SSH-WS TLS : 443 (Path: /sshws)\nPort SSH-WS NTLS : 80 (Path: /sshws)\n━━━━━━━━━━━━━━━━━━━━\nExpired On : {dt_str} WIB"
    msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nUsername : `{user}`\nPassword : `{password}`\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH : 22\nPort Dropbear : 109, 143\nPort SSH-WS TLS : 443 (Path: /sshws)\nPort SSH-WS NTLS : 80 (Path: /sshws)\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : {dt_str} WIB"
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_web})

@app.route('/user_legend/trial-ssh', methods=['POST'])
def api_trial_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    exp_min = int(data.get('exp', 60))
    user = f"trial-{datetime.datetime.now().strftime('%m%d%H%M')}"
    password = "1"
    
    dt = datetime.datetime.now() + datetime.timedelta(minutes=exp_min)
    dt_str = dt.strftime('%Y-%m-%d %H:%M:%S')
    exp_date_only = dt.strftime('%Y-%m-%d')
    
    subprocess.run(['useradd', '-e', exp_date_only, '-s', '/bin/false', '-M', user])
    subprocess.run(f'echo "{user}:{password}" | chpasswd', shell=True)
    
    if not os.path.exists(os.path.dirname(SSH_EXP)): os.makedirs(os.path.dirname(SSH_EXP), exist_ok=True)
    with open(SSH_EXP, 'a') as f: f.write(f"{user} {password} {dt_str}\n")
    
    msg_web = f"━━━━━━━━━━━━━━━━━━━━\n❖ TRIAL SSH ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\nUsername : {user}\nPassword : {password}\nDomain : {DOMAIN}\nIP : {IP_ADD}\n━━━━━━━━━━━━━━━━━━━━\nPort SSH/Dropbear : 22, 109, 143\nPort SSH-WS : 80, 443 (Path: /sshws)\n━━━━━━━━━━━━━━━━━━━━\nExpired On : {dt_str} WIB"
    msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ TRIAL SSH ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\nUsername : `{user}`\nPassword : `{password}`\nDomain : {DOMAIN}\nIP : {IP_ADD}\n━━━━━━━━━━━━━━━━━━━━\nPort SSH/Dropbear : 22, 109, 143\nPort SSH-WS : 80, 443 (Path: /sshws)\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : {dt_str} WIB"
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_web})

@app.route('/user_legend/del-ssh', methods=['DELETE'])
def api_del_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    
    # Hapus dari Linux
    subprocess.run(['userdel', '-f', user])
    
    # Hapus dari txt log
    if os.path.exists(SSH_EXP):
        with open(SSH_EXP, 'r') as f: lines = f.readlines()
        with open(SSH_EXP, 'w') as f:
            for line in lines:
                if not line.startswith(user + ' '): f.write(line)
    return jsonify({"stdout": f"Success: {user} deleted."})

@app.route('/user_legend/renew-ssh', methods=['POST'])
def api_renew_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    add_days = int(data.get('exp', 30))
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    
    updated = False
    if os.path.exists(SSH_EXP):
        with open(SSH_EXP, 'r') as f: lines = f.readlines()
        with open(SSH_EXP, 'w') as f:
            for line in lines:
                if line.startswith(user + ' '):
                    parts = line.strip().split()
                    if len(parts) >= 4:
                        curr_pass = parts[1]
                        curr_dt = datetime.datetime.strptime(f"{parts[2]} {parts[3]}", '%Y-%m-%d %H:%M:%S')
                        new_dt = curr_dt + datetime.timedelta(days=add_days)
                        dt_str = new_dt.strftime('%Y-%m-%d %H:%M:%S')
                        dt_only = new_dt.strftime('%Y-%m-%d')
                        
                        subprocess.run(['chage', '-E', dt_only, user])
                        f.write(f"{user} {curr_pass} {dt_str}\n")
                        updated = True
                        continue
                f.write(line)
    if updated: return jsonify({"stdout": f"Success: {user} renewed."})
    return jsonify({"stdout": f"Error: User {user} not found."})

@app.route('/user_legend/lock-ssh', methods=['POST'])
def api_lock_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    check = subprocess.run(['usermod', '-L', user], capture_output=True)
    if check.returncode == 0: return jsonify({"stdout": f"Success: {user} locked."})
    return jsonify({"stdout": "Error: User not found."})

@app.route('/user_legend/unlock-ssh', methods=['POST'])
def api_unlock_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    check = subprocess.run(['usermod', '-U', user], capture_output=True)
    if check.returncode == 0: return jsonify({"stdout": f"Success: {user} unlocked."})
    return jsonify({"stdout": "Error: User not found."})

@app.route('/user_legend/cek-ssh', methods=['GET', 'POST'])
def api_cek_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    # Count active users connected via ssh/dropbear (basic check)
    out = subprocess.run("ps aux | grep -iE 'dropbear|sshd' | grep -v grep | wc -l", shell=True, capture_output=True, text=True).stdout.strip()
    return jsonify({"stdout": f"Active SSH/Dropbear Processes: {out}, Domain: {DOMAIN}"})

# ===============================================
# ROUTE API: LAINNYA
# ===============================================

@app.route('/user_legend/change-uuid', methods=['POST'])
def change_uuid():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    uuidold = data.get('uuidold')
    uuidnew = data.get('uuidnew')
    cfg = load_json(XRAY_CONF)
    found = False
    for ib in cfg.get('inbounds', []):
        for c in ib['settings'].get('clients', []):
            if ib.get('protocol') == 'trojan':
                if c.get('password') == uuidold:
                    c['password'] = uuidnew
                    found = True
            else:
                if c.get('id') == uuidold:
                    c['id'] = uuidnew
                    found = True
    if found:
        save_json(XRAY_CONF, cfg)
        restart_xray()
        return jsonify({"stdout": "Success: UUID changed."})
    return jsonify({"stdout": "Error: Old UUID not found."})

@app.route('/user_legend/cek-xray', methods=['GET', 'POST'])
def cek_xray():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    out = subprocess.run(['systemctl', 'is-active', 'xray'], capture_output=True, text=True).stdout.strip()
    return jsonify({"stdout": f"Xray status: {out}, Domain: {DOMAIN}"})

@app.route('/user_legend/lock-xray', methods=['GET', 'POST'])
def lock_xray():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    cfg = load_json(XRAY_CONF)
    locked = load_json(LOCK_FILE) if os.path.exists(LOCK_FILE) else {}
    found = False
    for ib in cfg.get('inbounds', []):
        cls = ib['settings'].get('clients', [])
        for c in cls:
            if c.get('email') == user:
                locked[user] = {'protocol': ib['protocol'], 'data': c}
                cls.remove(c)
                found = True
                break
    if found:
        save_json(XRAY_CONF, cfg)
        save_json(LOCK_FILE, locked)
        restart_xray()
        return jsonify({"stdout": f"Success: {user} locked."})
    return jsonify({"stdout": "Error: User not found."})

@app.route('/user_legend/unlock-xray', methods=['GET', 'POST'])
def unlock_xray():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    locked = load_json(LOCK_FILE) if os.path.exists(LOCK_FILE) else {}
    if user in locked:
        info = locked[user]
        cfg = load_json(XRAY_CONF)
        for ib in cfg.get('inbounds', []):
            if ib.get('protocol') == info['protocol']:
                ib['settings']['clients'].append(info['data'])
        save_json(XRAY_CONF, cfg)
        del locked[user]
        save_json(LOCK_FILE, locked)
        restart_xray()
        return jsonify({"stdout": f"Success: {user} unlocked."})
    return jsonify({"stdout": "Error: User not locked."})

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
