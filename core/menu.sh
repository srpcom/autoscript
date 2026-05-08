#!/bin/bash
# ==========================================
# menu.sh
# MODULE: MAIN MENU (ROUTER)
# Menampilkan antarmuka CLI utama dan perutean menu
# ==========================================

# Memuat Semua Modul
source /usr/local/etc/srpcom/env.conf
source /usr/local/bin/srpcom/utils.sh
source /usr/local/bin/srpcom/telegram.sh
source /usr/local/bin/srpcom/xray.sh
source /usr/local/bin/srpcom/l2tp.sh

menu_api_key() {
    clear
    echo "======================================"
    echo "       SETTING API KEY WEBSITE        "
    echo "======================================"
    current_key=$(cat /usr/local/etc/xray/api_key.conf 2>/dev/null)
    echo "Current API Key: ${current_key}"
    echo "======================================"
    echo "Ini adalah kunci akses rahasia agar website billing"
    echo "Anda bisa mengontrol Xray di server ini."
    echo "======================================"
    read -p "Input New API Key (tekan 'x' untuk batal): " new_key
    if [[ "$new_key" != "x" && "$new_key" != "X" && -n "$new_key" ]]; then
        echo "$new_key" > /usr/local/etc/xray/api_key.conf
        systemctl restart xray-api
        echo -e "\n\e[32m[SUCCESS]\e[0m API Key berhasil diubah dan sistem direstart!"
        sleep 2
    fi
    menu_settings
}

restore_xray() {
    clear
    echo "======================================"
    echo "          RESTORE DATA via VPS        "
    echo "======================================"
    echo "PENTING: Pastikan Anda sudah mengupload"
    echo "file backup (.tar.gz) ke folder /root/ "
    echo "menggunakan MobaXterm/SFTP."
    echo "======================================"
    read -p "Nama file backup (misal: xray-backup.tar.gz) atau 'x' untuk batal : " backup_name
    
    if [ -z "$backup_name" ]; then menu_settings; return; fi
    if [[ "$backup_name" == "x" || "$backup_name" == "X" ]]; then return; fi
    if [ ! -f "/root/$backup_name" ]; then
        echo -e "\n\e[31m[ERROR]\e[0m File /root/$backup_name tidak ditemukan!"
        sleep 2; return
    fi

    echo -e "\nMetode Restore:"
    echo "1. Replace (Hapus user saat ini, ganti total dengan backup)"
    echo "2. Merge   (Tambahkan user dari backup ke data saat ini)"
    read -p "Pilih Metode [1-2]: " restore_mode

    case $restore_mode in
        1)
            tar -xzf "/root/$backup_name" -C / 2>/dev/null
            echo -e "\n\e[32m[SUCCESS]\e[0m Restore Replace Berhasil!"
            ;;
        2)
            echo -e "\nMenggabungkan data (Merging)..."
            mkdir -p /tmp/restore_temp
            tar -xzf "/root/$backup_name" -C /tmp/restore_temp 2>/dev/null
            
            jq -s '.[0].inbounds[0].settings.clients = (.[0].inbounds[0].settings.clients + .[1].inbounds[0].settings.clients | unique_by(.email)) | .[0]' \
               /usr/local/etc/xray/config.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v1.json
            
            jq -s '.[0].inbounds[1].settings.clients = (.[0].inbounds[1].settings.clients + .[1].inbounds[1].settings.clients | unique_by(.email)) | .[0]' \
               /tmp/merged_v1.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v2.json
            
            jq -s '.[0].inbounds[2].settings.clients = (.[0].inbounds[2].settings.clients + .[1].inbounds[2].settings.clients | unique_by(.email)) | .[0]' \
               /tmp/merged_v2.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v3.json
            
            mv /tmp/merged_v3.json /usr/local/etc/xray/config.json
            
            cat /usr/local/etc/xray/expiry.txt /tmp/restore_temp/usr/local/etc/xray/expiry.txt | sort -k1,1 -k2,2r | sort -u -k1,1 > /tmp/merged_exp.txt
            mv /tmp/merged_exp.txt /usr/local/etc/xray/expiry.txt
            
            rm -rf /tmp/restore_temp
            echo -e "\n\e[32m[SUCCESS]\e[0m Restore Merge Berhasil!"
            ;;
        *) echo "Batal."; sleep 1; return ;;
    esac

    systemctl restart xray
    pause
}

menu_settings() {
    while true; do
        clear
        echo "▶ BACKUP & RESTORE / SETTINGS"
        echo ""
        echo " [1] AUTOBACKUP VIA BOT TELEGRAM"
        echo " [2] AUTOSEND CREATED VPN VIA BOT"
        echo " [3] BACKUP VIA BOT TELEGRAM (MANUAL)"
        echo " [4] RESTORE DATA via VPS"
        echo " [5] SETTING API KEY FOR WEBSITE"
        echo " [0/x] Back to Main Menu"
        echo ""
        read -p " Select option [0-5 or x]: " opt
        case $opt in
            1) menu_autobackup ;;
            2) menu_autosend ;;
            3) manual_backup_telegram ;;
            4) restore_xray ;;
            5) menu_api_key ;;
            0|x|X) break ;;
            *) echo "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

main_menu() {
    while true; do
        print_header # Berasal dari utils.sh
        
        echo "1. MENU XRAY (Vmess, Vless, Trojan)"
        echo "2. MENU SSH & OVPN (Segera Hadir)"
        echo "3. MENU L2TP"
        echo "4. SETTINGS (Backup/Bot/API)"
        echo "5. RESTART SERVICES (Xray, Caddy, API, L2TP)"
        echo "6. CEK STATUS SERVICES"
        echo "0. Exit CLI"
        echo ""
        read -p "Pilih opsi [0-6]: " opt
        case $opt in
            1) menu_xray ;;
            2) echo "Menu SSH akan segera ditambahkan!"; pause ;;
            3) menu_l2tp ;;
            4) menu_settings ;;
            5) 
                echo -e "\n=> Restarting Services..."
                systemctl restart xray caddy cron xray-api ipsec xl2tpd 2>/dev/null
                echo -e "=> Done!"
                sleep 1.5 ;;
            6)
                clear
                echo "======================================"
                echo "          STATUS SERVICES             "
                echo "======================================"
                echo -n "XRAY CORE     : "
                if systemctl is-active --quiet xray; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "CADDY PROXY   : "
                if systemctl is-active --quiet caddy; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "API SERVER    : "
                if systemctl is-active --quiet xray-api; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "L2TP (IPsec)  : "
                if systemctl is-active --quiet ipsec; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "L2TP (xl2tpd) : "
                if systemctl is-active --quiet xl2tpd; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo "======================================"
                pause ;;
            0) clear; exit 0 ;;
            *) echo "Tidak valid!"; sleep 1 ;;
        esac
    done
}

# Eksekusi fungsi utama
main_menu
