#!/bin/bash
# ==========================================
# uninstall.sh
# MODULE: AUTO UNINSTALLER XRAY, CADDY, & L2TP BY SRPCOM
# ==========================================

# Memastikan script dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan sebagai root (Gunakan 'sudo su' terlebih dahulu)."
    exit 1
fi

clear
echo "=========================================="
echo "    MEMULAI PROSES UNINSTALL SYSTEM"
echo "    (Xray, Caddy, API, L2TP & Modular)"
echo "=========================================="
echo -e "\e[31mPERINGATAN:\e[0m Semua data akun Xray, L2TP, konfigurasi, dan backup di VPS ini akan dihapus permanen!"
read -p "Apakah Anda yakin ingin melanjutkan? (y/n): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Proses uninstall dibatalkan."
    exit 0
fi

echo -e "\n[1/7] Menghentikan semua layanan (Services)..."
systemctl stop xray caddy xray-api cron ipsec xl2tpd 2>/dev/null
systemctl disable xray caddy xray-api ipsec xl2tpd 2>/dev/null

echo -e "\n[2/7] Menghapus Systemd Service..."
rm -f /etc/systemd/system/xray.service
rm -f /etc/systemd/system/xray@.service
rm -f /etc/systemd/system/xray-api.service
systemctl daemon-reload

echo -e "\n[3/7] Menghapus Xray Core, L2TP, & Konfigurasi SRPCOM..."
# Hapus file Xray Core
rm -rf /usr/local/bin/xray
rm -rf /usr/local/share/xray
rm -rf /usr/local/etc/xray
rm -rf /var/log/xray

# Hapus file Modular SRPCOM
rm -rf /usr/local/etc/srpcom
rm -rf /usr/local/bin/srpcom
rm -f /usr/local/bin/xray-api.py
rm -f /usr/bin/menu

# Hapus file kredensial dan konfigurasi L2TP/IPsec
rm -f /etc/ipsec.conf /etc/ipsec.secrets
rm -rf /etc/xl2tpd
rm -f /etc/ppp/options.xl2tpd /etc/ppp/chap-secrets

echo -e "\n[4/7] Menghapus Caddy & Paket VPN..."
apt purge caddy strongswan xl2tpd iptables-persistent -y > /dev/null 2>&1
apt autoremove -y > /dev/null 2>&1
rm -rf /etc/caddy
rm -rf /var/lib/caddy
rm -rf /var/log/caddy
rm -f /etc/apt/sources.list.d/caddy-stable.list

echo -e "\n[5/7] Membersihkan Aturan Firewall (Iptables NAT)..."
iptables -t nat -D POSTROUTING -s 192.168.42.0/24 -o eth0 -j MASQUERADE 2>/dev/null
iptables-save > /etc/iptables/rules.v4 2>/dev/null

echo -e "\n[6/7] Membersihkan Cronjob & Auto-Start..."
# Hapus cronjob yang berhubungan dengan xray dan bot
rm -f /etc/cron.d/xray_autobackup
crontab -l 2>/dev/null | grep -v "xray" | crontab -

# Hapus autostart menu di profile
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
echo "VPS Anda kini bersih dari sistem Xray, Caddy, L2TP dan Menu."
echo "Anda bisa langsung menjalankan script install kembali."
echo "======================================================"
