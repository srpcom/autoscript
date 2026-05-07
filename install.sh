#!/bin/bash
# ==========================================
# AUTO INSTALLER XRAY & CADDY BY SRPCOM
# OS Support: Ubuntu 20.04 / 22.04 LTS
# ==========================================

# Memastikan script dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan sebagai root (Gunakan 'sudo su' terlebih dahulu)."
    exit 1
fi

clear
echo "=========================================="
echo "    MEMULAI INSTALASI XRAY & CADDY"
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

echo -e "\n[1/9] Memperbarui sistem & menginstal dependensi..."
apt update && apt upgrade -y
apt install curl wget unzip uuid-runtime jq tzdata ufw cron -y
timedatectl set-timezone Asia/Jakarta

echo -e "\n[2/9] Menginstal Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
systemctl enable xray

echo -e "\n[3/9] Mengonfigurasi Xray (VMESS, VLESS, TROJAN)..."
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
CONFIG_EOF

echo -e "\n[4/9] Menginstal & Mengonfigurasi Caddy (Auto HTTPS)..."
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy -y

cat > /etc/caddy/Caddyfile << EOF
http://$DOMAIN, https://$DOMAIN {
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

echo -e "\n[5/9] Mengatur Firewall (UFW)..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo -e "\n[6/9] Menyiapkan Script Eksekusi Telegram..."
cat > /usr/local/bin/xray-backup-bot << 'EOF'
#!/bin/bash
source /usr/local/etc/xray/bot_setting.conf
if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] || [ "$AUTOBACKUP_STATUS" == "OFF" ]; then exit 0; fi

BACKUP_FILE="/root/xray-backup-$(date +"%Y%m%d").tar.gz"
tar -czf "$BACKUP_FILE" -C / usr/local/etc/xray/config.json usr/local/etc/xray/expiry.txt usr/local/etc/xray/bot_setting.conf 2>/dev/null
curl -s -F chat_id="${CHAT_ID}" -F document=@"${BACKUP_FILE}" -F caption="Auto Backup XRAY | Server IP: $(curl -sS ipv4.icanhazip.com) | Date: $(date)" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" >/dev/null
EOF
chmod +x /usr/local/bin/xray-backup-bot

echo -e "\n[7/9] Membangun CLI Menu Interaktif..."
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
SLOWDNS="157at"
CLIENT_N="syam157"
VER="1.3.0"

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
    echo "$user $exp_date" >> /usr/local/etc/xray/expiry.txt

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
EXPIRED ON : ${exp_date} (${masaaktif} days)"

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
EXPIRED ON : ${exp_date} (${masaaktif} days)"

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
    echo "$user $exp_date" >> /usr/local/etc/xray/expiry.txt

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
EXPIRED ON : ${exp_date} (${masaaktif} days)"

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
EXPIRED ON : ${exp_date} (${masaaktif} days)"

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
    echo "$user $exp_date" >> /usr/local/etc/xray/expiry.txt

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
EXPIRED ON : ${exp_date} (${masaaktif} days)"

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
EXPIRED ON : ${exp_date} (${masaaktif} days)"

    clear
    echo "$msg_terminal"
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
    echo " ————————————————————————————————————"
    echo "0. Back to XRAY Menu"
    echo "x. Back to Main Menu"
    echo "======================================"
    read -p "Please select an option [0-3 or x]: " opt
    case $opt in
        1) add_vmess_ws ;;
        2) add_vless_ws ;;
        3) add_trojan_ws ;;
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
    read -p "Masukkan Username (Ketik 'x' untuk Batal): " user
    if [ -z "$user" ]; then echo -e "\n=> Username tidak boleh kosong!"; sleep 1; menu_xray; return; fi
    if [[ "$user" == "x" || "$user" == "X" ]]; then main_menu; return; fi

    cek=$(jq -r '.inbounds[].settings.clients[] | select(.email=="'$user'") | .email' /usr/local/etc/xray/config.json 2>/dev/null | head -n 1)
    if [ "$cek" != "$user" ]; then echo -e "\n=> User '$user' tidak ditemukan!"; sleep 2; menu_xray; return; fi

    jq '(.inbounds[].settings.clients) |= map(select(.email != "'$user'"))' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
    systemctl restart xray

    echo "======================================"
    echo "   Akun '$user' berhasil dihapus!"
    echo "======================================"
    read -n 1 -s -r -p "Press any key to back..."
    menu_xray
}

