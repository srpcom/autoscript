#!/bin/bash
# ==========================================
# install.sh
# MODULE: AUTO INSTALLER XRAY, CADDY, & L2TP BY SRPCOM
# OS Support: Ubuntu 20.04 / 22.04 / 24.04 LTS
# ==========================================

# --- KONFIGURASI GITHUB ANDA ---
GITHUB_RAW="https://raw.githubusercontent.com/syamsul18782/xray2026/main"

# Memastikan script dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan sebagai root (Gunakan 'sudo su' terlebih dahulu)."
    exit 1
fi

clear
echo "=========================================="
echo "    MEMULAI INSTALASI XRAY, CADDY & L2TP"
echo "    SUPPORT UBUNTU 20/22/24 LTS (MODULAR)"
echo "=========================================="

# Mendapatkan IP Publik
VPS_IP=$(curl -sS --max-time 5 ipv4.icanhazip.com || curl -sS --max-time 5 ifconfig.me)

# Looping Validasi Domain
while true; do
    read -p "Masukkan Domain VPS Anda (contoh: sg1.srpcom.cloud): " DOMAIN
    if [ -z "$DOMAIN" ]; then echo -e "\e[31m[ERROR]\e[0m Domain tidak boleh kosong!\n"; continue; fi

    DOMAIN_IP=$(getent ahostsv4 "$DOMAIN" | awk '{ print $1 }' | head -n 1)
    if [ "$DOMAIN_IP" == "$VPS_IP" ]; then
        echo -e "\e[32m[SUCCESS]\e[0m Domain valid! ($DOMAIN -> $VPS_IP)"
        break
    else
        echo -e "\e[31m[ERROR] VERIFIKASI DOMAIN GAGAL!\e[0m"
        echo -e "\e[33m[Solusi]\e[0m Pastikan A Record di DNS mengarah ke IP $VPS_IP (DNS Only)."
        echo -e "Tunggu 1-2 menit setelah merubah DNS, lalu coba lagi...\n"
    fi
done

echo -e "\n[1/9] Memperbarui sistem & dependensi..."
export DEBIAN_FRONTEND=noninteractive
apt update && apt upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
# PERBAIKAN: Menghapus iptables-persistent yang bentrok dengan UFW di Ubuntu 24
apt install curl wget unzip uuid-runtime jq tzdata ufw cron gnupg2 gnupg python3 python3-flask strongswan xl2tpd iptables -y
timedatectl set-timezone Asia/Jakarta

# Membuat Struktur Folder SRPCOM
mkdir -p /usr/local/etc/srpcom
mkdir -p /usr/local/bin/srpcom
mkdir -p /usr/local/etc/xray

# Menyimpan Data Global (Environment Variable)
cat > /usr/local/etc/srpcom/env.conf << EOF
DOMAIN="$DOMAIN"
IP_ADD="$VPS_IP"
EOF

echo -e "\n[2/9] Menginstal Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
systemctl enable xray

echo -e "\n[3/9] Mengonfigurasi Xray Core..."
# Memperbaiki Permission Log Xray
mkdir -p /var/log/xray
touch /var/log/xray/access.log
touch /var/log/xray/error.log
chown -R nobody:nogroup /var/log/xray
chmod -R 777 /var/log/xray

cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {"access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning"},
  "inbounds": [
    {"port": 10001, "listen": "127.0.0.1", "protocol": "vmess", "settings": {"clients": []}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/vmessws"}}},
    {"port": 10002, "listen": "127.0.0.1", "protocol": "vless", "settings": {"clients": [], "decryption": "none"}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/vlessws"}}},
    {"port": 10003, "listen": "127.0.0.1", "protocol": "trojan", "settings": {"clients": []}, "streamSettings": {"network": "ws", "wsSettings": {"path": "/trojanws"}}}
  ],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
touch /usr/local/etc/xray/expiry.txt
cat > /usr/local/etc/xray/bot_setting.conf << 'EOF'
BOT_TOKEN=""
CHAT_ID=""
AUTOBACKUP_STATUS="OFF"
BACKUP_TIME="24"
AUTOSEND_STATUS="OFF"
EOF
echo "SANGATRAHASIA123" > /usr/local/etc/xray/api_key.conf

echo -e "\n[4/9] Mengonfigurasi L2TP & IPsec..."
mkdir -p /etc/xl2tpd
mkdir -p /etc/ppp
# Konfigurasi IPsec (StrongSwan)
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

# Membuat Preshared Key (PSK)
echo "%any %any : PSK \"srpcom_vpn\"" > /etc/ipsec.secrets

# Konfigurasi XL2TPD
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

# Konfigurasi PPP Options untuk L2TP
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

echo -e "\n[5/9] Mendownload Modul Sistem dari GitHub..."
wget -q -O /usr/local/bin/srpcom/utils.sh "$GITHUB_RAW/core/utils.sh"
wget -q -O /usr/local/bin/srpcom/telegram.sh "$GITHUB_RAW/core/telegram.sh"
wget -q -O /usr/local/bin/srpcom/xray.sh "$GITHUB_RAW/core/xray.sh"
wget -q -O /usr/local/bin/srpcom/l2tp.sh "$GITHUB_RAW/core/l2tp.sh"
wget -q -O /usr/local/bin/srpcom/menu.sh "$GITHUB_RAW/core/menu.sh"
wget -q -O /usr/local/bin/xray-api.py "$GITHUB_RAW/configs/xray-api.py"

chmod +x /usr/local/bin/srpcom/*.sh
chmod +x /usr/local/bin/xray-api.py

# Membuat symlink agar user bisa ketik 'menu'
ln -sf /usr/local/bin/srpcom/menu.sh /usr/bin/menu

echo -e "\n[6/9] Mengonfigurasi Layanan API..."
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

echo -e "\n[7/9] Mengonfigurasi Firewall (UFW & Iptables NAT L2TP)..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 500/udp
ufw allow 4500/udp
ufw allow 1701/udp
ufw --force enable

# PERBAIKAN: Membuat Service NAT Custom (Pengganti iptables-persistent)
# Mencari nama interface internet secara otomatis (misal: eth0, ens3, dll)
ETH=$(ip route ls | grep default | awk '{print $5}' | head -n 1)

cat > /etc/systemd/system/l2tp-nat.service << EOF
[Unit]
Description=L2TP NAT IPTables Rules
After=network.target ufw.service

[Service]
Type=oneshot
ExecStart=/sbin/iptables -t nat -A POSTROUTING -s 192.168.42.0/24 -o $ETH -j MASQUERADE
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable l2tp-nat
systemctl start l2tp-nat

# Aktifkan IP Forwarding di sysctl
sed -i '/net.ipv4.ip_forward/s/^#//g' /etc/sysctl.conf
sysctl -p

echo -e "\n[8/9] Menginstal & Mengonfigurasi Caddy..."
apt install -y debian-keyring debian-archive-keyring apt-transport-https
# PERBAIKAN: Menambahkan --yes untuk memaksa overwrite GPG Caddy tanpa prompt
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor --yes -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
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

echo -e "\n[9/9] Setup Cronjob Selesai..."
# Auto start menu
if ! grep -q "menu" /root/.profile; then echo "menu" >> /root/.profile; fi

systemctl restart xray caddy cron xray-api ipsec xl2tpd

clear
echo "======================================================"
echo "    INSTALASI SELESAI & BERHASIL! (V2 MODULAR)        "
echo "======================================================"
echo "Protokol Terinstal : VMESS, VLESS, TROJAN, L2TP/IPsec"
echo "Ketik 'menu' untuk masuk ke dashboard manajemen."
echo "======================================================"
