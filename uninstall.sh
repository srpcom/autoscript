#!/bin/bash
# ==========================================
# uninstall.sh
# MODULE: AUTO UNINSTALLER XRAY & CADDY BY SRPCOM
# ==========================================

# Memastikan script dijalankan sebagai root
if [ "${EUID}" -ne 0 ]; then
    echo -e "\e[31m[ERROR]\e[0m Script ini harus dijalankan sebagai root (Gunakan 'sudo su' terlebih dahulu)."
    exit 1
fi

clear
echo "=========================================="
echo "    MEMULAI PROSES UNINSTALL SYSTEM"
echo "    (Xray, Caddy, API & SRPCOM Modular)"
echo "=========================================="
echo -e "\e[31mPERINGATAN:\e[0m Semua data akun Xray, konfigurasi, dan backup di VPS ini akan dihapus permanen!"
read -p "Apakah Anda yakin ingin melanjutkan? (y/n): " confirm

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Proses uninstall dibatalkan."
    exit 0
fi

echo -e "\n[1/6] Menghentikan semua layanan (Services)..."
systemctl stop xray caddy xray-api cron 2>/dev/null
systemctl disable xray caddy xray-api 2>/dev/null

echo -e "\n[2/6] Menghapus Systemd Service..."
rm -f /etc/systemd/system/xray.service
rm -f /etc/systemd/system/xray@.service
rm -f /etc/systemd/system/xray-api.service
systemctl daemon-reload

echo -e "\n[3/6] Menghapus Xray Core & Konfigurasi SRPCOM..."
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

echo -e "\n[4/6] Menghapus Caddy Web Server..."
apt purge caddy -y > /dev/null 2>&1
apt autoremove -y > /dev/null 2>&1
rm -rf /etc/caddy
rm -rf /var/lib/caddy
rm -rf /var/log/caddy
rm -f /etc/apt/sources.list.d/caddy-stable.list

echo -e "\n[5/6] Membersihkan Cronjob & Auto-Start..."
# Hapus cronjob yang berhubungan dengan xray
rm -f /etc/cron.d/xray_autobackup
crontab -l 2>/dev/null | grep -v "xray" | crontab -

# Hapus autostart menu di profile
sed -i '/menu/d' /root/.profile 2>/dev/null
sed -i '/menu/d' /root/.bashrc 2>/dev/null
sed -i '/menu/d' /etc/bash.bashrc 2>/dev/null

echo -e "\n[6/6] Finalisasi pembersihan..."
systemctl restart cron
hash -r

clear
echo "======================================================"
echo "    PROSES UNINSTALL SELESAI! "
echo "======================================================"
echo "VPS Anda kini bersih dari sistem Xray, Caddy, dan Menu."
echo "Anda bisa langsung menjalankan script install kembali."
echo "======================================================"