renew_xray() {
    clear
    echo "======================================"
    echo "          RENEW XRAY ACCOUNT          "
    echo "======================================"
    read -p "Masukkan Username (Ketik 'x' untuk Batal): " user
    if [ -z "$user" ]; then echo -e "\n=> Username tidak boleh kosong!"; sleep 1; menu_xray; return; fi
    if [[ "$user" == "x" || "$user" == "X" ]]; then main_menu; return; fi

    cek=$(jq -r '.inbounds[].settings.clients[] | select(.email=="'$user'") | .email' /usr/local/etc/xray/config.json 2>/dev/null | head -n 1)
    if [ "$cek" != "$user" ]; then echo -e "\n=> User '$user' tidak ditemukan!"; sleep 2; menu_xray; return; fi

    read -p "Tambah Masa Aktif (Hari): " masaaktif
    current_exp=$(grep "^$user " /usr/local/etc/xray/expiry.txt | awk '{print $2}')
    if [ -z "$current_exp" ]; then current_exp=$(date +"%Y-%m-%d"); fi
    new_exp=$(date -d "$current_exp + $masaaktif days" +"%Y-%m-%d")
    
    sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
    echo "$user $new_exp" >> /usr/local/etc/xray/expiry.txt

    echo "======================================"
    echo "   Akun '$user' diperpanjang $masaaktif Hari!"
    echo "   Expired Baru: $new_exp"
    echo "======================================"
    read -n 1 -s -r -p "Press any key to back..."
    menu_xray
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
    exp_date=$(grep "^$user " /usr/local/etc/xray/expiry.txt | awk '{print $2}')
    if [ -z "$exp_date" ]; then exp_date="Lifetime / No Exp"; fi
    echo "Expired On : $exp_date"
    echo ""
    read -n 1 -s -r -p "Press any key to back..."
    detail_list "$prot"
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
    echo "0. Back to Main Menu"
    echo "======================================"
    read -p "Please select an option [0-5]: " opt
    case $opt in
        1) create_xray ;; 2) delete_xray ;; 3) renew_xray ;; 
        4) list_xray ;; 5) detail_xray ;; 
        0|x|X) main_menu ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; menu_xray ;;
    esac
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
    
    BACKUP_FILE="/root/xray-backup-$(date +"%Y%m%d").tar.gz"
    tar -czf "$BACKUP_FILE" -C / usr/local/etc/xray/config.json usr/local/etc/xray/expiry.txt usr/local/etc/xray/bot_setting.conf 2>/dev/null
    
    echo "Sedang mengirim file backup ke Telegram..."
    curl -s -F chat_id="${CHAT_ID}" -F document=@"${BACKUP_FILE}" -F caption="Manual Backup XRAY | Server IP: $VPS_IP | Date: $(date)" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" > /dev/null
    
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
            # Buat folder sementara untuk ekstraksi
            mkdir -p /tmp/restore_temp
            tar -xzf "/root/$backup_name" -C /tmp/restore_temp 2>/dev/null
            
            # 1. Merge Config JSON (VMESS clients)
            # Menggunakan jq untuk menggabungkan array clients dan memastikan email unik
            jq -s '.[0].inbounds[0].settings.clients = (.[0].inbounds[0].settings.clients + .[1].inbounds[0].settings.clients | unique_by(.email)) | .[0]' \
               /usr/local/etc/xray/config.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v1.json
            
            # 2. Merge Config JSON (VLESS clients)
            jq -s '.[0].inbounds[1].settings.clients = (.[0].inbounds[1].settings.clients + .[1].inbounds[1].settings.clients | unique_by(.email)) | .[0]' \
               /tmp/merged_v1.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v2.json
            
            # 3. Merge Config JSON (TROJAN clients)
            jq -s '.[0].inbounds[2].settings.clients = (.[0].inbounds[2].settings.clients + .[1].inbounds[2].settings.clients | unique_by(.email)) | .[0]' \
               /tmp/merged_v2.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v3.json
            
            mv /tmp/merged_v3.json /usr/local/etc/xray/config.json
            
            # 4. Merge Expiry.txt
            # Menggabungkan, mengurutkan, dan hanya menyimpan nama unik (paling baru)
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
    echo " [0/x] Back to Main Menu"
    echo ""
    read -p " Select option [0-4 or x]: " opt
    case $opt in
        1) menu_autobackup ;;
        2) menu_autosend ;;
        3) manual_backup_telegram ;;
        4) restore_xray ;;
        0|x|X) main_menu ;;
        *) menu_settings ;;
    esac
}

