#!/bin/bash
# ==========================================
# install.sh
# MODULE: AUTO INSTALLER XRAY & CADDY BY SRPCOM (V2 MODULAR)
# OS Support: Ubuntu 20.04 / 22.04 / 24.04 LTS
# ==========================================

# OS Support: Ubuntu 20.04 / 22.04 / 24.04 LTS
# ==========================================
# File ini hanya bertugas menginstal dependencies, 
# menyiapkan sistem, dan mendownload modul dari GitHub.

# --- KONFIGURASI GITHUB ANDA ---
# Ubah URL ini sesuai dengan repositori GitHub Anda nantinya
GITHUB_RAW="https://raw.githubusercontent.com/syamsul18782/xray2026/main"

# Memastikan script dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan sebagai root (Gunakan 'sudo su' terlebih dahulu)."
    exit 1
fi

clear
echo "=========================================="
echo "    MEMULAI INSTALASI XRAY & CADDY (MODULAR)"
echo "    SUPPORT UBUNTU 20/22/24 LTS"
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

echo -e "\n[1/7] Memperbarui sistem & dependensi..."
apt update && apt upgrade -y
apt install curl wget unzip uuid-runtime jq tzdata ufw cron gnupg2 gnupg python3 python3-flask -y
timedatectl set-timezone Asia/Jakarta

# Membuat Struktur Folder
mkdir -p /usr/local/etc/srpcom
mkdir -p /usr/local/bin/srpcom
mkdir -p /usr/local/etc/xray
mkdir -p /var/log/xray
chown -R nobody:nogroup /var/log/xray

# Menyimpan Data Global (Environment Variable)
cat > /usr/local/etc/srpcom/env.conf << EOF
DOMAIN="$DOMAIN"
IP_ADD="$VPS_IP"
EOF

echo -e "\n[2/7] Menginstal Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
systemctl enable xray

echo -e "\n[3/7] Mengonfigurasi Xray Core..."
# Menyiapkan konfigurasi dasar Xray (Anda bisa memindahkannya juga ke GitHub configs/xray.json nantinya)
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

echo -e "\n[4/7] Mendownload Modul Sistem dari GitHub..."
wget -q -O /usr/local/bin/srpcom/utils.sh "$GITHUB_RAW/core/utils.sh"
wget -q -O /usr/local/bin/srpcom/telegram.sh "$GITHUB_RAW/core/telegram.sh"
wget -q -O /usr/local/bin/srpcom/xray.sh "$GITHUB_RAW/core/xray.sh"
wget -q -O /usr/local/bin/srpcom/menu.sh "$GITHUB_RAW/core/menu.sh"
wget -q -O /usr/local/bin/xray-api.py "$GITHUB_RAW/configs/xray-api.py"

chmod +x /usr/local/bin/srpcom/*.sh
chmod +x /usr/local/bin/xray-api.py

# Membuat symlink agar user bisa ketik 'menu'
ln -sf /usr/local/bin/srpcom/menu.sh /usr/bin/menu

echo -e "\n[5/7] Mengonfigurasi Layanan API & Firewall..."
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

ufw allow 22/tcp; ufw allow 80/tcp; ufw allow 443/tcp; ufw --force enable

echo -e "\n[6/7] Menginstal & Mengonfigurasi Caddy..."
apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
apt update && apt install caddy -y

cat > /etc/caddy/Caddyfile << EOF
http://$DOMAIN, https://$DOMAIN {
    handle /user_legend/* { reverse_proxy localhost:5000 }
    handle / { respond "Server is running normally." 200 }
    handle /vmessws* { reverse_proxy localhost:10001 }
    handle /vlessws* { reverse_proxy localhost:10002 }
    handle /trojanws* { reverse_proxy localhost:10003 }
}
EOF

echo -e "\n[7/7] Setup Cronjob Selesai..."
# Auto start menu
if ! grep -q "menu" /root/.profile; then echo "menu" >> /root/.profile; fi

systemctl restart xray caddy cron xray-api

clear
echo "======================================================"
echo "    INSTALASI SELESAI & BERHASIL! (V2 MODULAR)        "
echo "======================================================"
echo "Ketik 'menu' untuk masuk ke dashboard manajemen."
echo "======================================================"
