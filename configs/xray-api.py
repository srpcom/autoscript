#!/usr/bin/env python3
# ==========================================
# xray-api.py
# MODULE: PYTHON API BACKEND (SQLITE VERSION - FULL FEATURES)
# Menggabungkan fitur Auto-Send Telegram, Lisensi, dan Locking.
# ==========================================

from flask import Flask, request, jsonify
import sqlite3, json, os, subprocess, uuid, datetime, base64, urllib.request

app = Flask(__name__)

# --- KONFIGURASI PATH ---
DB_PATH = '/usr/local/etc/srpcom/database.db'
XRAY_CONF = '/usr/local/etc/xray/config.json'
CHAP_SECRETS = '/etc/ppp/chap-secrets'
ENV_FILE = '/usr/local/etc/srpcom/env.conf'
LICENSE_FILE = '/usr/local/etc/srpcom/license.info'

# ==========================================
# FUNGSI HELPER DATABASE & SISTEM
# ==========================================
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def get_env(key):
    try:
        with open(ENV_FILE, 'r') as f:
            for line in f:
                if line.startswith(f"{key}="):
                    return line.split('=', 1)[1].strip().strip('"').strip("'")
    except: pass
    return "UNKNOWN"

DOMAIN = get_env("DOMAIN")
IP_ADD = get_env("IP_ADD")

def get_setting(key_name, default_val=""):
    try:
        conn = get_db()
        c = conn.cursor()
        c.execute("SELECT key_value FROM system_settings WHERE key_name=?", (key_name,))
        row = c.fetchone()
        if row: return row['key_value']
    except: pass
    return default_val

def check_auth():
    auth_status = get_setting('api_auth', 'OFF')
    if auth_status == 'OFF': return True
    api_key_header = request.headers.get('x-api-key')
    real_key = get_setting('api_key', 'SANGATRAHASIA123')
    return api_key_header == real_key

def is_license_active():
    try:
        if os.path.exists(LICENSE_FILE):
            with open(LICENSE_FILE, 'r') as f:
                if 'STATUS="EXPIRED"' in f.read(): return False
    except: pass
    return True

@app.before_request
def check_license_lock():
    # Cegah eksekusi penambahan/perubahan jika lisensi mati (Sesuai fitur lama)
    if request.method in ['POST', 'DELETE']:
        mutating_paths = ['/add', '/del', '/renew', '/trial', '/lock', '/change-uuid']
        if any(p in request.path for p in mutating_paths):
            if not is_license_active():
                return jsonify({"stdout": "❌ AKSES DITOLAK: Masa aktif Lisensi Autoscript untuk Node Server ini telah habis. Eksekusi dibatalkan."}), 403

def send_telegram(text):
    """Mengirim notifikasi ke Telegram langsung dari API (Sesuai fitur lama)"""
    try:
        bot_token = get_setting('bot_token')
        chat_id = get_setting('admin_id')
        autosend = get_setting('bot_autosend', 'OFF')

        if autosend == "ON" and bot_token and chat_id:
            url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
            payload = {"chat_id": chat_id, "text": text, "parse_mode": "Markdown"}
            req = urllib.request.Request(url, data=json.dumps(payload).encode('utf-8'), headers={'Content-Type': 'application/json'})
            urllib.request.urlopen(req, timeout=5)
    except: pass

