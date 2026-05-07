#!/bin/bash
# ==========================================
# AUTO INSTALLER XRAY & CADDY BY SRPCOM
# OS Support: Ubuntu 20.04 / 22.04 / 24.04 LTS
# ==========================================

# Memastikan script dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan sebagai root (Gunakan 'sudo su' terlebih dahulu)."
    exit 1
fi

clear
echo "=========================================="
echo "    MEMULAI INSTALASI XRAY & CADDY"
echo "    SUPPORT UBUNTU 20/22/24 LTS"
echo "=========================================="

# Mendapatkan IP Publik VPS saat ini
echo "Mendeteksi IP Publik VPS..."
VPS_IP=$(curl -sS --max-time 5 ipv4.icanhazip.com)
if [ -z "$VPS_IP" ]; then
    VPS_IP=$(curl -sS --max-time 5 ifconfig.me)
fi

# Looping Validasi Domain
while true; do
    read -p "Masukkan Domain VPS Anda (contoh: sg1.srpcom.cloud): " DOMAIN
    if [ -z "$DOMAIN" ]; then
        echo -e "\e[31m[ERROR]\e[0m Domain tidak boleh kosong!\n"
        continue
    fi

    echo -e "Memverifikasi resolusi DNS untuk \e[33m$DOMAIN\e[0m..."
    DOMAIN_IP=$(getent ahostsv4 "$DOMAIN" | awk '{ print $1 }' | head -n 1)

    if [ "$DOMAIN_IP" == "$VPS_IP" ]; then
        echo -e "\e[32m[SUCCESS]\e[0m Domain valid! ($DOMAIN -> $VPS_IP)"
        break
    else
        echo -e "\e[31m[ERROR] VERIFIKASI DOMAIN GAGAL!\e[0m"
        echo -e "IP dari Domain : \e[31m${DOMAIN_IP:-TIDAK DITEMUKAN}\e[0m"
        echo -e "IP VPS Asli    : \e[32m$VPS_IP\e[0m"
        echo -e "\e[33m[Solusi]\e[0m Pastikan A Record di DNS mengarah ke IP $VPS_IP dan Proxy Cloudflare berstatus ABU-ABU (DNS Only)."
        echo -e "Tunggu sekitar 1-2 menit setelah merubah DNS, lalu coba masukkan lagi...\n"
    fi
done

echo -e "\n[1/10] Memperbarui sistem & menginstal dependensi..."
apt update && apt upgrade -y
apt install curl wget unzip uuid-runtime jq tzdata ufw cron gnupg2 gnupg python3 python3-flask -y
timedatectl set-timezone Asia/Jakarta

echo -e "\n[2/10] Menginstal Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
systemctl enable xray

