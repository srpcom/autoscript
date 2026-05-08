#!/bin/bash
# ==========================================
# uninstall.sh
# MODULE: FULL UNINSTALLER (V5)
# Membersihkan VPS kembali seperti semula (Nol)
# ==========================================

if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan sebagai root (Gunakan 'sudo su' terlebih dahulu)."
    exit 1
fi

clear
echo "======================================================"
echo "       MEMULAI PROSES UNINSTALL VPN MULTIPORT V5      "
echo "======================================================"
echo "PERINGATAN: Proses ini akan menghapus SELURUH data, "
echo "akun, dan aplikasi VPN (Xray, L2TP, SSH, OVPN, BadVPN,"
echo "Bot Telegram, dll) dari VPS Anda secara permanen!"
echo "======================================================"
read -p "Apakah Anda yakin ingin melanjutkan? (y/n): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Proses dibatalkan."
    exit 0
fi

echo -e "\n[1/8] Menghapus Akun SSH/OpenVPN Linux..."
if [ -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
    while read -r user pass exp_date exp_time; do
        userdel -f "$user" 2>/dev/null
    done < /usr/local/etc/srpcom/ssh_expiry.txt
fi

echo -e "\n[2/8] Menghentikan semua layanan (Services)..."
systemctl stop xray caddy xray-api ipsec xl2tpd dropbear ssh-ws openvpn-server@server-udp openvpn-server@server-tcp badvpn-7100 badvpn-7200 badvpn-7300 srpcom-bot vpn-nat 2>/dev/null
systemctl disable xray caddy xray-api ipsec xl2tpd dropbear ssh-ws openvpn-server@server-udp openvpn-server@server-tcp badvpn-7100 badvpn-7200 badvpn-7300 srpcom-bot vpn-nat 2>/dev/null

echo -e "\n[3/8] Menghapus file Systemd Service..."
rm -f /etc/systemd/system/xray-api.service
rm -f /etc/systemd/system/ssh-ws.service
rm -f /etc/systemd/system/badvpn-*.service
rm -f /etc/systemd/system/srpcom-bot.service
rm -f /etc/systemd/system/vpn-nat.service
systemctl daemon-reload

echo -e "\n[4/8] Menghapus aplikasi dan paket bawaan..."
apt-get remove --purge caddy strongswan xl2tpd dropbear openvpn -y 2>/dev/null
apt-get autoremove -y 2>/dev/null
# Menghapus Xray core
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove 2>/dev/null

echo -e "\n[5/8] Menghapus folder dan file script..."
rm -rf /usr/local/etc/xray
rm -rf /usr/local/etc/srpcom
rm -rf /usr/local/bin/srpcom
rm -rf /var/log/xray
rm -rf /etc/caddy
rm -rf /etc/openvpn
rm -rf /etc/xl2tpd
rm -rf /etc/ppp
rm -f /usr/local/bin/ssh-ws.py
rm -f /usr/local/bin/xray-api.py
rm -f /usr/local/bin/bot-admin.py
rm -f /usr/local/bin/badvpn-udpgw
rm -f /usr/bin/menu

echo -e "\n[6/8] Membersihkan Aturan Firewall (UFW) & NAT..."
ufw delete allow 22/tcp 2>/dev/null
ufw delete allow 80/tcp 2>/dev/null
ufw delete allow 109/tcp 2>/dev/null
ufw delete allow 143/tcp 2>/dev/null
ufw delete allow 443/tcp 2>/dev/null
ufw delete allow 500/udp 2>/dev/null
ufw delete allow 4500/udp 2>/dev/null
ufw delete allow 1701/udp 2>/dev/null
ufw delete allow 1194/tcp 2>/dev/null
ufw delete allow 2200/udp 2>/dev/null
ufw delete allow 7100/udp 2>/dev/null
ufw delete allow 7200/udp 2>/dev/null
ufw delete allow 7300/udp 2>/dev/null

ETH=$(ip route ls | grep default | awk '{print $5}' | head -n 1)
iptables -t nat -D POSTROUTING -s 192.168.42.0/24 -o $ETH -j MASQUERADE 2>/dev/null
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o $ETH -j MASQUERADE 2>/dev/null
iptables -t nat -D POSTROUTING -s 10.9.0.0/24 -o $ETH -j MASQUERADE 2>/dev/null
iptables-save > /etc/iptables/rules.v4 2>/dev/null

echo -e "\n[7/8] Membersihkan Swap Memory..."
if [ -f "/swapfile" ]; then
    swapoff /swapfile 2>/dev/null
    rm -f /swapfile
    sed -i '/\/swapfile/d' /etc/fstab
fi

echo -e "\n[8/8] Membersihkan Cronjob & Auto-Start..."
rm -f /etc/cron.d/xray_autobackup
rm -f /etc/cron.d/srpcom_autokill
crontab -l 2>/dev/null | grep -v "xray" | grep -v "srpcom" | crontab - 2>/dev/null
sed -i '/menu/d' /root/.profile 2>/dev/null
sed -i '/menu/d' /root/.bashrc 2>/dev/null

clear
echo "======================================================"
echo "      UNINSTALL SELESAI! VPS KEMBALI BERSIH!          "
echo "======================================================"
echo "Sistem VPN Multiport V5 beserta OpenVPN, BadVPN,"
echo "dan Bot Telegram telah dihapus sepenuhnya."
echo "Sangat disarankan untuk melakukan REBOOT server."
echo "======================================================"