# ==========================================
# FUNGSI SINKRONISASI KE CONFIG OS
# ==========================================
def sync_xray_config():
    if not os.path.exists(XRAY_CONF): return
    try:
        with open(XRAY_CONF, 'r') as f: cfg = json.load(f)
        conn = get_db()
        c = conn.cursor()
        
        for ib in cfg.get('inbounds', []):
            if ib.get('protocol') in ['vmess', 'vless', 'trojan']:
                ib['settings']['clients'] = []
                prot_map = {'vmess': 'vmessws', 'vless': 'vlessws', 'trojan': 'trojanws'}
                db_prot = prot_map.get(ib.get('protocol'))
                
                # Hanya sinkronisasi user yang aktif (yang locked diabaikan/dihapus dari config memori)
                c.execute("SELECT username, uuid_pass FROM vpn_accounts WHERE protocol=? AND status='active'", (db_prot,))
                users = c.fetchall()
                
                for u in users:
                    if ib.get('protocol') in ['vmess', 'vless']:
                        ib['settings']['clients'].append({"id": u['uuid_pass'], "email": u['username']})
                    elif ib.get('protocol') == 'trojan':
                        ib['settings']['clients'].append({"password": u['uuid_pass'], "email": u['username']})
                        
        with open(XRAY_CONF, 'w') as f: json.dump(cfg, f, indent=2)
        subprocess.run(['systemctl', 'restart', 'xray'], capture_output=True)
    except: pass

def sync_l2tp_config():
    try:
        conn = get_db()
        c = conn.cursor()
        c.execute("SELECT username, uuid_pass FROM vpn_accounts WHERE protocol='l2tp' AND status='active'")
        users = c.fetchall()
        with open(CHAP_SECRETS, 'w') as f:
            for u in users: f.write(f'"{u["username"]}" l2tpd "{u["uuid_pass"]}" *\n')
        subprocess.run(['systemctl', 'restart', 'ipsec', 'xl2tpd'], capture_output=True)
    except: pass

def manage_ssh_os(username, password, exp_date_str, action='add'):
    try:
        if action == 'add':
            exp_date = exp_date_str.split(' ')[0]
            subprocess.run(['useradd', '-e', exp_date, '-s', '/bin/false', '-M', username])
            proc = subprocess.Popen(['chpasswd'], stdin=subprocess.PIPE, text=True)
            proc.communicate(f"{username}:{password}")
        elif action == 'del':
            subprocess.run(['userdel', '-f', username])
        elif action == 'renew':
            exp_date = exp_date_str.split(' ')[0]
            subprocess.run(['chage', '-E', exp_date, username])
    except: pass

# ==========================================
# ENDPOINTS API (ROUTING & LOGIC)
# ==========================================

