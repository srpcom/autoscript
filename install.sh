#!/bin/bash
# ==========================================
# install.sh
# MODULE: AUTO INSTALLER XRAY, CADDY, L2TP, SSH, OVPN, BADVPN
# OS Support: Ubuntu 20.04 / 22.04 / 24.04 LTS
# ==========================================

GITHUB_RAW="https://raw.githubusercontent.com/srpcom/autoscript/main"

if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan sebagai root (Gunakan 'sudo su' terlebih dahulu)."
    exit 1
fi

clear
echo "=========================================="
echo "  SRPCOM AUTOSCRIPT VERSI 1.0             "
echo "  MEMULAI INSTALASI VPN MULTIPORT V5      "
echo "  XRAY, CADDY, L2TP, SSH, OVPN, BADVPN    "
echo "=========================================="
echo "=========================================="
echo "  PASTIKAN BAHWA ANDA SUDAH LOGIN         "
echo "  SEBAGAI USER ROOT MURNI                 "
echo "  GUNAKAN TOOL INI UNTUK MENDAPATKAN      "
echo "  HAK AKSES ROOT MURNI :                  "
echo "  bash <(curl -Ls https://srpcom.cloud/getroot.sh)"
echo "  skip jika sudah paham"
echo "  note : saran OS ubuntu 20"
echo "=========================================="


VPS_IP=$(curl -sS --max-time 5 ipv4.icanhazip.com || curl -sS --max-time 5 ifconfig.me)

# ==========================================
# PENGECEKAN LISENSI SCRIPT KE DATABASE CLOUDFLARE
# ==========================================
echo -e "\n=========================================="
echo -e "  VERIFIKASI LISENSI AUTOSCRIPT PREMIUM   "
echo -e "=========================================="
while true; do
    read -p "Masukkan Nama VPS Anda (Sesuai pendaftaran di web): " VPS_NAME
    if [ -n "$VPS_NAME" ]; then break; fi
    echo -e "\e[31m[ERROR]\e[0m Nama VPS tidak boleh kosong!\n"
done

echo -e "\nMemeriksa Validitas Lisensi IP ($VPS_IP) dan Nama ($VPS_NAME)..."

FORMATTED_NAME=$(echo "$VPS_NAME" | sed 's/ /%20/g')
API_CHECK_URL="https://tuban.store/api/license/check?ip=$VPS_IP&name=$FORMATTED_NAME"

RESPONSE=$(curl -sS --max-time 10 -w "\n%{http_code}" "$API_CHECK_URL")
HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
JSON_BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_STATUS" != "200" ]; then
    echo -e "\e[31m[ERROR] LISENSI DITOLAK ATAU TIDAK VALID!\e[0m"
    ERR_MSG=$(echo "$JSON_BODY" | grep -o '"message":"[^"]*' | cut -d'"' -f4)
    if [ -n "$ERR_MSG" ]; then echo -e "\e[33mAlasan:\e[0m $ERR_MSG"
    else echo -e "\e[33mAlasan:\e[0m IP $VPS_IP belum terdaftar atau masa aktif habis."; fi
    
    echo -e "Silakan beli/perpanjang lisensi Anda di: \e[36mhttps://tuban.store/lisensi\e[0m"
    exit 1
fi

# Mengambil tanggal expired dari JSON (Grep manual karena jq belum terinstall)
EXP_DATE_INIT=$(echo "$JSON_BODY" | grep -o '"expires_at":"[^"]*' | cut -d'"' -f4)
echo -e "\e[32m[SUCCESS]\e[0m Lisensi Valid (Exp: $EXP_DATE_INIT)! Melanjutkan instalasi...\n"
# ==========================================

