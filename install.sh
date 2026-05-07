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
# Meminta input domain dari user
read -p "Masukkan Domain VPS Anda (contoh: sg1.srpcom.cloud): " DOMAIN
if [ -z "$DOMAIN" ]; then
    echo "Domain tidak boleh kosong!"
    exit 1
fi

echo -e "\n[1/7] Memperbarui sistem & menginstal dependensi..."
apt update && apt upgrade -y
apt install curl wget unzip uuid-runtime jq tzdata ufw -y
timedatectl set-timezone Asia/Jakarta

echo -e "\n[2/7] Menginstal Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
systemctl enable xray

echo -e "\n[3/7] Mengonfigurasi Xray (VMESS, VLESS, TROJAN)..."
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

echo -e "\n[4/7] Menginstal & Mengonfigurasi Caddy (Auto HTTPS)..."
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

echo -e "\n[5/7] Mengatur Firewall (UFW)..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

echo -e "\n[6/7] Membangun CLI Menu Interaktif..."
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

add_vmess_ws() {
    clear
    echo "======================================"
    echo "       CREATE VMESS WS ACCOUNT        "
    echo "======================================"
    read -p "Username : " user
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    exp=$(date -d "$masaaktif days" +"%Y-%m-%d %H:%M:%S WIB")
    jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
    link_tls="vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
    link_none_tls="vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
    clear
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "[XRAY/VMESS_WS]"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Remarks : ${user}"
    echo "Limit Quota : No Limit Quota User"
    echo "Limit IP : Not Active"
    echo "IP Address : ${IP_ADD}"
    echo "Domain : ${DOMAIN}"
    echo "Port TLS : 443"
    echo "Port NONE-TLS : 80"
    echo "ID : ${uuid}"
    echo "Network : Websocket"
    echo "Websocket Path : /vmessws"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "LINK WS TLS : ${link_tls}"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "LINK WS NONE-TLS : ${link_none_tls}"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "EXPIRED ON : ${exp} (${masaaktif} days)"
    echo ""
    read -n 1 -s -r -p "Press any key to back..."
    create_xray
}

add_vless_ws() {
    clear
    echo "======================================"
    echo "       CREATE VLESS WS ACCOUNT        "
    echo "======================================"
    read -p "Username : " user
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    exp=$(date -d "$masaaktif days" +"%Y-%m-%d %H:%M:%S WIB")
    jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    link_tls="vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    link_none_tls="vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
    clear
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "[XRAY/VLESS_WS]"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Remarks : ${user}"
    echo "Limit Quota : No Limit Quota User"
    echo "Limit IP : Not Active"
    echo "IP Address : ${IP_ADD}"
    echo "Domain : ${DOMAIN}"
    echo "Port TLS : 443"
    echo "Port NONE-TLS : 80"
    echo "ID : ${uuid}"
    echo "Network : Websocket"
    echo "Websocket Path : /vlessws"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "LINK WS TLS : ${link_tls}"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "LINK WS NONE-TLS : ${link_none_tls}"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "EXPIRED ON : ${exp} (${masaaktif} days)"
    echo ""
    read -n 1 -s -r -p "Press any key to back..."
    create_xray
}

add_trojan_ws() {
    clear
    echo "======================================"
    echo "       CREATE TROJAN WS ACCOUNT       "
    echo "======================================"
    read -p "Username : " user
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    exp=$(date -d "$masaaktif days" +"%Y-%m-%d %H:%M:%S WIB")
    jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    link_tls="trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    clear
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "[XRAY/TROJAN_WS]"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Remarks : ${user}"
    echo "Limit Quota : No Limit Quota User"
    echo "Limit IP : Not Active"
    echo "IP Address : ${IP_ADD}"
    echo "Domain : ${DOMAIN}"
    echo "Port TLS : 443"
    echo "Password : ${uuid}"
    echo "Network : Websocket"
    echo "Websocket Path : /trojanws"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "LINK WS TLS : ${link_tls}"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "EXPIRED ON : ${exp} (${masaaktif} days)"
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
    echo "======================================"
    read -p "Please select an option [0-3]: " opt
    case $opt in
        1) add_vmess_ws ;;
        2) add_vless_ws ;;
        3) add_trojan_ws ;;
        0) menu_xray ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; create_xray ;;
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
    echo "2. Delete XRAY Account (Coming Soon)"
    echo "3. Renew XRAY Account (Coming Soon)"
    echo "0. Back to Main Menu"
    echo "======================================"
    read -p "Please select an option [0-3]: " opt
    case $opt in
        1) create_xray ;;
        2|3) echo -e "\n=> Fitur XRAY (Opsi $opt) sedang dalam pengembangan..."; sleep 1; menu_xray ;;
        0) main_menu ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; menu_xray ;;
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
    echo "2. RESTART SERVICES (Xray & Caddy)"
    echo "3. CEK STATUS SERVICES"
    echo "0. Exit"
    echo "══════════════════════════════════════"
    echo "EXP SCRIPT: 2272-09-04 (89970 days)"
    echo "REGIST BY : 5666536947 (id telegram)"
    echo "══════════════════════════════════════"
    read -p "Please select an option [0-3]: " opt
    case $opt in
        1) menu_xray ;;
        2) 
            echo -e "\n=> Restarting Xray & Caddy..."
            systemctl restart xray
            systemctl restart caddy
            echo -e "=> Done!"
            sleep 1.5
            main_menu 
            ;;
        3) 
            clear
            echo "======================================"
            echo "          STATUS SERVICES             "
            echo "======================================"
            echo -n "XRAY CORE   : "
            if systemctl is-active --quiet xray; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
            echo -n "CADDY PROXY : "
            if systemctl is-active --quiet caddy; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
            echo "======================================"
            read -n 1 -s -r -p "Press any key to back..."
            main_menu
            ;;
        0) clear; exit 0 ;;
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

echo -e "\n[7/7] Merestart Services..."
systemctl daemon-reload
systemctl restart xray caddy

clear
echo "======================================================"
echo "    INSTALASI SELESAI & BERHASIL! "
echo "======================================================"
echo "- Domain terdaftar : $DOMAIN"
echo "- Xray Port        : 10001 (VMESS), 10002 (VLESS), 10003 (TROJAN)"
echo "- Reverse Proxy    : Caddy (Auto HTTPS Port 443 & 80)"
echo "======================================================"
echo "Silakan ketik 'menu' untuk membuat akun VPN."
echo "======================================================"