@app.route('/user_legend/<action>-<protocol>', methods=['GET', 'POST', 'DELETE'])
def handle_vpn_request(action, protocol):
    if not check_auth(): return jsonify({"stdout": "❌ Unauthorized. API Key Invalid."}), 401
    
    data = request.json or {}
    conn = get_db()
    c = conn.cursor()
    now = datetime.datetime.now()

    try:
        # ------------------------------------------------
        # 1. CREATE ACCOUNT (ADD / TRIAL)
        # ------------------------------------------------
        if action in ['add', 'trial']:
            username = data.get('user')
            if action == 'trial':
                username = f"trial-{now.strftime('%m%d%H%M')}"
                exp_days = 0
                exp_time = now + datetime.timedelta(hours=1)
                limit_ip = 1
                limit_quota = 1 if 'ws' in protocol else 0
            else:
                if not username: return jsonify({"stdout": "❌ Error: Username diperlukan."})
                exp_days = int(data.get('exp', 30))
                limit_ip = int(data.get('limit_ip', 0))
                limit_quota = int(data.get('limit_quota', 0))
                exp_time = now + datetime.timedelta(days=exp_days)
            
            exp_str = exp_time.strftime('%Y-%m-%d %H:%M:%S')
            
            if protocol in ['vmessws', 'vlessws']: uuid_pass = str(uuid.uuid4())
            elif protocol == 'trojanws': uuid_pass = str(uuid.uuid4())[:8]
            else: uuid_pass = data.get('password', '1') if action == 'trial' else data.get('password', 'rahasia')

            try:
                c.execute('''INSERT INTO vpn_accounts (username, uuid_pass, protocol, expired_at, limit_ip, limit_quota)
                             VALUES (?, ?, ?, ?, ?, ?)''', (username, uuid_pass, protocol, exp_str, limit_ip, limit_quota))
                conn.commit()
            except sqlite3.IntegrityError:
                return jsonify({"stdout": f"❌ Error: Username '{username}' sudah ada di protokol {protocol.upper()}!"})

            if protocol in ['vmessws', 'vlessws', 'trojanws']: sync_xray_config()
            elif protocol == 'ssh': manage_ssh_os(username, uuid_pass, exp_str, 'add')
            elif protocol == 'l2tp': sync_l2tp_config()

            # Format Pesan Output & Telegram (Sesuai fitur lama)
            trial_txt = " TRIAL" if action == 'trial' else ""
            lim_ip_str = f"{limit_ip} IP" if limit_ip > 0 else "Unlimited"
            lim_q_str = f"{limit_quota} GB" if limit_quota > 0 else "Unlimited"
            
            if protocol == 'vmessws':
                tls_dict = {"v":"2","ps":username,"add":DOMAIN,"port":"443","id":uuid_pass,"aid":"0","net":"ws","type":"none","host":DOMAIN,"path":"/vmessws","tls":"tls","sni":DOMAIN}
                none_tls_dict = {"v":"2","ps":username,"add":DOMAIN,"port":"80","id":uuid_pass,"aid":"0","net":"ws","type":"none","host":DOMAIN,"path":"/vmessws","tls":"","sni":""}
                link_tls = "vmess://" + base64.b64encode(json.dumps(tls_dict, separators=(',', ':')).encode('utf-8')).decode('utf-8')
                link_none = "vmess://" + base64.b64encode(json.dumps(none_tls_dict, separators=(',', ':')).encode('utf-8')).decode('utf-8')
                msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{username}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : `{uuid_pass}`\nNetwork : Websocket\nWebsocket Path : /vmessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : {lim_ip_str}\nLimit Kuota : {lim_q_str}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : `{link_tls}`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : `{link_none}`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : {exp_str} WIB"
            
            elif protocol == 'vlessws':
                link_tls = f"vless://{uuid_pass}@{DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host={DOMAIN}&type=ws&sni={DOMAIN}#{username}"
                link_none = f"vless://{uuid_pass}@{DOMAIN}:80?path=/vlessws&security=none&encryption=none&host={DOMAIN}&type=ws#{username}"
                msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{username}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : `{uuid_pass}`\nNetwork : Websocket\nWebsocket Path : /vlessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : {lim_ip_str}\nLimit Kuota : {lim_q_str}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : `{link_tls}`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : `{link_none}`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : {exp_str} WIB"
            
            elif protocol == 'trojanws':
                link_tls = f"trojan://{uuid_pass}@{DOMAIN}:443?path=/trojanws&security=tls&host={DOMAIN}&type=ws&sni={DOMAIN}#{username}"
                msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{username}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nPort TLS : 443\nPassword : `{uuid_pass}`\nNetwork : Websocket\nWebsocket Path : /trojanws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : {lim_ip_str}\nLimit Kuota : {lim_q_str}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : `{link_tls}`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : {exp_str} WIB"
            
            elif protocol == 'ssh':
                msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{username}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nUsername : `{username}`\nPassword : `{uuid_pass}`\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH : 22\nPort Dropbear : 109, 143\nPort SSH-WS TLS : 443\nPort SSH-WS NTLS : 80\nPort OVPN UDP : 2200\nPort OVPN TCP : 1194\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : {lim_ip_str}\n━━━━━━━━━━━━━━━━━━━━\nLINK OVPN UDP : `http://{DOMAIN}/ovpn/udp.ovpn`\nLINK OVPN TCP : `http://{DOMAIN}/ovpn/tcp.ovpn`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : {exp_str} WIB"
            
            elif protocol == 'l2tp':
                msg_tg = f"━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN{trial_txt} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : `{username}`\nIP Address : {IP_ADD}\nDomain : {DOMAIN}\nIPsec PSK : `srpcom_vpn`\nUsername : `{username}`\nPassword : `{uuid_pass}`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : {exp_str} WIB"

            out = msg_tg.replace('`', '') # Versi tanpa backtick untuk terminal
            send_telegram(msg_tg)
            return jsonify({"stdout": out, "stdout_tg": msg_tg})

        # ------------------------------------------------
        # 2. DELETE ACCOUNT (DEL)
        # ------------------------------------------------
        elif action == 'del':
            username = data.get('user')
            if not username: return jsonify({"stdout": "❌ Error: Username diperlukan."})
            
            c.execute("DELETE FROM vpn_accounts WHERE username=? AND protocol=?", (username, protocol))
            if c.rowcount == 0: return jsonify({"stdout": f"❌ Error: Username '{username}' tidak ditemukan!"})
            conn.commit()
            
            if protocol in ['vmessws', 'vlessws', 'trojanws']: sync_xray_config()
            elif protocol == 'ssh': manage_ssh_os(username, '', '', 'del')
            elif protocol == 'l2tp': sync_l2tp_config()
            
            return jsonify({"stdout": f"✅ Akun {username} berhasil dihapus dari {protocol.upper()}!"})

        # ------------------------------------------------
        # 3. RENEW ACCOUNT
        # ------------------------------------------------
        elif action == 'renew':
            username = data.get('user')
            add_days = int(data.get('exp', 30))
            
            c.execute("SELECT expired_at, status FROM vpn_accounts WHERE username=? AND protocol=?", (username, protocol))
            row = c.fetchone()
            if not row: return jsonify({"stdout": f"❌ Error: Username '{username}' tidak ditemukan!"})
            
            curr_exp = row['expired_at']
            curr_dt = now if curr_exp == "Lifetime" else datetime.datetime.strptime(curr_exp, '%Y-%m-%d %H:%M:%S')
            new_exp_str = (curr_dt + datetime.timedelta(days=add_days)).strftime('%Y-%m-%d %H:%M:%S')
            
            # Renew juga akan otomatis membuka Lock
            c.execute("UPDATE vpn_accounts SET expired_at=?, status='active' WHERE username=? AND protocol=?", (new_exp_str, username, protocol))
            conn.commit()
            
            if protocol == 'ssh':
                manage_ssh_os(username, '', new_exp_str, 'renew')
                subprocess.run(['usermod', '-U', username], capture_output=True) # Unlock user OS
            elif protocol in ['vmessws', 'vlessws', 'trojanws', 'l2tp']:
                if row['status'] == 'locked': # Jika sebelumnya dikunci, maka restart core agar masuk lagi
                    if 'ws' in protocol: sync_xray_config()
                    else: sync_l2tp_config()
            
            return jsonify({"stdout": f"✅ Akun {username} diperpanjang {add_days} hari (Status: ACTIVE).\nExpired Baru: {new_exp_str} WIB"})

        # ------------------------------------------------
        # 4. DETAIL ACCOUNT
        # ------------------------------------------------
        elif action == 'detail':
            username = data.get('user')
            c.execute("SELECT * FROM vpn_accounts WHERE username=? AND protocol=?", (username, protocol))
            row = c.fetchone()
            if not row: return jsonify({"stdout": f"❌ Error: Username '{username}' tidak ditemukan!"})
            
            out = f"━━━━━━━━━━━━━━━━━━━━\n🔍 DETAIL AKUN {protocol.upper()}\n━━━━━━━━━━━━━━━━━━━━\n"
            out += f"Domain    : {DOMAIN}\nUsername  : {row['username']}\nPassword  : {row['uuid_pass']}\n"
            out += f"Status    : {row['status'].upper()}\nExpired   : {row['expired_at']} WIB\n━━━━━━━━━━━━━━━━━━━━\n"
            return jsonify({"stdout": out})

    except Exception as e:
        return jsonify({"stdout": f"❌ Terjadi Kesalahan Internal: {str(e)}"})

