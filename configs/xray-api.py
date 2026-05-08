#!/usr/bin/env python3
# ==========================================
# xray-api.py
# MODULE: PYTHON API BACKEND
# ==========================================

from flask import Flask, request, jsonify
import json, os, subprocess, uuid, datetime, base64
import urllib.request

app = Flask(__name__)

API_KEY_FILE = '/usr/local/etc/xray/api_key.conf'
XRAY_CONF = '/usr/local/etc/xray/config.json'
EXP_FILE = '/usr/local/etc/xray/expiry.txt'
LIMIT_FILE = '/usr/local/etc/xray/limit.txt'
ENV_FILE = '/usr/local/etc/srpcom/env.conf'
BOT_CONF = '/usr/local/etc/xray/bot_setting.conf'

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
    return request.headers.get('x-api-key') == get_api_key()

def load_json(p):
    if not os.path.exists(p): return {}
    with open(p, 'r') as f: return json.load(f)

def save_json(p, d):
    with open(p, 'w') as f: json.dump(d, f, indent=2)

def restart_xray(): subprocess.run(['systemctl', 'restart', 'xray'])

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

    # msg_web: Bersih (Untuk Website)
    msg_web = (
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"❖ XRAY/{protocol.upper()} WS{trial_txt} ❖\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"Remarks : {user}\n"
        f"IP Address : {IP_ADD}\n"
        f"Domain : {DOMAIN}\n"
        f"Port TLS : 443\n"
        f"Port NONE-TLS : 80\n"
        f"{'Password' if protocol == 'trojan' else 'ID'} : {uid}\n"
        f"Network : Websocket\n"
        f"Websocket Path : /{protocol}ws\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"Limit IP : {lim_ip_str}\n"
        f"Limit Kuota : {lim_q_str}\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"LINK WS TLS : {link_tls}\n"
        f"{'━━━━━━━━━━━━━━━━━━━━' if protocol != 'trojan' else ''}\n"
        f"{'LINK WS NONE-TLS : ' + link_none if protocol != 'trojan' else ''}\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"Expired On : {exp_date_str} WIB"
    )

    # msg_tg: Dengan Backtick (Khusus Telegram/Bot Admin agar Click-to-Copy Aktif)
    msg_tg = (
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"❖ XRAY/{protocol.upper()} WS{trial_txt} ❖\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"Remarks : `{user}`\n"
        f"IP Address : {IP_ADD}\n"
        f"Domain : {DOMAIN}\n"
        f"Port TLS : 443\n"
        f"Port NONE-TLS : 80\n"
        f"{'Password' if protocol == 'trojan' else 'ID'} : `{uid}`\n"
        f"Network : Websocket\n"
        f"Websocket Path : /{protocol}ws\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"Limit IP : {lim_ip_str}\n"
        f"Limit Kuota : {lim_q_str}\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"LINK WS TLS : `{link_tls}`\n"
        f"{'━━━━━━━━━━━━━━━━━━━━' if protocol != 'trojan' else ''}\n"
        f"{'LINK WS NONE-TLS : `' + link_none + '`' if protocol != 'trojan' else ''}\n"
        f"━━━━━━━━━━━━━━━━━━━━\n"
        f"Expired On : {exp_date_str} WIB"
    )
        
    return msg_web, msg_tg

@app.route('/user_legend/add-<protocol>ws', methods=['POST'])
def add_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    user, exp = data.get('user'), int(data.get('exp', 30))
    limit_ip, limit_quota = int(data.get('limit_ip', 0)), int(data.get('limit_quota', 0))
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
    send_telegram(msg_tg) # Notif Telegram pake backtick
    return jsonify({"stdout": msg_web}) # Balasan Website pake polos

@app.route('/user_legend/trial-<protocol>ws', methods=['POST'])
def trial_user(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    exp_min, limit_ip = int(data.get('exp', 60)), int(data.get('limit_ip', 1))
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
        msg_web, msg_tg = generate_account_detail(protocol, user, uid, exp_date_str, False, limit_ip, limit_q)
        return jsonify({"stdout": msg_tg}) # Bot Admin butuh format TG (backtick)
    return jsonify({"stdout": "Error: User not found"})

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=5000)
