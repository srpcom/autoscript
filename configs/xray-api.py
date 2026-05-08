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

API_KEY_FILE = '/usr/local/etc/xray/api_key.conf'
XRAY_CONF = '/usr/local/etc/xray/config.json'
EXP_FILE = '/usr/local/etc/xray/expiry.txt'
LIMIT_FILE = '/usr/local/etc/xray/limit.txt'
LOCK_FILE = '/usr/local/etc/xray/locked.json'
ENV_FILE = '/usr/local/etc/srpcom/env.conf'
BOT_CONF = '/usr/local/etc/xray/bot_setting.conf'

# File kredensial tambahan
CHAP_SECRETS = '/etc/ppp/chap-secrets'
L2TP_EXP = '/usr/local/etc/srpcom/l2tp_expiry.txt'
IPSEC_PSK = "srpcom_vpn"

SSH_EXP = '/usr/local/etc/srpcom/ssh_expiry.txt'
SSH_LIMIT = '/usr/local/etc/srpcom/ssh_limit.txt'

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

def generate_account_detail(protocol, user, uid, exp_date_str, is_trial=False, limit_ip=0, limit_quota=0):
    trial_txt = " TRIAL" if is_trial else ""
    lim_ip_str = f"{limit_ip} IP" if limit_ip > 0 else "Unlimited"
    lim_q_str = f"{limit_quota} GB" if limit_quota > 0 else "Unlimited"
    
    # PERBAIKAN: Menambahkan Backticks pada nilai penting
    if protocol == 'vmess':
        tls_dict = {"v":"2","ps":user,"add":DOMAIN,"port":"443","id":uid,"aid":"0","net":"ws","type":"none","host":DOMAIN,"path":"/vmessws","tls":"tls","sni":DOMAIN}
        none_tls_dict = {"v":"2","ps":user,"add":DOMAIN,"port":"80","id":uid,"aid":"0","net":"ws","type":"none","host":DOMAIN,"path":"/vmessws","tls":"","sni":""}
        link_tls = "vmess://" + base64.b64encode(json.dumps(tls_dict, separators=(',', ':')).encode('utf-8')).decode('utf-8')
        link_none = "vmess://" + base64.b64encode(json.dumps(none_tls_dict, separators=(',', ':')).encode('utf-8')).decode('utf-8')
        
        msg_web = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : `{uid}`\nNetwork : Websocket\nWebsocket Path : /vmessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : {lim_ip_str}\nLimit Kuota : {lim_q_str}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : `{link_tls}`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : `{link_none}`\n━━━━━━━━━━━━━━━━━━━━\n"
        msg_tg = msg_web
        
    elif protocol == 'vless':
        link_tls = f"vless://{uid}@{DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host={DOMAIN}&type=ws&sni={DOMAIN}#{user}"
        link_none = f"vless://{uid}@{DOMAIN}:80?path=/vlessws&security=none&encryption=none&host={DOMAIN}&type=ws#{user}"
        msg_web = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : `{uid}`\nNetwork : Websocket\nWebsocket Path : /vlessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : {lim_ip_str}\nLimit Kuota : {lim_q_str}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : `{link_tls}`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : `{link_none}`\n━━━━━━━━━━━━━━━━━━━━\n"
        msg_tg = msg_web
        
    elif protocol == 'trojan':
        link_tls = f"trojan://{uid}@{DOMAIN}:443?path=/trojanws&security=tls&host={DOMAIN}&type=ws&sni={DOMAIN}#{user}"
        msg_web = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{user}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPassword : `{uid}`\nNetwork : Websocket\nWebsocket Path : /trojanws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : {lim_ip_str}\nLimit Kuota : {lim_q_str}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : `{link_tls}`\n━━━━━━━━━━━━━━━━━━━━\n"
        msg_tg = msg_web
        
    msg_web_final = msg_web + f"Expired On : {exp_date_str} WIB"
    return msg_web_final, msg_web_final

# ===============================================
# ROUTE API: XRAY, SSH, L2TP
# ===============================================

@app.route('/user_legend/add-<protocol>ws', methods=['POST'])
def add_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user = data.get('user')
    exp = int(data.get('exp', 30))
    limit_ip = int(data.get('limit_ip', 0))
    limit_quota = int(data.get('limit_quota', 0))
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
    with open(LIMIT_FILE, 'a') as f: f.write(f"{user} {limit_ip} {limit_quota}\n")
    restart_xray()
    msg_web, msg_tg = generate_account_detail(protocol, user, uid, dt_str, False, limit_ip, limit_quota)
    send_telegram(msg_tg)
    return jsonify({"stdout": msg_web})

@app.route('/user_legend/trial-<protocol>ws', methods=['POST'])
def trial_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    exp_min = int(data.get('exp', 60))
    limit_ip = int(data.get('limit_ip', 1))
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
    with open(LIMIT_FILE, 'a') as f: f.write(f"{user} {limit_ip} 1\n")
    restart_xray()
    msg_web, msg_tg = generate_account_detail(protocol, user, uid, dt_str, True, limit_ip, 1)
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
    for log_file in [EXP_FILE, LIMIT_FILE]:
        if os.path.exists(log_file):
            with open(log_file, 'r') as f: lines = f.readlines()
            with open(log_file, 'w') as f:
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
        limit_ip, limit_q = 0, 0
        if os.path.exists(EXP_FILE):
            with open(EXP_FILE, 'r') as f:
                for line in f:
                    if line.startswith(user + ' '):
                        parts = line.strip().split(' ', 1)
                        if len(parts) > 1: exp_date_str = parts[1]
                        break
        if os.path.exists(LIMIT_FILE):
            with open(LIMIT_FILE, 'r') as f:
                for line in f:
                    if line.startswith(user + ' '):
                        parts = line.strip().split()
                        if len(parts) >= 3:
                            limit_ip, limit_q = int(parts[1]), int(parts[2])
                        break
        msg_web, _ = generate_account_detail(protocol, user, uid, exp_date_str, False, limit_ip, limit_q)
        return jsonify({"stdout": msg_web})
    return jsonify({"stdout": "Error: User not found"})

@app.route('/user_legend/cek-xray', methods=['GET'])
def cek_xray():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    out = subprocess.run(['systemctl', 'is-active', 'xray'], capture_output=True, text=True).stdout.strip()
    return jsonify({"stdout": f"Xray status: {out}, Domain: {DOMAIN}"})

@app.route('/user_legend/cek-ssh', methods=['GET'])
def cek_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    out = subprocess.run("ps aux | grep -iE 'dropbear|sshd' | grep -v grep | wc -l", shell=True, capture_output=True, text=True).stdout.strip()
    return jsonify({"stdout": f"Active SSH/Dropbear Processes: {out}"})

@app.route('/user_legend/lock-ssh', methods=['POST'])
def lock_ssh():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = (request.json or {}).get('user')
    subprocess.run(['usermod', '-L', user])
    return jsonify({"stdout": f"Success: {user} locked."})

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
