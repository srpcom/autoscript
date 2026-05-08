#!/bin/bash
# ==========================================
# menu.sh
# MODULE: MAIN MENU (ROUTER)
# Menampilkan antarmuka CLI utama dan perutean menu
# ==========================================

# Memuat Semua Modul
source /usr/local/bin/srpcom/utils.sh
source /usr/local/bin/srpcom/telegram.sh
source /usr/local/bin/srpcom/xray.sh

menu_settings() {
    while true; do
        clear
        echo "▶ BACKUP & RESTORE / SETTINGS"
        echo " [1] Manual Backup ke Telegram"
        echo " [2] Pengaturan Auto Backup Bot"
        echo " [3] Pengaturan Auto Send Akun"
        echo " [0] Kembali ke Menu Utama"
        read -p " Pilih opsi [0-3]: " opt
        case $opt in
            1) manual_backup_telegram ;;
            2) menu_autobackup ;;
            3) menu_autosend ;;
            0) break ;;
            *) echo "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

main_menu() {
    while true; do
        print_header # Berasal dari utils.sh
        
        echo "1. MENU XRAY (Vmess, Vless, Trojan)"
        echo "2. MENU SSH & OVPN (Segera Hadir / TODO)"
        echo "3. MENU WIREGUARD (Segera Hadir / TODO)"
        echo "4. SETTINGS (Backup/Bot/API)"
        echo "5. RESTART SERVICES"
        echo "0. Exit CLI"
        echo ""
        read -p "Pilih opsi [0-5]: " opt
        case $opt in
            1) menu_xray ;;
            2) echo "Menu SSH akan segera ditambahkan!"; pause ;;
            3) echo "Menu Wireguard akan segera ditambahkan!"; pause ;;
            4) menu_settings ;;
            5) 
                echo -e "\nRestarting services..."
                systemctl restart xray caddy cron xray-api
                sleep 1 ;;
            0) clear; exit 0 ;;
            *) echo "Tidak valid!"; sleep 1 ;;
        esac
    done
}

# Eksekusi fungsi utama
main_menu