# ==========================================
# ENDPOINTS SISTEM, MONITORING & KONTROL LAMA
# ==========================================

@app.route('/user_legend/list-accounts', methods=['GET'])
def list_accounts():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    conn = get_db()
    c = conn.cursor()
    c.execute("SELECT username, protocol, expired_at, status FROM vpn_accounts ORDER BY protocol ASC")
    rows = c.fetchall()
    if not rows: return jsonify({"stdout": "📋 Database kosong. Belum ada akun."})
    
    out = "📋 DAFTAR SEMUA AKUN VPN\n━━━━━━━━━━━━━━━━━━━━\n"
    for r in rows: out += f"- [{r['protocol'].upper()}] {r['username']} (Exp: {r['expired_at'].split(' ')[0]}) [{r['status'].upper()}]\n"
    return jsonify({"stdout": out})

@app.route('/user_legend/cek-xray', methods=['GET'])
def cek_status():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    out = subprocess.run(['systemctl', 'is-active', 'xray'], capture_output=True, text=True).stdout.strip()
    return jsonify({"stdout": f"✅ Status Layanan Aktif\nXray Core: {out.upper()}\nDomain: {DOMAIN}"})

@app.route('/user_legend/sys-backup', methods=['GET'])
def sys_backup():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    try:
        with open(DB_PATH, "rb") as f: encoded = base64.b64encode(f.read()).decode('utf-8')
        return jsonify({"stdout": "✅ Proses kompresi database.db berhasil.", "data": encoded, "filename": f"srpcom-db-{datetime.datetime.now().strftime('%m%d')}.sqlite"})
    except Exception as e:
         return jsonify({"stdout": f"❌ Gagal membackup: {e}"})