while true; do
    read -p "Masukkan Domain VPS Anda (contoh: aw.srpcom.cloud): " DOMAIN
    if [ -z "$DOMAIN" ]; then echo -e "\e[31m[ERROR]\e[0m Domain tidak boleh kosong!\n"; continue; fi
    
    # FITUR BYPASS: Mencegah user terjebak looping jika DNS sedang masa propagasi lambat
    if [[ "$DOMAIN" == "skip" || "$DOMAIN" == "SKIP" ]]; then
        read -p "Masukkan Domain secara manual (tanpa validasi DNS): " DOMAIN
        echo -e "\e[33m[WARNING]\e[0m Validasi DNS dilewati secara paksa untuk domain: $DOMAIN"
        break
    fi
    
    DOMAIN_IP=$(getent ahostsv4 "$DOMAIN" | awk '{ print $1 }' | head -n 1)
    if [ "$DOMAIN_IP" == "$VPS_IP" ]; then
        echo -e "\e[32m[SUCCESS]\e[0m Domain valid! ($DOMAIN -> $VPS_IP)"
        break
    else
        echo -e "\e[31m[ERROR] VERIFIKASI DOMAIN GAGAL!\e[0m"
        echo -e "\e[33m[Solusi]\e[0m Pastikan A Record di DNS mengarah ke IP $VPS_IP (DNS Only)."
        echo -e "Ketik \e[32mskip\e[0m jika Anda YAKIN DNS sudah disetting dan sedang menunggu propagasi (Propagasi bisa memakan waktu 5-30 menit).\n"
    fi
done

echo -e "\n[1/11] Memperbarui sistem & dependensi..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
apt install curl wget unzip uuid-runtime jq tzdata ufw cron gnupg2 gnupg python3 python3-flask python3-pip strongswan xl2tpd iptables dropbear openvpn cmake make gcc git net-tools -y
timedatectl set-timezone Asia/Jakarta

pip3 install pyTelegramBotAPI requests --break-system-packages 2>/dev/null || pip3 install pyTelegramBotAPI requests

echo -e "\n=> Menginstal Speedtest CLI Resmi Ookla..."
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
apt install speedtest -y

mkdir -p /usr/local/etc/srpcom
mkdir -p /usr/local/bin/srpcom
mkdir -p /usr/local/etc/xray

# SIMPAN VPS NAME SECARA PERMANEN
cat > /usr/local/etc/srpcom/env.conf << EOF
DOMAIN="$DOMAIN"
IP_ADD="$VPS_IP"
VPS_NAME="$VPS_NAME"
EOF

# SIMPAN CACHE LISENSI AWAL
cat > /usr/local/etc/srpcom/license.info << EOF
STATUS="ACTIVE"
EXP_DATE="$EXP_DATE_INIT"
EOF

touch /usr/local/etc/srpcom/extra_domains.txt

cat > /usr/local/etc/xray/bot_admin.conf << 'EOF'
BOT_TOKEN=""
ADMIN_ID=""
EOF

echo -e "\n[2/11] Optimasi Performa Server (BBR & Swap RAM)..."
if [ ! -f "/swapfile" ]; then
    echo "=> Membuat Swap Memory 2GB..."
    dd if=/dev/zero of=/swapfile bs=1M count=2048 status=none
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1
    swapon /swapfile
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    fi
fi

echo "=> Mengaktifkan TCP BBR..."
if ! grep -q "net.ipv4.tcp_congestion_control=bbr" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf << EOF

# Optimasi TCP BBR & Network
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    sysctl -p >/dev/null 2>&1
fi

echo -e "\n[3/11] Menginstal Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
systemctl enable xray

echo -e "\n[4/11] Mengonfigurasi Xray Core (Limit & Kuota Enabled)..."
mkdir -p /var/log/xray
touch /var/log/xray/access.log
touch /var/log/xray/error.log
chown -R nobody:nogroup /var/log/xray
chmod -R 777 /var/log/xray

cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning"},
  "api": {"services": ["StatsService", "LoggerService"], "tag": "api"},
  "stats": {},
  "policy": {"levels": {"0": {"statsUserUplink": true, "statsUserDownlink": true}}, "system": {"statsInboundUplink": true, "statsInboundDownlink": true}},
  "inbounds": [
    {"port": 10001, "listen": "127.0.0.1", "protocol": "vmess", "settings": {"clients": []}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmessws"}}},
    {"port": 10002, "listen": "127.0.0.1", "protocol": "vless", "settings": {"clients": [], "decryption": "none"}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/vlessws"}}},
    {"port": 10003, "listen": "127.0.0.1", "protocol": "trojan", "settings": {"clients": []}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojanws"}}},
    {"port": 10085, "listen": "127.0.0.1", "protocol": "dokodemo-door", "settings": {"address": "127.0.0.1"}, "tag": "api"}
  ],
  "outbounds": [{"protocol": "freedom"}],
  "routing": {"rules": [{"inboundTag": ["api"], "outboundTag": "api", "type": "field"}]}
}
EOF
touch /usr/local/etc/xray/expiry.txt
touch /usr/local/etc/xray/limit.txt
cat > /usr/local/etc/xray/bot_setting.conf << 'EOF'
BOT_TOKEN=""
CHAT_ID=""
AUTOBACKUP_STATUS="OFF"
BACKUP_TIME="24"
AUTOSEND_STATUS="OFF"
EOF

# KONFIGURASI DEFAULT API
echo "SANGATRAHASIA123" > /usr/local/etc/xray/api_key.conf
echo "OFF" > /usr/local/etc/xray/api_auth.conf

echo -e "\n[5/11] Mengonfigurasi L2TP & IPsec..."
mkdir -p /etc/xl2tpd
mkdir -p /etc/ppp
cat > /etc/ipsec.conf << EOF
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no
conn L2TP-PSK-NAT
    rightsubnet=vhost:%priv
    also=L2TP-PSK-noNAT
conn L2TP-PSK-noNAT
    authby=secret
    pfs=no
    auto=add
    keyingtries=3
    rekey=no
    ikelifetime=8h
    keylife=1h
    type=transport
    left=%defaultroute
    leftid=%any
    leftprotoport=17/1701
    right=%any
    rightid=%any
    rightprotoport=17/%any
    dpddelay=40
    dpdtimeout=130
    dpdaction=clear
EOF
echo "%any %any : PSK \"srpcom_vpn\"" > /etc/ipsec.secrets
cat > /etc/xl2tpd/xl2tpd.conf << EOF
[global]
port = 1701
[lns default]
ip range = 192.168.42.10-192.168.42.250
local ip = 192.168.42.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF
cat > /etc/ppp/options.xl2tpd << EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
idle 1800
mtu 1410
mru 1410
nodefaultroute
debug
proxyarp
connect-delay 5000
EOF
touch /usr/local/etc/srpcom/l2tp_expiry.txt
systemctl enable ipsec xl2tpd

echo -e "\n[6/11] Mengonfigurasi SSH, Dropbear, SSH-WS, BadVPN & OpenVPN..."
cat > /etc/default/dropbear << 'EOF'
NO_START=0
DROPBEAR_PORT=109
DROPBEAR_EXTRA_ARGS="-p 143"
DROPBEAR_BANNER=""
DROPBEAR_RECEIVE_WINDOW=65536
EOF
systemctl restart dropbear
systemctl enable dropbear

cat > /usr/local/bin/ssh-ws.py << 'EOF'
import socket, threading, sys
def handle_client(client_socket):
    try:
        req = client_socket.recv(4096).decode('utf-8')
        if not req: return
        response = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n"
        client_socket.send(response.encode())
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect(('127.0.0.1', 22))
        def forward(src, dst):
            try:
                while True:
                    data = src.recv(4096)
                    if not data: break
                    dst.send(data)
            except: pass
            finally:
                src.close(); dst.close()
        threading.Thread(target=forward, args=(client_socket, ssh_socket)).start()
        threading.Thread(target=forward, args=(ssh_socket, client_socket)).start()
    except: client_socket.close()
def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('127.0.0.1', 10004))
    server.listen(100)
    while True:
        client, addr = server.accept()
        threading.Thread(target=handle_client, args=(client,)).start()
if __name__ == '__main__': main()
EOF
cat > /etc/systemd/system/ssh-ws.service << EOF
[Unit]
Description=SSH WebSocket Proxy Service
After=network.target
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ssh-ws.py
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable ssh-ws
systemctl start ssh-ws

touch /usr/local/etc/srpcom/ssh_expiry.txt
touch /usr/local/etc/srpcom/ssh_limit.txt

echo -e "Membuat layanan BadVPN (UDP Custom)..."
git clone https://github.com/ambrop72/badvpn.git /tmp/badvpn >/dev/null 2>&1
mkdir -p /tmp/badvpn/build && cd /tmp/badvpn/build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 >/dev/null 2>&1
make >/dev/null 2>&1
cp udpgw/badvpn-udpgw /usr/local/bin/

for port in 7100 7200 7300; do
cat > /etc/systemd/system/badvpn-$port.service << EOF
[Unit]
Description=BadVPN UDPGW Service Port $port
After=network.target

[Service]
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:$port --max-clients 500
User=root
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable badvpn-$port
systemctl start badvpn-$port
done

echo -e "Menyiapkan OpenVPN dan Sertifikatnya..."
mkdir -p /etc/openvpn/server/keys
cd /etc/openvpn/server/keys
openssl ecparam -genkey -name prime256v1 -out ca.key
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt -subj "/CN=SRPCOM_CA"
openssl ecparam -genkey -name prime256v1 -out server.key
openssl req -new -key server.key -out server.csr -subj "/CN=SRPCOM_Server"
openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt

# PERBAIKAN: Menambahkan --secret agar ta.key berhasil dibuat tanpa error
openvpn --genkey --secret ta.key

# PERBAIKAN: Mempercepat pencarian plugin PAM agar instalasi tidak terkesan macet/hang
PAM_PLUGIN=$(find /usr/lib -name "openvpn-plugin-auth-pam.so" | head -n 1)
if [ -z "$PAM_PLUGIN" ]; then
    PAM_PLUGIN="/usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so"
fi

cat > /etc/openvpn/server/server-udp.conf << EOF
port 2200
proto udp
dev tun
ca keys/ca.crt
cert keys/server.crt
key keys/server.key
dh none
ecdh-curve prime256v1
tls-auth keys/ta.key 0
server 10.8.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-GCM
persist-key
persist-tun
status openvpn-udp.log
verb 3
plugin $PAM_PLUGIN login
verify-client-cert none
username-as-common-name
EOF

cat > /etc/openvpn/server/server-tcp.conf << EOF
port 1194
proto tcp
dev tun
ca keys/ca.crt
cert keys/server.crt
key keys/server.key
dh none
ecdh-curve prime256v1
tls-auth keys/ta.key 0
server 10.9.0.0 255.255.255.0
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
cipher AES-256-GCM
persist-key
persist-tun
status openvpn-tcp.log
verb 3
plugin $PAM_PLUGIN login
verify-client-cert none
username-as-common-name
EOF
systemctl enable openvpn-server@server-udp
systemctl enable openvpn-server@server-tcp
systemctl start openvpn-server@server-udp
systemctl start openvpn-server@server-tcp

mkdir -p /usr/local/etc/srpcom/ovpn
CA_CERT=$(cat /etc/openvpn/server/keys/ca.crt)
TA_CERT=$(cat /etc/openvpn/server/keys/ta.key)

cat > /usr/local/etc/srpcom/ovpn/udp.ovpn << EOF
client
dev tun
proto udp
remote $DOMAIN 2200
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth-user-pass
key-direction 1
<ca>
$CA_CERT
</ca>
<tls-auth>
$TA_CERT
</tls-auth>
EOF

cat > /usr/local/etc/srpcom/ovpn/tcp.ovpn << EOF
client
dev tun
proto tcp
remote $DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth-user-pass
key-direction 1
<ca>
$CA_CERT
</ca>
<tls-auth>
$TA_CERT
</tls-auth>
EOF

echo -e "\n[7/11] Mendownload Modul Sistem dari GitHub..."
wget -q -O /usr/local/bin/srpcom/utils.sh "$GITHUB_RAW/core/utils.sh"
wget -q -O /usr/local/bin/srpcom/telegram.sh "$GITHUB_RAW/core/telegram.sh"
wget -q -O /usr/local/bin/srpcom/xray.sh "$GITHUB_RAW/core/xray.sh"
wget -q -O /usr/local/bin/srpcom/l2tp.sh "$GITHUB_RAW/core/l2tp.sh"
wget -q -O /usr/local/bin/srpcom/ssh.sh "$GITHUB_RAW/core/ssh.sh"
wget -q -O /usr/local/bin/srpcom/monitor.sh "$GITHUB_RAW/core/monitor.sh"
wget -q -O /usr/local/bin/srpcom/autokill.sh "$GITHUB_RAW/core/autokill.sh"
wget -q -O /usr/local/bin/srpcom/menu.sh "$GITHUB_RAW/core/menu.sh"
wget -q -O /usr/local/bin/srpcom/auto_expired.sh "$GITHUB_RAW/core/auto_expired.sh"
wget -q -O /usr/local/bin/xray-api.py "$GITHUB_RAW/configs/xray-api.py"
wget -q -O /usr/local/bin/bot-admin.py "$GITHUB_RAW/configs/bot-admin.py"

# FIX: Hapus karakter DOS (Carriage Return / \r) akibat edit file di Windows
sed -i 's/\r$//' /usr/local/bin/srpcom/*.sh 2>/dev/null
sed -i 's/\r$//' /usr/local/bin/xray-api.py 2>/dev/null
sed -i 's/\r$//' /usr/local/bin/bot-admin.py 2>/dev/null

chmod +x /usr/local/bin/srpcom/*.sh
chmod +x /usr/local/bin/xray-api.py
chmod +x /usr/local/bin/bot-admin.py

echo -e "\n[8/11] Mengonfigurasi Layanan API & Bot Admin..."
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

cat > /etc/systemd/system/srpcom-bot.service << EOF
[Unit]
Description=Telegram Admin Interactive Bot
After=network.target xray-api.service
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/bot-admin.py
Restart=always
RestartSec=5
User=root
Environment=PYTHONUNBUFFERED=1
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray-api
systemctl start xray-api
systemctl disable srpcom-bot >/dev/null 2>&1

echo -e "\n[9/11] Mengonfigurasi Firewall (UFW & Iptables NAT L2TP/OVPN)..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 109/tcp
ufw allow 143/tcp
ufw allow 443/tcp
ufw allow 500/udp
ufw allow 4500/udp
ufw allow 1701/udp
ufw allow 1194/tcp
ufw allow 2200/udp
ufw allow 7100/udp
ufw allow 7200/udp
ufw allow 7300/udp
ufw --force enable

ETH=$(ip route ls | grep default | awk '{print $5}' | head -n 1)
cat > /etc/systemd/system/vpn-nat.service << EOF
[Unit]
Description=VPN NAT IPTables Rules (L2TP & OVPN)
After=network.target ufw.service
[Service]
Type=oneshot
ExecStart=/sbin/iptables -t nat -A POSTROUTING -s 192.168.42.0/24 -o $ETH -j MASQUERADE
ExecStart=/sbin/iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o $ETH -j MASQUERADE
ExecStart=/sbin/iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o $ETH -j MASQUERADE
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable vpn-nat
systemctl start vpn-nat
sed -i '/net.ipv4.ip_forward/s/^#//g' /etc/sysctl.conf
sysctl -p

echo -e "\n[10/11] Menginstal & Mengonfigurasi Caddy..."
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy -y

DOMAINS_STR="http://$DOMAIN, https://$DOMAIN, http://support.zoom.us.$DOMAIN, https://support.zoom.us.$DOMAIN"

cat > /etc/caddy/Caddyfile << EOF
$DOMAINS_STR {
    handle /user_legend/* {
        reverse_proxy localhost:5000
    }
    handle /ovpn/* {
        root * /usr/local/etc/srpcom
        file_server
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
    handle /sshws* {
        reverse_proxy localhost:10004
    }
}
EOF

echo -e "\n[11/11] Setup Cronjob Selesai..."
if ! grep -q "menu" /root/.profile; then echo "menu" >> /root/.profile; fi

echo "0 * * * * root /usr/local/bin/srpcom/auto_expired.sh >/dev/null 2>&1" > /etc/cron.d/auto_expired

# ==========================================
# REBUILD SHORTCUTS (WRAPPER)
# ==========================================
chmod +x /usr/local/bin/srpcom/menu.sh
source /usr/local/bin/srpcom/menu.sh
rebuild_shortcuts
# ==========================================

systemctl restart xray caddy cron xray-api ipsec xl2tpd dropbear ssh-ws

clear
echo "======================================================"
echo "    INSTALASI SELESAI & BERHASIL! (V5 FINAL)          "
echo "======================================================"
echo "Protokol: VMESS, VLESS, TROJAN, L2TP, SSH, OVPN, UDPGW"
echo "Optimasi: TCP BBR & Swap RAM 2GB Aktif!"
echo "Default SNI/Bug: support.zoom.us.$DOMAIN"
echo "Ketik 'menu' untuk masuk ke dashboard manajemen."
echo "Ketik 'srpcom' untuk melihat daftar perintah cepat."
echo "------------------------------------------------------"
echo "Untuk menjadikan VPS ini sebagai MASTER BOT, masuk ke menu:"
echo "-> [5] Settings -> [9] Setting Telegram Admin Bot -> Mulai Bot"
echo "Untuk menghubungkan Node lain, gunakan API Key Default:"
echo "SANGATRAHASIA123 (Ubah di menu 5 -> 5 jika perlu)"
echo "======================================================"
