#!/bin/bash
# ==========================================
# uninstall.sh
# MODULE: AUTO UNINSTALLER XRAY, CADDY, L2TP, SSH
# ==========================================

if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan sebagai root (Gunakan 'sudo su' terlebih dahulu)."
    exit 1
fi

clear
echo "=========================================="
echo "    MEMULAI PROSES UNINSTALL SYSTEM"
echo "=========================================="
echo -e "\e[31mPERINGATAN:\e[0m Semua data VPN di VPS ini akan dihapus permanen!"
read -p "Apakah Anda yakin ingin melanjutkan? (y/n): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Proses uninstall dibatalkan."; exit 0
fi

echo -e "\n[1/7] Menghentikan semua layanan..."
systemctl stop xray caddy xray-api cron ipsec xl2tpd dropbear ssh-ws 2>/dev/null
systemctl disable xray caddy xray-api ipsec xl2tpd dropbear ssh-ws 2>/dev/null

echo -e "\n[2/7] Menghapus Systemd Service..."
rm -f /etc/systemd/system/xray.service /etc/systemd/system/xray@.service
rm -f /etc/systemd/system/xray-api.service /etc/systemd/system/l2tp-nat.service
rm -f /etc/systemd/system/ssh-ws.service
systemctl daemon-reload

echo -e "\n[3/7] Menghapus Xray, L2TP, SSH Proxy & Data..."
rm -rf /usr/local/bin/xray /usr/local/share/xray /usr/local/etc/xray /var/log/xray
rm -rf /usr/local/etc/srpcom /usr/local/bin/srpcom
rm -f /usr/local/bin/xray-api.py /usr/local/bin/ssh-ws.py /usr/bin/menu
rm -f /etc/ipsec.conf /etc/ipsec.secrets /etc/ppp/options.xl2tpd /etc/ppp/chap-secrets
rm -rf /etc/xl2tpd

echo -e "\n[4/7] Menghapus Caddy & Paket L2TP/SSH..."
apt purge caddy strongswan xl2tpd dropbear -y > /dev/null 2>&1
apt autoremove -y > /dev/null 2>&1
rm -rf /etc/caddy /var/lib/caddy /var/log/caddy /etc/apt/sources.list.d/caddy-stable.list

echo -e "\n[5/7] Membersihkan Aturan Firewall (NAT)..."
ETH=$(ip route ls | grep default | awk '{print $5}' | head -n 1)
iptables -t nat -D POSTROUTING -s 192.168.42.0/24 -o $ETH -j MASQUERADE 2>/dev/null
iptables-save > /etc/iptables/rules.v4 2>/dev/null

echo -e "\n[6/7] Membersihkan Cronjob & Auto-Start..."
rm -f /etc/cron.d/xray_autobackup
rm -f /etc/cron.d/srpcom_autokill
crontab -l 2>/dev/null | grep -v "xray" | crontab -
sed -i '/menu/d' /root/.profile 2>/dev/null
sed -i '/menu/d' /root/.bashrc 2>/dev/null
sed -i '/menu/d' /etc/bash.bashrc 2>/dev/null

echo -e "\n[7/7] Finalisasi pembersihan..."
systemctl restart cron
hash -r

clear
echo "======================================================"
echo "    PROSES UNINSTALL SELESAI! "
echo "======================================================"
