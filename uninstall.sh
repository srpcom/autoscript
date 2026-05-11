#!/bin/bash
# ==========================================
# uninstall.sh
# MODULE: FULL UNINSTALLER VPN MULTIPORT V5
# Menghapus Xray, Caddy, L2TP, SSH, OVPN, BadVPN & Bot
# ==========================================

if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan sebagai root (Gunakan 'sudo su' terlebih dahulu)."
    exit 1
fi

clear
echo "====================================================="
echo "       WARNING: FULL UNINSTALLATION SCRIPT           "
echo "====================================================="
echo " Skrip ini akan MENGHAPUS TOTAL seluruh layanan VPN: "
echo " - Xray Core & Konfigurasi"
echo " - Caddy Web Server"
echo " - L2TP/IPsec (xl2tpd & strongswan)"
echo " - SSH-WS, Dropbear, & Akun-akun SSH"
echo " - OpenVPN & BadVPN UDPGW"
echo " - Bot Telegram Admin & API Backend"
echo " - Seluruh cronjob, firewall, dan file sistem srpcom"
echo "====================================================="
read -p "Apakah Anda YAKIN ingin menghapus semuanya? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo -e "\nProses uninstall dibatalkan."
    exit 0
fi

echo -e "\n[1/7] Menghentikan & Menonaktifkan Servis Sistem..."
# Stop Custom Services
systemctl stop xray-api srpcom-bot ssh-ws badvpn-7100 badvpn-7200 badvpn-7300 vpn-nat 2>/dev/null
systemctl disable xray-api srpcom-bot ssh-ws badvpn-7100 badvpn-7200 badvpn-7300 vpn-nat 2>/dev/null

# Stop Core Services
systemctl stop xray caddy ipsec xl2tpd dropbear openvpn-server@server-udp openvpn-server@server-tcp 2>/dev/null
systemctl disable xray caddy ipsec xl2tpd dropbear openvpn-server@server-udp openvpn-server@server-tcp 2>/dev/null

echo -e "\n[2/7] Menghapus Akun SSH/Dropbear yang Dibuat..."
if [ -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
    grep -v "^$" /usr/local/etc/srpcom/ssh_expiry.txt | while read -r user pass exp_date exp_time; do
        if id "$user" &>/dev/null; then
            userdel -f "$user" 2>/dev/null
        fi
    done
fi

echo -e "\n[3/7] Menghapus Xray Core..."
# Menjalankan script uninstaller resmi dari XTLS
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove >/dev/null 2>&1

echo -e "\n[4/7] Menghapus Paket VPN (Caddy, Dropbear, OpenVPN, dll)..."
apt-get purge -y caddy dropbear openvpn xl2tpd strongswan >/dev/null 2>&1
apt-get autoremove -y >/dev/null 2>&1

echo -e "\n[5/7] Membersihkan Aturan Firewall & Jaringan..."
# Menghapus iptables NAT
ETH=$(ip route ls | grep default | awk '{print $5}' | head -n 1)
iptables -t nat -D POSTROUTING -s 192.168.42.0/24 -o $ETH -j MASQUERADE 2>/dev/null
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $ETH -j MASQUERADE 2>/dev/null
iptables -t nat -D POSTROUTING -s 10.9.0.0/24 -o $ETH -j MASQUERADE 2>/dev/null
# Reset dan Nonaktifkan UFW ke kondisi pabrik
ufw --force reset >/dev/null 2>&1
ufw disable >/dev/null 2>&1

echo -e "\n[6/7] Menghapus Seluruh File & Folder Konfigurasi..."
rm -rf /usr/local/etc/srpcom
rm -rf /usr/local/bin/srpcom
rm -rf /usr/local/etc/xray
rm -rf /var/log/xray
rm -rf /etc/caddy
rm -rf /etc/openvpn
rm -rf /etc/xl2tpd
rm -rf /etc/ipsec.*
rm -f /etc/ppp/options.xl2tpd
rm -f /etc/ppp/chap-secrets
rm -f /usr/local/bin/xray-api.py
rm -f /usr/local/bin/bot-admin.py
rm -f /usr/local/bin/ssh-ws.py
rm -f /usr/local/bin/badvpn-udpgw
rm -f /usr/bin/menu

# Menghapus File Services (Systemd)
rm -f /etc/systemd/system/xray-api.service
rm -f /etc/systemd/system/srpcom-bot.service
rm -f /etc/systemd/system/ssh-ws.service
rm -f /etc/systemd/system/badvpn-7100.service
rm -f /etc/systemd/system/badvpn-7200.service
rm -f /etc/systemd/system/badvpn-7300.service
rm -f /etc/systemd/system/vpn-nat.service

# Membersihkan Daemon Cache agar tidak ada status 'failed' atau 'not-found'
systemctl daemon-reload
systemctl reset-failed

echo -e "\n[7/7] Menghapus Cronjob & Menghapus Shortcut Menu..."
rm -f /etc/cron.d/xray_autobackup
rm -f /etc/cron.d/srpcom_autokill
rm -f /etc/cron.d/auto_expired
sed -i '/menu/d' /root/.profile

clear
echo "====================================================="
echo -e "\e[32m         UNINSTALL SELESAI & BERHASIL!               \e[0m"
echo "====================================================="
echo " Seluruh layanan VPN, Bot, dan file sistem telah     "
echo " dibersihkan secara total dari VPS Anda.             "
echo "                                                     "
echo " INFO: Swap RAM 2GB & Optimasi TCP BBR sengaja       "
echo " dipertahankan karena baik untuk performa VPS Anda.  "
echo "====================================================="