echo -e "\n[3/10] Mengonfigurasi Xray (VMESS, VLESS, TROJAN)..."
rm -rf /usr/local/etc/xray/config.json
cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmessws"
        }
      }
    },
    {
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vlessws"
        }
      }
    },
    {
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojanws"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
mkdir -p /var/log/xray
chown -R nobody:nogroup /var/log/xray
touch /usr/local/etc/xray/expiry.txt

cat > /usr/local/etc/xray/bot_setting.conf << 'EOF'
BOT_TOKEN=""
CHAT_ID=""
AUTOBACKUP_STATUS="OFF"
BACKUP_TIME="00:00"
AUTOSEND_STATUS="OFF"
EOF

# Set API Key default
echo "SANGATRAHASIA123" > /usr/local/etc/xray/api_key.conf

echo -e "\n[4/10] Membangun API Backend (Python Flask) untuk Website..."
cat > /usr/local/bin/xray-api.py << 'EOF'
from flask import Flask, request, jsonify
import json, os, subprocess, uuid, datetime

app = Flask(__name__)
API_KEY_FILE = '/usr/local/etc/xray/api_key.conf'
XRAY_CONF = '/usr/local/etc/xray/config.json'
EXP_FILE = '/usr/local/etc/xray/expiry.txt'
LOCK_FILE = '/usr/local/etc/xray/locked.json'

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

def restart_xray():
    subprocess.run(['systemctl', 'restart', 'xray'])

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
    with open(EXP_FILE, 'a') as f: f.write(f"{user} {dt.strftime('%Y-%m-%d %H:%M:%S')}\n")
    restart_xray()
    return jsonify({"stdout": f"Success: {user} added to {protocol}ws."})

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
    with open(EXP_FILE, 'a') as f: f.write(f"{user} {dt.strftime('%Y-%m-%d %H:%M:%S')}\n")
    restart_xray()
    return jsonify({"stdout": f"Success: Trial {user} added."})

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
    for ib in cfg.get('inbounds', []):
        if ib.get('protocol') == protocol:
            for c in ib['settings']['clients']:
                if c.get('email') == user:
                    return jsonify({"stdout": f"Found: {json.dumps(c)}"})
    return jsonify({"stdout": "Not found"})

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
    return jsonify({"stdout": f"Xray status: {out}"})

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
EOF
chmod +x /usr/local/bin/xray-api.py

cat > /etc/systemd/system/xray-api.service << EOF
[Unit]
Description=Xray Python API Backend
After=network.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/xray-api.py
Restart=always
User=root
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray-api
systemctl start xray-api

echo -e "\n[5/10] Menginstal & Mengonfigurasi Caddy (Auto HTTPS)..."
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy -y

cat > /etc/caddy/Caddyfile << EOF
http://$DOMAIN, https://$DOMAIN {
    handle /user_legend/* {
        reverse_proxy localhost:5000
    }
    handle / {
        respond "Server is running normally." 200
    }
    handle /vmessws* {
        reverse_proxy localhost:10001
    }
    handle /vlessws* {
        reverse_proxy localhost:10002
    }
    handle /trojanws* {
        reverse_proxy localhost:10003
    }
}
EOF

echo -e "\n[6/10] Mengatur Firewall (UFW)..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo -e "\n[7/10] Menyiapkan Script Eksekusi Telegram..."
cat > /usr/local/bin/xray-backup-bot << 'EOF'
#!/bin/bash
source /usr/local/etc/xray/bot_setting.conf
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] || [ "$AUTOBACKUP_STATUS" == "OFF" ]; then exit 0; fi

# Mengambil IP dan jumlah akun
MYIP=$(curl -sS --max-time 10 ipv4.icanhazip.com || curl -sS --max-time 10 ifconfig.me)
XRAY_C=$(jq '[.inbounds[].settings.clients | length] | add' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)

# Nama file dengan format: xray-backup-YYYYMMDD HHMMSS.tar.gz
BACKUP_NAME="xray-backup-$(date +"%Y%m%d %H%M%S").tar.gz"
BACKUP_FILE="/root/$BACKUP_NAME"

tar -czf "$BACKUP_FILE" -C / usr/local/etc/xray/config.json usr/local/etc/xray/expiry.txt usr/local/etc/xray/bot_setting.conf 2>/dev/null
curl -s -F chat_id="${CHAT_ID}" -F document=@"${BACKUP_FILE}" -F caption="Auto Backup XRAY | ${XRAY_C} account |Server IP:${MYIP}  | Date: $(date)" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" >/dev/null
EOF
chmod +x /usr/local/bin/xray-backup-bot

echo -e "\n[8/10] Membangun CLI Menu Interaktif..."
cat > /usr/local/bin/menu << 'EOF'
#!/bin/bash
clear

OS_SYS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
BIT=$(uname -m)
if [[ "$BIT" == "x86_64" ]]; then BIT="(64 Bit)"; else BIT="(32 Bit)"; fi
KRNL=$(uname -r)
CPUMDL=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
CPUFREQ=$(awk -F: '/cpu MHz/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
if [[ -z "$CPUFREQ" ]]; then CPUFREQ="Unknown"; fi
CORE=$(nproc)
T_RAM=$(free -m | awk '/Mem:/ {printf "%.1f GB", $2/1024}')
U_RAM=$(free -m | awk '/Mem:/ {printf "%.1f MB", $3}')
T_DISK=$(df -h / | awk 'NR==2 {print $2}')
U_DISK=$(df -h / | awk 'NR==2 {print $3}')
IP_ADD=$(curl -sS --max-time 3 ipv4.icanhazip.com)
ISP_NAME=$(curl -sS --max-time 3 ipinfo.io/org | cut -d' ' -f2-)
REG=$(curl -sS --max-time 3 ipinfo.io/city)
TZ=$(cat /etc/timezone)

DOMAIN="DOMAIN_PLACEHOLDER"

load_bot_setting() {
    source /usr/local/etc/xray/bot_setting.conf
}
save_bot_setting() {
    cat > /usr/local/etc/xray/bot_setting.conf << CONFIG_EOF
BOT_TOKEN="${BOT_TOKEN}"
CHAT_ID="${CHAT_ID}"
AUTOBACKUP_STATUS="${AUTOBACKUP_STATUS}"
BACKUP_TIME="${BACKUP_TIME}"
AUTOSEND_STATUS="${AUTOSEND_STATUS}"
CONFIG_EOF
}
setup_autobackup_cron() {
    if [[ "$AUTOBACKUP_STATUS" == "ON" ]]; then
        IFS=':' read -r HH MM <<< "$BACKUP_TIME"
        echo "$MM $HH * * * root /usr/local/bin/xray-backup-bot" > /etc/cron.d/xray_autobackup
    else
        rm -f /etc/cron.d/xray_autobackup
    fi
    systemctl restart cron
}

send_telegram() {
    local text="$1"
    if [[ "$AUTOSEND_STATUS" == "ON" && -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" -d chat_id="${CHAT_ID}" -d text="$text" -d parse_mode="Markdown" >/dev/null 2>&1
    fi
}

add_vmess_ws() {
    clear
    load_bot_setting
    echo "======================================"
    echo "       CREATE VMESS WS ACCOUNT        "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then main_menu; return; fi
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    
    tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
    link_tls="vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
    link_none_tls="vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
    
    msg_terminal="━━━━━━━━━━━━━━━━━━━━
[XRAY/VMESS WS]
━━━━━━━━━━━━━━━━━━━━
Remarks : ${user}
Limit Quota : No Limit Quota User
Limit IP : Not Active
IP Address : ${IP_ADD}
Domain : ${DOMAIN}
Port TLS : 443
Port NONE-TLS : 80
ID : ${uuid}
Network : Websocket
Websocket Path : /vmessws
━━━━━━━━━━━━━━━━━━━━
LINK WS TLS : ${link_tls}
━━━━━━━━━━━━━━━━━━━━
LINK WS NONE-TLS : ${link_none_tls}
━━━━━━━━━━━━━━━━━━━━
EXPIRED ON : ${exp_date} ${exp_time} (${masaaktif} days)"

    msg_telegram="━━━━━━━━━━━━━━━━━━━━
[XRAY/VMESS WS]
━━━━━━━━━━━━━━━━━━━━
Remarks : \`${user}\`
Limit Quota : No Limit Quota User
Limit IP : Not Active
IP Address : ${IP_ADD}
Domain : ${DOMAIN}
Port TLS : 443
Port NONE-TLS : 80
ID : \`${uuid}\`
Network : Websocket
Websocket Path : /vmessws
━━━━━━━━━━━━━━━━━━━━
LINK WS TLS : \`${link_tls}\`
━━━━━━━━━━━━━━━━━━━━
LINK WS NONE-TLS : \`${link_none_tls}\`
━━━━━━━━━━━━━━━━━━━━
EXPIRED ON : ${exp_date} ${exp_time} (${masaaktif} days)"

    clear
    echo "$msg_terminal"
    send_telegram "$msg_telegram"
    
    echo ""
    read -n 1 -s -r -p "Press any key to back..."
    create_xray
}

add_vless_ws() {
    clear
    load_bot_setting
    echo "======================================"
    echo "       CREATE VLESS WS ACCOUNT        "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then main_menu; return; fi
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    
    link_tls="vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    link_none_tls="vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
    
    msg_terminal="━━━━━━━━━━━━━━━━━━━━
[XRAY/VLESS WS]
━━━━━━━━━━━━━━━━━━━━
Remarks : ${user}
Limit Quota : No Limit Quota User
Limit IP : Not Active
IP Address : ${IP_ADD}
Domain : ${DOMAIN}
Port TLS : 443
Port NONE-TLS : 80
ID : ${uuid}
Network : Websocket
Websocket Path : /vlessws
━━━━━━━━━━━━━━━━━━━━
LINK WS TLS : ${link_tls}
━━━━━━━━━━━━━━━━━━━━
LINK WS NONE-TLS : ${link_none_tls}
━━━━━━━━━━━━━━━━━━━━
EXPIRED ON : ${exp_date} ${exp_time} (${masaaktif} days)"

    msg_telegram="━━━━━━━━━━━━━━━━━━━━
[XRAY/VLESS WS]
━━━━━━━━━━━━━━━━━━━━
Remarks : \`${user}\`
Limit Quota : No Limit Quota User
Limit IP : Not Active
IP Address : ${IP_ADD}
Domain : ${DOMAIN}
Port TLS : 443
Port NONE-TLS : 80
ID : \`${uuid}\`
Network : Websocket
Websocket Path : /vlessws
━━━━━━━━━━━━━━━━━━━━
LINK WS TLS : \`${link_tls}\`
━━━━━━━━━━━━━━━━━━━━
LINK WS NONE-TLS : \`${link_none_tls}\`
━━━━━━━━━━━━━━━━━━━━
EXPIRED ON : ${exp_date} ${exp_time} (${masaaktif} days)"

    clear
    echo "$msg_terminal"
    send_telegram "$msg_telegram"
    
    echo ""
    read -n 1 -s -r -p "Press any key to back..."
    create_xray
}

add_trojan_ws() {
    clear
    load_bot_setting
    echo "======================================"
    echo "       CREATE TROJAN WS ACCOUNT       "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then main_menu; return; fi
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    
    link_tls="trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    
    msg_terminal="━━━━━━━━━━━━━━━━━━━━
[XRAY/TROJAN WS]
━━━━━━━━━━━━━━━━━━━━
Remarks : ${user}
Limit Quota : No Limit Quota User
Limit IP : Not Active
IP Address : ${IP_ADD}
Domain : ${DOMAIN}
Port TLS : 443
Password : ${uuid}
Network : Websocket
Websocket Path : /trojanws
━━━━━━━━━━━━━━━━━━━━
LINK WS TLS : ${link_tls}
━━━━━━━━━━━━━━━━━━━━
EXPIRED ON : ${exp_date} ${exp_time} (${masaaktif} days)"

    msg_telegram="━━━━━━━━━━━━━━━━━━━━
[XRAY/TROJAN WS]
━━━━━━━━━━━━━━━━━━━━
Remarks : \`${user}\`
Limit Quota : No Limit Quota User
Limit IP : Not Active
IP Address : ${IP_ADD}
Domain : ${DOMAIN}
Port TLS : 443
Password : \`${uuid}\`
Network : Websocket
Websocket Path : /trojanws
━━━━━━━━━━━━━━━━━━━━
LINK WS TLS : \`${link_tls}\`
━━━━━━━━━━━━━━━━━━━━
EXPIRED ON : ${exp_date} ${exp_time} (${masaaktif} days)"

    clear
    echo "$msg_terminal"
    send_telegram "$msg_telegram"
    
    echo ""
    read -n 1 -s -r -p "Press any key to back..."
    create_xray
}

add_trial() {
    clear
    load_bot_setting
    echo "======================================"
    echo "       CREATE TRIAL ACCOUNT (60M)     "
    echo "======================================"
    echo "1. VMESS WS"
    echo "2. VLESS WS"
    echo "3. TROJAN WS"
    echo "0. Back"
    read -p "Select Protocol [1-3 or 0]: " prot_opt
    
    if [[ "$prot_opt" == "0" ]]; then create_xray; return; fi
    
    user="trialsrp-$(date +%m%d%H%M)"
    masaaktif="60 Minutes"
    exp_date=$(date -d "+60 minutes" +"%Y-%m-%d")
    exp_time=$(date -d "+60 minutes" +"%H:%M:%S")
    uuid=$(uuidgen)
    
    if [[ "$prot_opt" == "1" ]]; then
        prot="vmess"
        jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    elif [[ "$prot_opt" == "2" ]]; then
        prot="vless"
        jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    elif [[ "$prot_opt" == "3" ]]; then
        prot="trojan"
        jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; add_trial; return
    fi
    
    mv /tmp/config.json /usr/local/etc/xray/config.json
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt
    systemctl restart xray
    
    if [[ "$prot" == "vmess" ]]; then
        tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
        none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
        link_tls="vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
        link_none_tls="vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
        port_none="80"
        path="/vmessws"
    elif [[ "$prot" == "vless" ]]; then
        link_tls="vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
        link_none_tls="vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
        port_none="80"
        path="/vlessws"
    elif [[ "$prot" == "trojan" ]]; then
        link_tls="trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
        link_none_tls="-"
        port_none="-"
        path="/trojanws"
    fi
    
    msg_terminal="━━━━━━━━━━━━━━━━━━━━
[XRAY/${prot^^} WS TRIAL]
━━━━━━━━━━━━━━━━━━━━
Remarks : ${user}
IP Address : ${IP_ADD}
Domain : ${DOMAIN}
Port TLS : 443
Port NONE-TLS : ${port_none}
ID/PW : ${uuid}
Network : Websocket
Websocket Path : ${path}
━━━━━━━━━━━━━━━━━━━━
LINK WS TLS : ${link_tls}
━━━━━━━━━━━━━━━━━━━━"
    if [[ "$prot" != "trojan" ]]; then
        msg_terminal="${msg_terminal}\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━"
    fi
    msg_terminal="${msg_terminal}\nEXPIRED ON : ${exp_date} ${exp_time} (${masaaktif})"

    msg_telegram="━━━━━━━━━━━━━━━━━━━━\n[XRAY/${prot^^} WS TRIAL]\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : ${port_none}\nID/PW : \`${uuid}\`\nNetwork : Websocket\nWebsocket Path : ${path}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━"
    if [[ "$prot" != "trojan" ]]; then
        msg_telegram="${msg_telegram}\nLINK WS NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━"
    fi
    msg_telegram="${msg_telegram}\nEXPIRED ON : ${exp_date} ${exp_time} (${masaaktif})"

    clear
    echo -e "$msg_terminal"
    send_telegram "$msg_telegram"
    
    echo ""
    read -n 1 -s -r -p "Press any key to back..."
    create_xray
}

create_xray() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║             CREATE XRAY            ║"
    echo "╚════════════════════════════════════╝"
    echo "1.  VMESS WS"
    echo "2.  VLESS WS"
    echo "3.  TROJAN WS"
    echo "4.  TRIAL ACCOUNT (60 Minutes)"
    echo " ————————————————————————————————————"
    echo "0. Back to XRAY Menu"
    echo "x. Back to Main Menu"
    echo "======================================"
    read -p "Please select an option [0-4 or x]: " opt
    case $opt in
        1) add_vmess_ws ;;
        2) add_vless_ws ;;
        3) add_trojan_ws ;;
        4) add_trial ;;
        0) menu_xray ;;
        x|X) main_menu ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; create_xray ;;
    esac
}

delete_xray() {
    clear
    echo "======================================"
    echo "          DELETE XRAY ACCOUNT         "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[].settings.clients[].email' /usr/local/etc/xray/config.json | sort -u)
    
    if [ ${#users[@]} -eq 0 ]; then
        echo "Tidak ada akun untuk dihapus."
        read -n 1 -s -r -p "Press any key to back..."
        menu_xray; return
    fi

    for i in "${!users[@]}"; do
        echo "$((i+1)). ${users[$i]}"
    done
    echo " ————————————————————————————————————"
    echo "0. Back to XRAY Menu"
    echo "x. Back to Main Menu"
    echo "======================================"
    read -p "Pilih nomor akun untuk dihapus [1-${#users[@]}]: " choice
    
    if [[ "$choice" == "0" ]]; then menu_xray; return; fi
    if [[ "$choice" == "x" || "$choice" == "X" ]]; then main_menu; return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        jq '(.inbounds[].settings.clients) |= map(select(.email != "'$user'"))' /usr/local/etc/xray/config.json > /tmp/config.json
        mv /tmp/config.json /usr/local/etc/xray/config.json
        sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
        systemctl restart xray
        echo -e "\n=> Akun '$user' berhasil dihapus!"
        sleep 2; menu_xray
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; delete_xray
    fi
}

renew_xray() {
    clear
    echo "======================================"
    echo "          RENEW XRAY ACCOUNT          "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[].settings.clients[].email' /usr/local/etc/xray/config.json | sort -u)
    
    if [ ${#users[@]} -eq 0 ]; then
        echo "Tidak ada akun untuk diperpanjang."
        read -n 1 -s -r -p "Press any key to back..."
        menu_xray; return
    fi

    for i in "${!users[@]}"; do
        echo "$((i+1)). ${users[$i]}"
    done
    echo " ————————————————————————————————————"
    echo "0. Back to XRAY Menu"
    echo "x. Back to Main Menu"
    echo "======================================"
    read -p "Pilih nomor akun [1-${#users[@]}]: " choice
    
    if [[ "$choice" == "0" ]]; then menu_xray; return; fi
    if [[ "$choice" == "x" || "$choice" == "X" ]]; then main_menu; return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        read -p "Tambah Masa Aktif (Hari): " masaaktif
        
        current_data=$(grep "^$user " /usr/local/etc/xray/expiry.txt)
        current_date=$(echo "$current_data" | awk '{print $2}')
        current_time=$(echo "$current_data" | awk '{print $3}')
        
        if [ -z "$current_date" ]; then current_date=$(date +"%Y-%m-%d"); fi
        if [ -z "$current_time" ]; then current_time=$(date +"%H:%M:%S"); fi
        
        new_exp_date=$(date -d "$current_date $current_time + $masaaktif days" +"%Y-%m-%d")
        new_exp_time=$(date -d "$current_date $current_time + $masaaktif days" +"%H:%M:%S")
        
        sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
        echo "$user $new_exp_date $new_exp_time" >> /usr/local/etc/xray/expiry.txt
        
        echo -e "\n=> Akun '$user' diperpanjang $masaaktif Hari!"
        echo "=> Expired Baru: $new_exp_date $new_exp_time"
        sleep 2; menu_xray
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; renew_xray
    fi
}

list_xray() {
    clear
    echo "======================================"
    echo "          LIST XRAY ACCOUNTS          "
    echo "======================================"
    echo -e "\n\e[32m[ VMESS WS ]\e[0m"
    echo "--------------------------------------"
    vmess_users=$(jq -r '.inbounds[] | select(.protocol=="vmess") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ -z "$vmess_users" ] || [ "$vmess_users" == "null" ]; then echo "Tidak ada akun."; else echo "$vmess_users" | awk '{print "- " $0}'; fi
    
    echo -e "\n\e[32m[ VLESS WS ]\e[0m"
    echo "--------------------------------------"
    vless_users=$(jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ -z "$vless_users" ] || [ "$vless_users" == "null" ]; then echo "Tidak ada akun."; else echo "$vless_users" | awk '{print "- " $0}'; fi
    
    echo -e "\n\e[32m[ TROJAN WS ]\e[0m"
    echo "--------------------------------------"
    trojan_users=$(jq -r '.inbounds[] | select(.protocol=="trojan") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ -z "$trojan_users" ] || [ "$trojan_users" == "null" ]; then echo "Tidak ada akun."; else echo "$trojan_users" | awk '{print "- " $0}'; fi
    
    echo -e "\n======================================"
    read -n 1 -s -r -p "Press any key to back..."
    menu_xray
}

detail_xray() {
    clear
    echo "======================================"
    echo "          DETAIL XRAY ACCOUNT         "
    echo "======================================"
    c_vm=$(jq '[.inbounds[] | select(.protocol=="vmess") | .settings.clients[]] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    c_vl=$(jq '[.inbounds[] | select(.protocol=="vless") | .settings.clients[]] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    c_tr=$(jq '[.inbounds[] | select(.protocol=="trojan") | .settings.clients[]] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)

    echo "1. VMESS ($c_vm)"
    echo "2. VLESS ($c_vl)"
    echo "3. TROJAN ($c_tr)"
    echo "0. Back to XRAY Menu"
    echo "x. Back to Main Menu"
    echo "======================================"
    read -p "Select Protocol [0-3 or x]: " prot_opt
    case $prot_opt in
        1) detail_list "vmess" ;;
        2) detail_list "vless" ;;
        3) detail_list "trojan" ;;
        0) menu_xray ;;
        x|X) main_menu ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; detail_xray ;;
    esac
}

detail_list() {
    prot=$1
    clear
    echo "======================================"
    echo "       SELECT ${prot^^} ACCOUNT       "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then
        echo "Tidak ada akun di protokol ini."
        echo "======================================"
        read -n 1 -s -r -p "Press any key to back..."
        detail_xray; return
    fi
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    echo "0. Back to Protocol Selection"
    echo "x. Back to Main Menu"
    echo "======================================"
    read -p "Select Account [0-${#users[@]} or x]: " acc_opt
    
    if [[ "$acc_opt" == "0" ]]; then detail_xray; return
    elif [[ "$acc_opt" == "x" || "$acc_opt" == "X" ]]; then main_menu; return
    elif [[ "$acc_opt" -gt 0 && "$acc_opt" -le "${#users[@]}" ]]; then
        selected_user="${users[$((acc_opt-1))]}"
        show_detail "$prot" "$selected_user"
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; detail_list "$prot"
    fi
}

show_detail() {
    prot=$1
    user=$2
    from_menu=$3
    clear
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "[XRAY/${prot^^} WS]"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Remarks : ${user}"
    echo "IP Address : ${IP_ADD}"
    echo "Domain : ${DOMAIN}"
    echo "Port TLS : 443"
    
    if [[ "$prot" == "vmess" ]]; then
        uuid=$(jq -r '.inbounds[] | select(.protocol=="vmess") | .settings.clients[] | select(.email=="'$user'") | .id' /usr/local/etc/xray/config.json)
        echo "Port NONE-TLS : 80"
        echo "ID : ${uuid}"
        echo "Network : Websocket"
        echo "Websocket Path : /vmessws"
        echo "━━━━━━━━━━━━━━━━━━━━"
        tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
        none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
        echo "LINK WS TLS : vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "LINK WS NONE-TLS : vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
    elif [[ "$prot" == "vless" ]]; then
        uuid=$(jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[] | select(.email=="'$user'") | .id' /usr/local/etc/xray/config.json)
        echo "Port NONE-TLS : 80"
        echo "ID : ${uuid}"
        echo "Network : Websocket"
        echo "Websocket Path : /vlessws"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "LINK WS TLS : vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "LINK WS NONE-TLS : vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
    elif [[ "$prot" == "trojan" ]]; then
        uuid=$(jq -r '.inbounds[] | select(.protocol=="trojan") | .settings.clients[] | select(.email=="'$user'") | .password' /usr/local/etc/xray/config.json)
        echo "Password : ${uuid}"
        echo "Network : Websocket"
        echo "Websocket Path : /trojanws"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "LINK WS TLS : trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━"
    exp_date=$(grep "^$user " /usr/local/etc/xray/expiry.txt | cut -d' ' -f2-)
    if [ -z "$exp_date" ]; then exp_date="Lifetime / No Exp"; fi
    echo "Expired On : $exp_date"
    echo ""
    read -n 1 -s -r -p "Press any key to back..."
    if [ "$from_menu" == "change_uuid" ]; then
        menu_change_uuid
    else
        detail_list "$prot"
    fi
}

change_protocol_uuid() {
    prot=$1
    clear
    echo "======================================"
    echo "     CHANGE UUID/PASS ${prot^^} WS    "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then
        echo "Tidak ada akun di protokol ini."
        echo "======================================"
        read -n 1 -s -r -p "Press any key to back..."
        menu_change_uuid; return
    fi
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    echo "0. Back"
    echo "x. Back to Main Menu"
    echo "======================================"
    read -p "Select Account [0-${#users[@]} or x]: " acc_opt
    
    if [[ "$acc_opt" == "0" ]]; then menu_change_uuid; return
    elif [[ "$acc_opt" == "x" || "$acc_opt" == "X" ]]; then main_menu; return
    elif [[ "$acc_opt" -gt 0 && "$acc_opt" -le "${#users[@]}" ]]; then
        selected_user="${users[$((acc_opt-1))]}"
        read -p "Input New UUID/Password (Press Enter to auto-generate): " new_uuid
        if [ -z "$new_uuid" ]; then new_uuid=$(uuidgen); fi
        
        if [[ "$prot" == "vmess" || "$prot" == "vless" ]]; then
            jq '(.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[] | select(.email=="'$selected_user'") | .id) = "'$new_uuid'"' /usr/local/etc/xray/config.json > /tmp/config.json
        elif [[ "$prot" == "trojan" ]]; then
            jq '(.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[] | select(.email=="'$selected_user'") | .password) = "'$new_uuid'"' /usr/local/etc/xray/config.json > /tmp/config.json
        fi
        mv /tmp/config.json /usr/local/etc/xray/config.json
        systemctl restart xray
        echo -e "\n=> UUID/Password untuk '$selected_user' berhasil diubah!"
        sleep 2
        show_detail "$prot" "$selected_user" "change_uuid"
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; change_protocol_uuid "$prot"
    fi
}

menu_change_uuid() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   CHANGE UUID OR PASSWORD XRAY   "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " [1]  CHANGE UUID/PASS FOR VMESS WS"
    echo " [2]  CHANGE UUID/PASS FOR VLESS WS"
    echo " [3]  CHANGE UUID/PASS FOR TROJAN WS"
    echo "----------------------------------"
    echo " [0]  Back"
    echo " [x]  Back To Menu"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    read -p "  Select From Options [1-3 or 0/x] : " opt
    case $opt in
        1) change_protocol_uuid "vmess" ;;
        2) change_protocol_uuid "vless" ;;
        3) change_protocol_uuid "trojan" ;;
        0) menu_xray ;;
        x|X) main_menu ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; menu_change_uuid ;;
    esac
}

menu_xray() {
    clear
    XRAY_VER=$(/usr/local/bin/xray version 2>/dev/null | head -n 1 | awk '{print $1" "$2}')
    if [[ -z "$XRAY_VER" ]]; then XRAY_VER="Xray 24.11.11"; fi
    echo "╔════════════════════════════════════╗"
    echo "║              MENU XRAY             ║"
    echo "╚════════════════════════════════════╝"
    echo "Xray Version: ${XRAY_VER}"
    echo "======================================"
    echo "1. Create XRAY Account"
    echo "2. Delete XRAY Account"
    echo "3. Renew XRAY Account"
    echo "4. List XRAY Account"
    echo "5. Detail XRAY Account"
    echo "6. Change UUID/Password"
    echo "0. Back to Main Menu"
    echo "======================================"
    read -p "Please select an option [0-6]: " opt
    case $opt in
        1) create_xray ;; 2) delete_xray ;; 3) renew_xray ;; 
        4) list_xray ;; 5) detail_xray ;; 6) menu_change_uuid ;;
        0|x|X) main_menu ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; menu_xray ;;
    esac
}

menu_api_key() {
    clear
    echo "======================================"
    echo "       SETTING API KEY WEBSITE        "
    echo "======================================"
    current_key=$(cat /usr/local/etc/xray/api_key.conf 2>/dev/null)
    echo "Current API Key: ${current_key}"
    echo "======================================"
    echo "Ini adalah kunci akses rahasia agar website billing"
    echo "Anda bisa mengontrol Xray di server ini."
    echo "======================================"
    read -p "Input New API Key (tekan 'x' untuk batal): " new_key
    if [[ "$new_key" != "x" && "$new_key" != "X" && -n "$new_key" ]]; then
        echo "$new_key" > /usr/local/etc/xray/api_key.conf
        systemctl restart xray-api
        echo -e "\n\e[32m[SUCCESS]\e[0m API Key berhasil diubah dan sistem direstart!"
        sleep 2
    fi
    menu_settings
}

menu_autobackup() {
    clear
    load_bot_setting
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   » Backup Data Via Telegram Bot «"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Status Autobackup Data Via Bot Is [$AUTOBACKUP_STATUS]"
    echo "   [1]  Start Backup Data (Enable)"
    echo "   [2]  Change Api Bot & Chat ID"
    echo "   [3]  Change Backup Time (Current: $BACKUP_TIME)"
    echo "   [4]  Stop Autobackup Data (Disable)"
    echo "   [0]  Back to Settings"
    echo "   [x]  Back to Main Menu"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "   Select From Options [1-4, 0, or x] : " opt
    case $opt in
        1) AUTOBACKUP_STATUS="ON"; save_bot_setting; setup_autobackup_cron; echo "Autobackup Enabled!"; sleep 1; menu_autobackup ;;
        2) 
            read -p "Input New API Bot: " new_api; BOT_TOKEN="$new_api"
            read -p "Input New Chat ID: " new_id; CHAT_ID="$new_id"
            save_bot_setting; echo "Data Bot Tersimpan!"; sleep 1; menu_autobackup ;;
        3) 
            read -p "Input New Time (HH:MM) [ex: 23:00] : " new_time
            BACKUP_TIME="$new_time"; save_bot_setting; setup_autobackup_cron; echo "Waktu Backup Diubah!"; sleep 1; menu_autobackup ;;
        4) AUTOBACKUP_STATUS="OFF"; save_bot_setting; setup_autobackup_cron; echo "Autobackup Disabled!"; sleep 1; menu_autobackup ;;
        0) menu_settings ;;
        x|X) main_menu ;;
        *) menu_autobackup ;;
    esac
}

menu_autosend() {
    clear
    load_bot_setting
    echo "======================"
    echo "AUTOSEND ACCOUNT VPN"
    echo "AFTER CREATED"
    echo "======================"
    echo "STATUS AUTOSEND ACCOUNT ($AUTOSEND_STATUS !)"
    echo "Current IDtelegram : $CHAT_ID"
    echo "Current API BOT : $BOT_TOKEN"
    echo "======================"
    echo " [1] Change User ID (warn: don't use id group)"
    echo " [2] Change API BOT TELEGRAM"
    if [ "$AUTOSEND_STATUS" == "ON" ]; then
        echo " [3] Stop AUTOSEND ACCOUNT"
    else
        echo " [3] Start AUTOSEND ACCOUNT"
    fi
    echo " [0] Back to Settings"
    echo " [x] Back to Main Menu"
    echo ""
    read -p " Select From Options [1-3, 0, or x] : " opt
    case $opt in
        1) read -p "Input New Chat ID: " new_id; CHAT_ID="$new_id"; save_bot_setting; menu_autosend ;;
        2) read -p "Input New API Bot: " new_api; BOT_TOKEN="$new_api"; save_bot_setting; menu_autosend ;;
        3) 
            if [ "$AUTOSEND_STATUS" == "ON" ]; then AUTOSEND_STATUS="OFF"; else AUTOSEND_STATUS="ON"; fi
            save_bot_setting; menu_autosend ;;
        0) menu_settings ;;
        x|X) main_menu ;;
        *) menu_autosend ;;
    esac
}

manual_backup_telegram() {
    clear
    load_bot_setting
    echo "======================================"
    echo "     MANUAL BACKUP VIA TELEGRAM       "
    echo "======================================"
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        echo "API Bot atau Chat ID belum disetting!"
        echo "Silakan setting di menu Autobackup/Autosend terlebih dahulu."
        sleep 3; menu_settings; return
    fi
    
    # Mengambil IP dan jumlah akun untuk caption manual
    MYIP=$(curl -sS --max-time 10 ipv4.icanhazip.com || curl -sS --max-time 10 ifconfig.me)
    XRAY_C=$(jq '[.inbounds[].settings.clients | length] | add' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    
    # Nama file dengan format waktu: xray-backup-YYYYMMDD HHMMSS.tar.gz
    BACKUP_NAME="xray-backup-$(date +"%Y%m%d %H%M%S").tar.gz"
    BACKUP_FILE="/root/$BACKUP_NAME"

    tar -czf "$BACKUP_FILE" -C / usr/local/etc/xray/config.json usr/local/etc/xray/expiry.txt usr/local/etc/xray/bot_setting.conf 2>/dev/null
    
    echo "Sedang mengirim file backup ke Telegram..."
    curl -s -F chat_id="${CHAT_ID}" -F document=@"${BACKUP_FILE}" -F caption="Manual Backup XRAY | ${XRAY_C} account |Server IP:${MYIP}  | Date: $(date)" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" > /dev/null
    
    echo -e "\n\e[32m[SUCCESS]\e[0m Backup berhasil dikirim ke Telegram!"
    read -n 1 -s -r -p "Press any key to back..."
    menu_settings
}

restore_xray() {
    clear
    echo "======================================"
    echo "          RESTORE DATA via VPS        "
    echo "======================================"
    echo "PENTING: Pastikan Anda sudah mengupload"
    echo "file backup (.tar.gz) ke folder /root/ "
    echo "menggunakan MobaXterm."
    echo "======================================"
    read -p "Nama file backup (misal: xray-backup.tar.gz) atau 'x' untuk batal : " backup_name
    
    if [ -z "$backup_name" ]; then menu_settings; return; fi
    if [[ "$backup_name" == "x" || "$backup_name" == "X" ]]; then main_menu; return; fi
    if [ ! -f "/root/$backup_name" ]; then
        echo -e "\n\e[31m[ERROR]\e[0m File /root/$backup_name tidak ditemukan!"
        sleep 2; menu_settings; return
    fi

    echo -e "\nMetode Restore:"
    echo "1. Replace (Hapus user saat ini, ganti total dengan backup)"
    echo "2. Merge   (Tambahkan user dari backup ke data saat ini)"
    read -p "Pilih Metode [1-2]: " restore_mode

    case $restore_mode in
        1)
            tar -xzf "/root/$backup_name" -C / 2>/dev/null
            echo -e "\n\e[32m[SUCCESS]\e[0m Restore Replace Berhasil!"
            ;;
        2)
            echo -e "\nMenggabungkan data (Merging)..."
            mkdir -p /tmp/restore_temp
            tar -xzf "/root/$backup_name" -C /tmp/restore_temp 2>/dev/null
            
            jq -s '.[0].inbounds[0].settings.clients = (.[0].inbounds[0].settings.clients + .[1].inbounds[0].settings.clients | unique_by(.email)) | .[0]' \
               /usr/local/etc/xray/config.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v1.json
            
            jq -s '.[0].inbounds[1].settings.clients = (.[0].inbounds[1].settings.clients + .[1].inbounds[1].settings.clients | unique_by(.email)) | .[0]' \
               /tmp/merged_v1.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v2.json
            
            jq -s '.[0].inbounds[2].settings.clients = (.[0].inbounds[2].settings.clients + .[1].inbounds[2].settings.clients | unique_by(.email)) | .[0]' \
               /tmp/merged_v2.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v3.json
            
            mv /tmp/merged_v3.json /usr/local/etc/xray/config.json
            
            cat /usr/local/etc/xray/expiry.txt /tmp/restore_temp/usr/local/etc/xray/expiry.txt | sort -k1,1 -k2,2r | sort -u -k1,1 > /tmp/merged_exp.txt
            mv /tmp/merged_exp.txt /usr/local/etc/xray/expiry.txt
            
            rm -rf /tmp/restore_temp
            echo -e "\n\e[32m[SUCCESS]\e[0m Restore Merge Berhasil!"
            ;;
        *) echo "Batal."; sleep 1; menu_settings; return ;;
    esac

    systemctl restart xray
    echo "======================================"
    read -n 1 -s -r -p "Press any key to back..."
    menu_settings
}

menu_settings() {
    clear
    echo "▶ BACKUP & RESTORE / SETTINGS"
    echo ""
    echo " [1] AUTOBACKUP VIA BOT TELEGRAM"
    echo " [2] AUTOSEND CREATED VPN VIA BOT"
    echo " [3] BACKUP VIA BOT TELEGRAM (MANUAL)"
    echo " [4] RESTORE DATA via VPS"
    echo " [5] SETTING API KEY FOR WEBSITE"
    echo " [0/x] Back to Main Menu"
    echo ""
    read -p " Select option [0-5 or x]: " opt
    case $opt in
        1) menu_autobackup ;;
        2) menu_autosend ;;
        3) manual_backup_telegram ;;
        4) restore_xray ;;
        5) menu_api_key ;;
        0|x|X) main_menu ;;
        *) menu_settings ;;
    esac
}

main_menu() {
    clear
    XRAY_C=$(jq '[.inbounds[].settings.clients | length] | add' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    echo "╔════════════════════════════════════╗"
    echo "║          SCRIP BY SRPCOM ver.1     ║"
    echo "╚════════════════════════════════════╝"
    echo " OS SYSTEM: ${OS_SYS} ${BIT}"
    echo " KERNEL TYPE: ${KRNL}"
    echo " CPU MODEL:  ${CPUMDL}"
    echo " CPU FREQUENCY:  ${CPUFREQ} MHz (${CORE} core)"
    echo " TOTAL RAM: ${T_RAM} Total / ${U_RAM} Used"
    echo " TOTAL STORAGE: ${T_DISK} Total / ${U_DISK} Used"
    echo " DOMAIN: ${DOMAIN}"
    echo " IP ADDRESS: ${IP_ADD}"
    echo " ISP: ${ISP_NAME}"
    echo " REGION: ${REG} [${TZ}]"
    echo "╔════════════════════════════════════╗"
    printf "║       XRAY ACCOUNT ➠ %-14s║\n" "${XRAY_C}"
    echo "╚════════════════════════════════════╝"
    echo "1. MENU XRAY"
    echo "2. SETTINGS (Backup/Restore/Bot/API)"
    echo "3. RESTART SERVICES (Xray & Caddy)"
    echo "4. CEK STATUS SERVICES"
    echo "0/x. Exit"
    echo ""
    read -p "Please select an option [0-4 or x]: " opt
    case $opt in
        1) menu_xray ;;
        2) menu_settings ;;
        3) 
            echo -e "\n=> Restarting Xray, Caddy, & API..."
            systemctl restart xray caddy cron xray-api
            echo -e "=> Done!"
            sleep 1.5; main_menu ;;
        4) 
            clear
            echo "======================================"
            echo "          STATUS SERVICES             "
            echo "======================================"
            echo -n "XRAY CORE   : "
            if systemctl is-active --quiet xray; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
            echo -n "CADDY PROXY : "
            if systemctl is-active --quiet caddy; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
            echo -n "API SERVER  : "
            if systemctl is-active --quiet xray-api; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
            echo "======================================"
            read -n 1 -s -r -p "Press any key to back..."; main_menu ;;
        0|x|X) clear; exit 0 ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; main_menu ;;
    esac
}
main_menu
EOF

# Inject domain inputan user ke dalam script menu
sed -i "s/DOMAIN_PLACEHOLDER/$DOMAIN/g" /usr/local/bin/menu

# Memberikan hak akses eksekusi ke menu
chmod +x /usr/local/bin/menu

# Menambahkan autostart menu saat login
if ! grep -q "menu" /root/.profile; then
    echo "menu" >> /root/.profile
fi
if ! grep -q "menu" /etc/bash.bashrc; then
    echo "menu" >> /etc/bash.bashrc
fi

echo -e "\n[9/10] Memasang Auto-Delete Cronjob..."
cat > /usr/local/bin/xray-exp << 'EOF'
#!/bin/bash
today_epoch=$(date +%s)
restart_required=false
if [ ! -f /usr/local/etc/xray/expiry.txt ]; then exit 0; fi
while read -r user exp_date exp_time; do
    if [ -z "$user" ] || [ -z "$exp_date" ]; then continue; fi
    if [ -z "$exp_time" ]; then
        exp_epoch=$(date -d "$exp_date 00:00:00" +%s 2>/dev/null)
    else
        exp_epoch=$(date -d "$exp_date $exp_time" +%s 2>/dev/null)
    fi
    if [[ -n "$exp_epoch" ]] && [[ $today_epoch -ge $exp_epoch ]]; then
        if jq '(.inbounds[].settings.clients) |= map(select(.email != "'$user'"))' /usr/local/etc/xray/config.json > /tmp/config.json; then
            mv /tmp/config.json /usr/local/etc/xray/config.json
            sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
            restart_required=true
        fi
    fi
done < /usr/local/etc/xray/expiry.txt
if [ "$restart_required" = true ]; then systemctl restart xray; fi
EOF
chmod +x /usr/local/bin/xray-exp

# Pasang cronjob agar berjalan setiap menit
crontab -l 2>/dev/null | grep -v "xray-exp" | crontab -
(crontab -l 2>/dev/null; echo "* * * * * /usr/local/bin/xray-exp") | crontab -

echo -e "\n[10/10] Merestart Services..."
systemctl daemon-reload
systemctl restart xray caddy cron xray-api

clear
echo "======================================================"
echo "    INSTALASI SELESAI & BERHASIL! "
echo "======================================================"
echo "- Domain terdaftar : $DOMAIN"
echo "- Xray Port        : 10001 (VMESS), 10002 (VLESS), 10003 (TROJAN)"
echo "- Reverse Proxy    : Caddy (Auto HTTPS Port 443 & 80)"
echo "- Fitur Auto-Delete: Aktif (Mengecek Setiap Menit)"
echo "- Fitur API Backend: Aktif (Jalur Web Billing -> VPS)"
echo "======================================================"
echo "Silakan ketik 'menu' untuk mengatur XRAY dan API KEY."
echo "======================================================"
