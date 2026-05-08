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
source /usr/local/bin/srpcom/ssh.sh

change_domain() {
    clear
    echo "======================================"
    echo "          GANTI DOMAIN VPS            "
    echo "======================================"
    echo "Domain saat ini : $DOMAIN"
    echo "IP VPS          : $IP_ADD"
    echo "======================================"
    echo "PENTING: Pastikan A Record DNS domain baru"
    echo "sudah mengarah ke IP VPS ini (DNS Only)!"
    echo "======================================"
    read -p "Masukkan Domain Baru (tekan 'x' untuk batal): " new_domain
    
    if [[ "$new_domain" == "x" || "$new_domain" == "X" || -z "$new_domain" ]]; then
        return
    fi

    echo -e "\nMemeriksa resolusi DNS untuk $new_domain..."
    domain_ip=$(getent ahostsv4 "$new_domain" | awk '{ print $1 }' | head -n 1)
    
    if [[ "$domain_ip" != "$IP_ADD" ]]; then
        echo -e "\n\e[31m[ERROR]\e[0m Domain $new_domain belum mengarah ke IP $IP_ADD!"
        echo "IP dari DNS saat ini: ${domain_ip:-Kosong/Tidak Ditemukan}"
        echo "Silakan update DNS Anda (Matikan Proxy/Cloudflare Orange Cloud)"
        echo "lalu tunggu 1-2 menit dan coba lagi."
        sleep 4
        return
    fi

    echo -e "\n=> Memperbarui konfigurasi domain..."
    
    # 1. Update env.conf
    sed -i "s/^DOMAIN=.*/DOMAIN=\"$new_domain\"/g" /usr/local/etc/srpcom/env.conf
    
    # Reload env
    source /usr/local/etc/srpcom/env.conf

    # 2. Update Caddyfile
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
    handle /sshws* {
        reverse_proxy localhost:10004
    }
}
EOF

    # 3. Restart Services
    echo "=> Restarting Web Server & API..."
    systemctl restart caddy
    systemctl restart xray-api
    
    echo -e "\n\e[32m[SUCCESS]\e[0m Domain berhasil diganti menjadi $DOMAIN!"
    sleep 2
}

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
        echo " [6] GANTI DOMAIN VPS"
        echo " [0/x] Back to Main Menu"
        echo ""
        read -p " Select option [0-6 or x]: " opt
        case $opt in
            1) menu_autobackup ;;
            2) menu_autosend ;;
            3) manual_backup_telegram ;;
            4) restore_xray ;;
            5) menu_api_key ;;
            6) change_domain ;;
            0|x|X) break ;;
            *) echo "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

main_menu() {
    while true; do
        print_header # Berasal dari utils.sh
        
        echo "1. MENU XRAY (Vmess, Vless, Trojan)"
        echo "2. MENU SSH & OVPN"
        echo "3. MENU L2TP"
        echo "4. SETTINGS (Backup/Bot/API/Domain)"
        echo "5. RESTART SERVICES (All)"
        echo "6. CEK STATUS SERVICES"
        echo "0. Exit CLI"
        echo ""
        read -p "Pilih opsi [0-6]: " opt
        case $opt in
            1) menu_xray ;;
            2) menu_ssh ;;
            3) menu_l2tp ;;
            4) menu_settings ;;
            5) 
                echo -e "\n=> Restarting Services..."
                systemctl restart xray caddy cron xray-api ipsec xl2tpd dropbear ssh-ws 2>/dev/null
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
                echo -n "DROPBEAR (SSH): "
                if systemctl is-active --quiet dropbear; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "SSH-WS PROXY  : "
                if systemctl is-active --quiet ssh-ws; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo "======================================"
                pause ;;
            0) clear; exit 0 ;;
            *) echo "Tidak valid!"; sleep 1 ;;
        esac
    done
}

# Eksekusi fungsi utama
main_menu