main_menu() {
    clear
    XRAY_C=$(jq '[.inbounds[].settings.clients | length] | add' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    echo "╔════════════════════════════════════╗"
    echo "║          SCRIP BY SRPCOM           ║"
    echo "╚════════════════════════════════════╝"
    echo " OS SYSTEM: ${OS_SYS} ${BIT}"
    echo " KERNEL TYPE: ${KRNL}"
    echo " CPU MODEL:  ${CPUMDL}"
    echo " CPU FREQUENCY:  ${CPUFREQ} MHz (${CORE} core)"
    echo " TOTAL RAM: ${T_RAM} Total / ${U_RAM} Used"
    echo " TOTAL STORAGE: ${T_DISK} Total / ${U_DISK} Used"
    echo " DOMAIN: ${DOMAIN}"
    echo " SLOWDNS DOMAIN: ${SLOWDNS}"
    echo " IP ADDRESS: ${IP_ADD}"
    echo " ISP: ${ISP_NAME}"
    echo " REGION: ${REG} [${TZ}]"
    echo " CLIENTNAME: ${CLIENT_N}"
    echo " SCRIPT VERSION: ${VER}"
    echo "╔════════════════════════════════════╗"
    echo "                                      "
    echo " ———————————————————————————————————— "
    echo "         XRAY ACCOUNT ➠ ${XRAY_C}     "
    echo " ———————————————————————————————————— "
    echo "                                      "
    echo "╔════════════════════════════════════╗"
    echo "║              MAIN MENU             ║"
    echo "╚════════════════════════════════════╝"
    echo "1. MENU XRAY"
    echo "2. SETTINGS (Backup/Restore/Bot)"
    echo "3. RESTART SERVICES (Xray & Caddy)"
    echo "4. CEK STATUS SERVICES"
    echo "0/x. Exit"
    echo "══════════════════════════════════════"
    echo "EXP SCRIPT: 2272-09-04 (89970 days)"
    echo "REGIST BY : 5666536947 (id telegram)"
    echo "══════════════════════════════════════"
    read -p "Please select an option [0-4 or x]: " opt
    case $opt in
        1) menu_xray ;;
        2) menu_settings ;;
        3) 
            echo -e "\n=> Restarting Xray & Caddy..."
            systemctl restart xray caddy cron
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

echo -e "\n[8/9] Memasang Auto-Delete Cronjob..."
cat > /usr/local/bin/xray-exp << 'EOF'
#!/bin/bash
# Script untuk mengecek dan menghapus user expired
today_epoch=$(date +%s)
restart_required=false

if [ ! -f /usr/local/etc/xray/expiry.txt ]; then
    exit 0
fi

while read -r user exp; do
    if [ -z "$user" ] || [ -z "$exp" ]; then continue; fi
    
    exp_epoch=$(date -d "$exp 00:00:00" +%s 2>/dev/null)
    
    if [[ -n "$exp_epoch" ]] && [[ $today_epoch -ge $exp_epoch ]]; then
        if jq '(.inbounds[].settings.clients) |= map(select(.email != "'$user'"))' /usr/local/etc/xray/config.json > /tmp/config.json; then
            mv /tmp/config.json /usr/local/etc/xray/config.json
            sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
            restart_required=true
        fi
    fi
done < /usr/local/etc/xray/expiry.txt

if [ "$restart_required" = true ]; then
    systemctl restart xray
fi
EOF
chmod +x /usr/local/bin/xray-exp

if ! crontab -l | grep -q "xray-exp"; then
    (crontab -l 2>/dev/null; echo "0 0 * * * /usr/local/bin/xray-exp") | crontab -
fi

echo -e "\n[9/9] Merestart Services..."
systemctl daemon-reload
systemctl restart xray caddy cron

clear
echo "======================================================"
echo "    INSTALASI SELESAI & BERHASIL! "
echo "======================================================"
echo "- Domain terdaftar : $DOMAIN"
echo "- Xray Port        : 10001 (VMESS), 10002 (VLESS), 10003 (TROJAN)"
echo "- Reverse Proxy    : Caddy (Auto HTTPS Port 443 & 80)"
echo "- Fitur Auto-Delete: Aktif (Mengecek Setiap Jam 00:00)"
echo "- Fitur Telegram   : Tersedia di menu SETTINGS"
echo "======================================================"
echo "Silakan ketik 'menu' untuk membuat akun VPN."
echo "======================================================"