# MENGEMBALIKAN FITUR LOCK (AUTOKILL) YANG HILANG
@app.route('/user_legend/lock-<protocol>', methods=['POST', 'GET'])
def lock_account(protocol):
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    user = request.json.get('user') if request.json else request.args.get('user')
    if not user: return jsonify({"stdout": "Error: User required"}), 400
    
    conn = get_db()
    c = conn.cursor()
    
    if protocol == 'ssh':
        subprocess.run(['usermod', '-L', user], capture_output=True)
        c.execute("UPDATE vpn_accounts SET status='locked' WHERE username=? AND protocol='ssh'", (user,))
    elif protocol == 'xray':
        # Lock semua protokol xray terkait user ini
        c.execute("UPDATE vpn_accounts SET status='locked' WHERE username=? AND protocol IN ('vmessws', 'vlessws', 'trojanws')", (user,))
        sync_xray_config() # Sync akan mengabaikan user yang status='locked', sehingga terhapus dari config.json sementara
        
    conn.commit()
    return jsonify({"stdout": f"User {user} on {protocol} has been LOCKED."})

# MENGEMBALIKAN FITUR CHANGE UUID
@app.route('/user_legend/change-uuid', methods=['POST'])
def change_uuid():
    if not check_auth(): return jsonify({"stdout": "Unauthorized"}), 401
    data = request.json or {}
    old_uuid = data.get('uuidold')
    new_uuid = data.get('uuidnew')
    if not old_uuid or not new_uuid: return jsonify({"stdout": "Error: uuidold and uuidnew required"}), 400
    
    conn = get_db()
    c = conn.cursor()
    c.execute("UPDATE vpn_accounts SET uuid_pass=? WHERE uuid_pass=?", (new_uuid, old_uuid))
    
    if c.rowcount > 0:
        conn.commit()
        sync_xray_config()
        sync_l2tp_config()
        return jsonify({"stdout": f"✅ UUID/Password berhasil diganti menjadi {new_uuid}."})
    return jsonify({"stdout": f"❌ UUID/Password lama '{old_uuid}' tidak ditemukan di Database."})

if __name__ == '__main__':
    if not os.path.exists(DB_PATH):
        print("Database belum dibuat. Menjalankan db_init.py...")
        subprocess.run(['python3', '/usr/local/bin/srpcom/db_init.py'])
    app.run(host='0.0.0.0', port=5000, debug=False)
