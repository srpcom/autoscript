#!/bin/bash
# ==========================================
# menu.sh
# MODULE: MAIN MENU (ROUTER)
# Menampilkan antarmuka CLI utama dan perutean menu
# Versi : 1.5 (Fitur: Dual Bot Architecture)
# ==========================================

SCRIPT_VERSION="1.5 (Dual Bot Arch)"

source /usr/local/etc/srpcom/env.conf 2>/dev/null
source /usr/local/bin/srpcom/utils.sh 2>/dev/null
source /usr/local/bin/srpcom/telegram.sh 2>/dev/null
source /usr/local/bin/srpcom/xray.sh 2>/dev/null
source /usr/local/bin/srpcom/l2tp.sh 2>/dev/null
source /usr/local/bin/srpcom/ssh.sh 2>/dev/null
source /usr/local/bin/srpcom/monitor.sh 2>/dev/null

GITHUB_RAW="https://raw.githubusercontent.com/srpcom/autoscript/main"

# ==========================================
# FUNGSI VALIDASI LISENSI GLOBAL (CEGAH BYPASS)
# ==========================================
validate_license_cli() {
    if [ -z "$VPS_NAME" ]; then
        clear
        echo "======================================"
        echo " UPDATE SISTEM: REGISTRASI NAMA VPS   "
        echo "======================================"
        echo "Sistem mendeteksi Nama VPS kosong."
        echo "Data ini wajib untuk Lisensi."
        echo "======================================"
        read -p "Masukkan Nama (Sesuai web): " input_name
        if [ -n "$input_name" ]; then
            echo "VPS_NAME=\"$input_name\"" >> /usr/local/etc/srpcom/env.conf
            VPS_NAME="$input_name"
            echo "=> Tersimpan! Memuat menu..."
            sleep 1
        else
            echo "Batal."; exit 0
        fi
    fi

    source /usr/local/etc/srpcom/license.info 2>/dev/null
    
    if [ "$STATUS" == "EXPIRED" ]; then
        CURRENT_TIME=$(date +%s)
        LAST_CHECK=0
        if [ -f /tmp/last_lic_check ]; then LAST_CHECK=$(cat /tmp/last_lic_check); fi
        TIME_DIFF=$((CURRENT_TIME - LAST_CHECK))

        if [ "$TIME_DIFF" -ge 60 ]; then
            echo "$CURRENT_TIME" > /tmp/last_lic_check
            FORMATTED_NAME=$(echo "$VPS_NAME" | sed 's/ /%20/g')
            API_CHECK_URL="https://tuban.store/api/license/check?ip=$IP_ADD&name=$FORMATTED_NAME"
            
            RESPONSE=$(curl -sS --max-time 5 -w "\n%{http_code}" "$API_CHECK_URL" 2>/dev/null)
            if [ $? -eq 0 ]; then
                HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
                if [ "$HTTP_STATUS" == "200" ]; then
                    JSON_BODY=$(echo "$RESPONSE" | sed '$d')
                    EXP_DATE_NEW=$(echo "$JSON_BODY" | grep -o '"expires_at":"[^"]*' | cut -d'"' -f4)
                    echo "STATUS=\"ACTIVE\"" > /usr/local/etc/srpcom/license.info
                    echo "EXP_DATE=\"$EXP_DATE_NEW\"" >> /usr/local/etc/srpcom/license.info
                    STATUS="ACTIVE"
                fi
            fi
        fi
    fi

    if [ "$STATUS" == "EXPIRED" ]; then
        clear
        echo -e "\e[31m╔════════════════════════════════════╗\e[0m"
        echo -e "\e[31m║         AKSES MENU DITOLAK         ║\e[0m"
        echo -e "\e[31m╚════════════════════════════════════╝\e[0m"
        echo -e "\e[33m Lisensi VPS ini telah HABIS.\e[0m"
        echo -e " Nama: $VPS_NAME"
        echo -e " IP  : $IP_ADD"
        echo -e ""
        echo -e " Perpanjang lisensi Anda di:"
        echo -e " \e[36mhttps://tuban.store/lisensi\e[0m"
        echo -e "======================================"
        exit 0
    fi
}

rebuild_shortcuts() {
    echo -e "\n=> Membangun Shortcuts (Wrapper)..."
    build_sc() {
        cat > /usr/bin/$1 << EOFSC
#!/bin/bash
source /usr/local/etc/srpcom/env.conf 2>/dev/null
source /usr/local/bin/srpcom/utils.sh 2>/dev/null
source /usr/local/bin/srpcom/telegram.sh 2>/dev/null
source /usr/local/bin/srpcom/xray.sh 2>/dev/null
source /usr/local/bin/srpcom/ssh.sh 2>/dev/null
source /usr/local/bin/srpcom/l2tp.sh 2>/dev/null
source /usr/local/bin/srpcom/monitor.sh 2>/dev/null
source /usr/local/bin/srpcom/menu.sh 2>/dev/null

validate_license_cli
$2
EOFSC
        chmod +x /usr/bin/$1
    }
    
    build_sc "add-vmess" "add_vmess_ws"
    build_sc "add-vless" "add_vless_ws"
    build_sc "add-trojan" "add_trojan_ws"
    build_sc "trial-xray" "add_trial"
    build_sc "del-xray" "delete_xray"
    build_sc "renew-xray" "renew_xray"
    build_sc "cek-xray" "detail_xray"
    build_sc "list-xray" "list_xray"
    build_sc "uuid-xray" "menu_change_uuid"
    build_sc "add-ssh" "add_ssh"
    build_sc "trial-ssh" "add_trial_ssh"
    build_sc "del-ssh" "delete_ssh"
    build_sc "renew-ssh" "renew_ssh"
    build_sc "cek-ssh" "detail_ssh"
    build_sc "list-ssh" "list_ssh"
    build_sc "add-l2tp" "add_l2tp"
    build_sc "del-l2tp" "delete_l2tp"
    build_sc "renew-l2tp" "renew_l2tp"
    build_sc "cek-l2tp" "detail_l2tp"
    build_sc "list-l2tp" "list_l2tp"
    build_sc "mon-xray" "monitor_xray"
    build_sc "mon-ssh" "monitor_ssh"
    build_sc "backup" "manual_backup_telegram"
    build_sc "restore" "restore_data"
    build_sc "set-domain" "change_domain"
    build_sc "set-sni" "menu_extra_domain"
    build_sc "set-apikey" "menu_api_key"
    build_sc "set-bot" "menu_bot_admin"
    build_sc "set-notif" "menu_bot_notif"
    build_sc "set-node" "menu_node_server"
    build_sc "set-autokill" "menu_autokill"
    build_sc "set-autoexp" "menu_auto_expired"
    build_sc "set-autobackup" "menu_autobackup"
    build_sc "set-autosend" "menu_autosend"
    build_sc "set-banner" "change_banner"
    build_sc "menu" "main_menu"
    
    cat > /usr/bin/srpcom << 'EOFSC'
#!/bin/bash
clear
echo "======================================"
echo -e "\e[36m       SRPCOM SHORTCUT COMMANDS       \e[0m"
echo "======================================"
echo -e "\e[32m[ XRAY COMMANDS ]\e[0m"
echo " add-vmess   : Buat VMess WS"
echo " add-vless   : Buat VLess WS"
echo " add-trojan  : Buat Trojan WS"
echo " trial-xray  : Buat Trial Xray"
echo " del-xray    : Hapus akun Xray"
echo " renew-xray  : Perpanjang Xray"
echo " cek-xray    : Detail & Link Xray"
echo " list-xray   : List akun Xray"
echo " uuid-xray   : Ganti UUID/Pass"
echo ""
echo -e "\e[32m[ SSH & OVPN COMMANDS ]\e[0m"
echo " add-ssh     : Buat SSH & OVPN"
echo " trial-ssh   : Buat Trial SSH"
echo " del-ssh     : Hapus akun SSH"
echo " renew-ssh   : Perpanjang SSH"
echo " cek-ssh     : Cek akun SSH"
echo " list-ssh    : List akun SSH"
echo ""
echo -e "\e[32m[ L2TP IPSEC COMMANDS ]\e[0m"
echo " add-l2tp    : Buat akun L2TP"
echo " del-l2tp    : Hapus akun L2TP"
echo " renew-l2tp  : Perpanjang L2TP"
echo " cek-l2tp    : Cek akun L2TP"
echo " list-l2tp   : List akun L2TP"
echo ""
echo -e "\e[32m[ MONITORING & SYSTEM ]\e[0m"
echo " mon-xray    : Monitor Xray"
echo " mon-ssh     : Monitor SSH"
echo " backup      : Kirim backup"
echo " restore     : Restore data VPS"
echo ""
echo -e "\e[32m[ SETTINGS COMMANDS ]\e[0m"
echo " set-domain  : Ganti domain VPS"
echo " set-sni     : Manajemen Bug/SNI"
echo " set-apikey  : Ganti API Key Node"
echo " set-node    : Manajemen Bot Master"
echo " set-bot     : Setting Telegram Bot Admin"
echo " set-notif   : Setting Telegram Bot Notif"
echo " set-autokill: Daemon Auto-Kill"
echo " set-autoexp : Daemon Auto-Expired"
echo " set-banner  : Rubah Banner SSH/VPN"
echo "======================================"
echo -e " Ketik \e[33mmenu\e[0m untuk antarmuka utama."
echo "======================================"
EOFSC
    chmod +x /usr/bin/srpcom
}

rebuild_caddyfile() {
    local main_domain="$DOMAIN"
    local main_str="http://$main_domain, https://$main_domain"
    
    cat > /tmp/temp_caddyfile << EOF
(proxy_rules) {
    handle /user_legend/* {
        reverse_proxy localhost:5000
    }
    handle /ovpn/* {
        root * /usr/local/etc/srpcom
        file_server
    }
    handle /panel/* {
        root * /usr/local/etc/srpcom
        file_server
    }
    redir /panel /panel/
    
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

$main_str {
    import proxy_rules
}
EOF

    if [ -s "/usr/local/etc/srpcom/extra_domains.txt" ]; then
        local extra_str=""
        while read -r ext_dom; do
            if [ -n "$ext_dom" ]; then
                if [ -z "$extra_str" ]; then
                    extra_str="http://$ext_dom, https://$ext_dom"
                else
                    extra_str="$extra_str, http://$ext_dom, https://$ext_dom"
                fi
            fi
        done < /usr/local/etc/srpcom/extra_domains.txt
        
        if [ -n "$extra_str" ]; then
            cat >> /tmp/temp_caddyfile << EOF

$extra_str {
    import proxy_rules
    tls internal
}
EOF
        fi
    fi

    if ! cmp -s /etc/caddy/Caddyfile /tmp/temp_caddyfile; then
        mv /tmp/temp_caddyfile /etc/caddy/Caddyfile
        nohup bash -c "sleep 2; systemctl reload caddy" >/dev/null 2>&1 &
    else
        rm -f /tmp/temp_caddyfile
    fi
}

menu_update() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║            UPDATE SCRIPT           ║"
        echo "╚════════════════════════════════════╝"
        echo " Versi: $SCRIPT_VERSION"
        echo "--------------------------------------"
        echo " 1. Update Modul Utama (menu.sh)"
        echo " 2. Update Modul Utilitas"
        echo " 3. Update Modul Xray"
        echo " 4. Update Modul SSH & OVPN"
        echo " 5. Update Modul L2TP"
        echo " 6. Update Modul Monitor"
        echo " 7. Update Auto Kill & Expired"
        echo " 8. Update API Backend & Bot"
        echo " 9. Update Modul Notifikasi"
        echo " 10. Update SEMUA Modul"
        echo " 11. Update UI Web Panel"
        echo "--------------------------------------"
        echo " 0/x. Kembali ke Menu Utama"
        echo "======================================"
        read -p " Pilih opsi [0-11 or x]: " opt
        
        case $opt in
            1) 
                echo -e "\n=> Mengunduh menu.sh..."
                wget -q -O /usr/local/bin/srpcom/menu.sh "$GITHUB_RAW/core/menu.sh"
                chmod +x /usr/local/bin/srpcom/menu.sh
                source /usr/local/bin/srpcom/menu.sh
                rebuild_shortcuts
                echo -e "\e[32m[SUCCESS]\e[0m Modul Utama diperbarui!"; sleep 1.5; exec menu ;;
            2) 
                echo -e "\n=> Mengunduh utils.sh..."
                wget -q -O /usr/local/bin/srpcom/utils.sh "$GITHUB_RAW/core/utils.sh"
                chmod +x /usr/local/bin/srpcom/utils.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul Utilitas diperbarui!"; sleep 1.5 ;;
            3) 
                echo -e "\n=> Mengunduh xray.sh..."
                wget -q -O /usr/local/bin/srpcom/xray.sh "$GITHUB_RAW/core/xray.sh"
                chmod +x /usr/local/bin/srpcom/xray.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul Xray diperbarui!"; sleep 1.5 ;;
            4) 
                echo -e "\n=> Mengunduh ssh.sh..."
                wget -q -O /usr/local/bin/srpcom/ssh.sh "$GITHUB_RAW/core/ssh.sh"
                chmod +x /usr/local/bin/srpcom/ssh.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul SSH diperbarui!"; sleep 1.5 ;;
            5) 
                echo -e "\n=> Mengunduh l2tp.sh..."
                wget -q -O /usr/local/bin/srpcom/l2tp.sh "$GITHUB_RAW/core/l2tp.sh"
                chmod +x /usr/local/bin/srpcom/l2tp.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul L2TP diperbarui!"; sleep 1.5 ;;
            6) 
                echo -e "\n=> Mengunduh monitor.sh..."
                wget -q -O /usr/local/bin/srpcom/monitor.sh "$GITHUB_RAW/core/monitor.sh"
                chmod +x /usr/local/bin/srpcom/monitor.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul Monitor diperbarui!"; sleep 1.5 ;;
            7) 
                echo -e "\n=> Mengunduh daemon otomatis..."
                wget -q -O /usr/local/bin/srpcom/autokill.sh "$GITHUB_RAW/core/autokill.sh"
                wget -q -O /usr/local/bin/srpcom/auto_expired.sh "$GITHUB_RAW/core/auto_expired.sh"
                chmod +x /usr/local/bin/srpcom/autokill.sh /usr/local/bin/srpcom/auto_expired.sh
                echo -e "\e[32m[SUCCESS]\e[0m Fitur Auto diperbarui!"; sleep 1.5 ;;
            8) 
                echo -e "\n=> Mengunduh API Backend & Bot Telegram..."
                wget -q -O /usr/local/bin/xray-api.py "$GITHUB_RAW/configs/xray-api.py"
                wget -q -O /usr/local/bin/bot-admin.py "$GITHUB_RAW/configs/bot-admin.py"
                chmod +x /usr/local/bin/xray-api.py /usr/local/bin/bot-admin.py
                systemctl daemon-reload
                systemctl restart xray-api srpcom-bot
                echo -e "\e[32m[SUCCESS]\e[0m API & Bot diperbarui!"; sleep 1.5 ;;
            9) 
                echo -e "\n=> Mengunduh telegram.sh..."
                wget -q -O /usr/local/bin/srpcom/telegram.sh "$GITHUB_RAW/core/telegram.sh"
                chmod +x /usr/local/bin/srpcom/telegram.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul Notifikasi diperbarui!"; sleep 1.5 ;;
            10) 
                echo -e "\n=> Mengunduh SEMUA modul sistem..."
                wget -q -O /usr/local/bin/srpcom/utils.sh "$GITHUB_RAW/core/utils.sh"
                wget -q -O /usr/local/bin/srpcom/telegram.sh "$GITHUB_RAW/core/telegram.sh"
                wget -q -O /usr/local/bin/srpcom/xray.sh "$GITHUB_RAW/core/xray.sh"
                wget -q -O /usr/local/bin/srpcom/l2tp.sh "$GITHUB_RAW/core/l2tp.sh"
                wget -q -O /usr/local/bin/srpcom/ssh.sh "$GITHUB_RAW/core/ssh.sh"
                wget -q -O /usr/local/bin/srpcom/monitor.sh "$GITHUB_RAW/core/monitor.sh"
                wget -q -O /usr/local/bin/srpcom/autokill.sh "$GITHUB_RAW/core/autokill.sh"
                wget -q -O /usr/local/bin/srpcom/auto_expired.sh "$GITHUB_RAW/core/auto_expired.sh"
                wget -q -O /usr/local/bin/xray-api.py "$GITHUB_RAW/configs/xray-api.py"
                wget -q -O /usr/local/bin/bot-admin.py "$GITHUB_RAW/configs/bot-admin.py"
                chmod +x /usr/local/bin/srpcom/*.sh /usr/local/bin/xray-api.py /usr/local/bin/bot-admin.py
                systemctl daemon-reload
                systemctl restart xray-api srpcom-bot
                wget -q -O /usr/local/bin/srpcom/menu.sh "$GITHUB_RAW/core/menu.sh"
                chmod +x /usr/local/bin/srpcom/menu.sh
                source /usr/local/bin/srpcom/menu.sh
                rebuild_shortcuts
                echo -e "\e[32m[SUCCESS]\e[0m Seluruh sistem berhasil diperbarui!"
                sleep 2; exec menu ;;
            11)
                echo -e "\n=> Mengunduh update UI Web Panel dari GitHub..."
                mkdir -p /usr/local/etc/srpcom/panel
                wget -q -O /usr/local/etc/srpcom/panel/index.html "$GITHUB_RAW/core/index.html"
                if [ -s /usr/local/etc/srpcom/panel/index.html ]; then
                    echo -e "\e[32m[SUCCESS]\e[0m Web Panel berhasil diperbarui!"
                else
                    echo -e "\e[31m[ERROR]\e[0m Gagal mengunduh Web Panel!"
                fi
                sleep 1.5 ;;
            0|x|X) exec menu ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_bot_admin() {
    while true; do
        clear
        echo "======================================"
        echo "      SETTING TELEGRAM BOT ADMIN      "
        echo "======================================"
        bot_token=$(grep "^BOT_TOKEN=" /usr/local/etc/xray/bot_admin.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        admin_id=$(grep "^ADMIN_ID=" /usr/local/etc/xray/bot_admin.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        
        echo "Status Service :"
        if systemctl is-active --quiet srpcom-bot; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ OFF / STANDBY ]\e[0m"; fi
        
        echo ""
        echo "bot token saat ini : ${bot_token:-OFF}"
        echo "chat id : ${admin_id:-OFF}"
        echo "--------------------------------------"
        echo " 1. Mulai / Restart Bot Admin"
        echo " 2. Ubah Token & ID Bot"
        echo " 3. Hentikan Bot (Disable)"
        echo " 0. Kembali"
        echo "======================================"
        read -p " Pilih opsi [0-3]: " opt
        case $opt in
            1)
                if [[ -n "$bot_token" && -n "$admin_id" ]]; then
                    systemctl restart srpcom-bot
                    echo -e "\n\e[32m=> Bot Admin berhasil dijalankan!\e[0m"; sleep 2
                else
                    echo -e "\n\e[31m=> Token/ID kosong! Pilih opsi 2.\e[0m"; sleep 2
                fi
                ;;
            2)
                read -p "Masukkan TOKEN BOT ADMIN : " new_token
                read -p "Masukkan CHAT ID ADMIN   : " new_id
                if [[ -n "$new_token" && -n "$new_id" ]]; then
                    cat > /usr/local/etc/xray/bot_admin.conf << EOF
BOT_TOKEN="$new_token"
ADMIN_ID="$new_id"
EOF
                    echo -e "\n\e[32m=> Bot berhasil disetting! (Silakan jalankan manual via opsi 1)\e[0m"; sleep 2
                else
                    echo -e "\n=> Token/ID tidak boleh kosong!"; sleep 2
                fi
                ;;
            3) systemctl stop srpcom-bot; echo -e "\n=> Bot dihentikan!"; sleep 2 ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_bot_notif() {
    while true; do
        clear
        echo "======================================"
        echo "     SETTING TELEGRAM NOTIF BOT       "
        echo "======================================"
        local notif_token=$(grep "^NOTIF_BOT_TOKEN=" /usr/local/etc/xray/bot_notif.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        local notif_id=$(grep "^NOTIF_CHAT_ID=" /usr/local/etc/xray/bot_notif.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        
        echo "Bot ini khusus untuk Push Notif Akun & Backup."
        echo "Mendukung ID Channel/Grup (Angka Negatif)."
        echo "--------------------------------------"
        echo "Token Notif : ${notif_token:-Belum disetting}"
        echo "Chat/Grup ID: ${notif_id:-Belum disetting}"
        echo "======================================"
        echo " 1. Ubah Token & ID Bot Notifikasi"
        echo " 0. Kembali"
        echo "======================================"
        read -p " Pilih opsi [0-1]: " opt
        case $opt in
            1)
                echo ""
                read -p "Masukkan TOKEN BOT NOTIFIKASI : " new_token
                read -p "Masukkan CHAT/GRUP ID TUJUAN  : " new_id
                if [[ -n "$new_token" && -n "$new_id" ]]; then
                    cat > /usr/local/etc/xray/bot_notif.conf << EOF
NOTIF_BOT_TOKEN="$new_token"
NOTIF_CHAT_ID="$new_id"
EOF
                    echo -e "\n\e[32m=> Bot Notifikasi berhasil disetting!\e[0m"; sleep 2
                else
                    echo -e "\n=> Token/ID tidak boleh kosong!"; sleep 2
                fi
                ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_autokill() {
    while true; do
        clear
        status_cron=$(grep "autokill.sh" /etc/cron.d/srpcom_autokill 2>/dev/null)
        if [ -n "$status_cron" ]; then st="\e[32m[ ON ]\e[0m"; else st="\e[31m[ OFF ]\e[0m"; fi
        
        echo "======================================"
        echo "      AUTO KILL & LIMIT SETTINGS      "
        echo "======================================"
        echo -e "Status Daemon (3 Menit) : $st"
        echo "======================================"
        echo " 1. Turn ON Auto Kill Daemon"
        echo " 2. Turn OFF Auto Kill Daemon"
        echo " 0. Kembali"
        echo "======================================"
        read -p " Pilih opsi [0-2]: " opt
        case $opt in
            1) 
                echo "*/3 * * * * root /usr/local/bin/srpcom/autokill.sh run_kill >/dev/null 2>&1" > /etc/cron.d/srpcom_autokill
                systemctl restart cron
                echo -e "\n=> Auto Kill DIAKTIFKAN!"; sleep 2 ;;
            2) 
                rm -f /etc/cron.d/srpcom_autokill
                systemctl restart cron
                echo -e "\n=> Auto Kill DIMATIKAN!"; sleep 2 ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_auto_expired() {
    while true; do
        clear
        status_cron=$(grep "auto_expired.sh" /etc/cron.d/auto_expired 2>/dev/null)
        if [ -n "$status_cron" ]; then st="\e[32m[ ON ]\e[0m"; else st="\e[31m[ OFF ]\e[0m"; fi
        
        echo "======================================"
        echo "         AUTO EXPIRED SETTINGS        "
        echo "======================================"
        echo -e "Status Daemon (Tiap 1 Jam) : $st"
        echo "======================================"
        echo " 1. Turn ON Auto Expired Daemon"
        echo " 2. Turn OFF Auto Expired Daemon"
        echo " 0. Kembali"
        echo "======================================"
        read -p " Pilih opsi [0-2]: " opt
        case $opt in
            1) 
                echo "0 * * * * root /usr/local/bin/srpcom/auto_expired.sh >/dev/null 2>&1" > /etc/cron.d/auto_expired
                systemctl restart cron
                echo -e "\n=> Auto Expired DIAKTIFKAN!"; sleep 2 ;;
            2) 
                rm -f /etc/cron.d/auto_expired
                systemctl restart cron
                echo -e "\n=> Auto Expired DIMATIKAN!"; sleep 2 ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

change_domain() {
    clear
    echo "======================================"
    echo "          GANTI DOMAIN VPS            "
    echo "======================================"
    echo "Domain saat ini : $DOMAIN"
    echo "IP VPS          : $IP_ADD"
    echo "======================================"
    read -p "Masukkan Domain Baru (x=Batal): " new_domain
    
    if [[ "$new_domain" == "x" || "$new_domain" == "X" || -z "$new_domain" ]]; then return; fi

    echo -e "\nMemeriksa resolusi DNS..."
    domain_ip=$(getent ahostsv4 "$new_domain" | awk '{ print $1 }' | head -n 1)
    
    if [[ "$domain_ip" != "$IP_ADD" ]]; then
        echo -e "\n\e[31m[ERROR]\e[0m Domain belum mengarah ke $IP_ADD!"
        sleep 4; return
    fi

    echo -e "\n=> Memperbarui konfigurasi..."
    sed -i "s/^DOMAIN=.*/DOMAIN=\"$new_domain\"/g" /usr/local/etc/srpcom/env.conf
    source /usr/local/etc/srpcom/env.conf
    rebuild_caddyfile

    CA_CERT=$(cat /etc/openvpn/server/keys/ca.crt 2>/dev/null)
    TA_CERT=$(cat /etc/openvpn/server/keys/ta.key 2>/dev/null)
    
    cat > /usr/local/etc/srpcom/ovpn/udp.ovpn << EOF
client
dev tun
proto udp
remote $DOMAIN 2200
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth-user-pass
key-direction 1
<ca>
$CA_CERT
</ca>
<tls-auth>
$TA_CERT
</tls-auth>
EOF

    cat > /usr/local/etc/srpcom/ovpn/tcp.ovpn << EOF
client
dev tun
proto tcp
remote $DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth-user-pass
key-direction 1
<ca>
$CA_CERT
</ca>
<tls-auth>
$TA_CERT
</tls-auth>
EOF

    systemctl restart xray-api
    echo -e "\n\e[32m[SUCCESS]\e[0m Domain diganti menjadi $DOMAIN!"
    sleep 2
}

add_extra_domain() {
    clear
    echo "======================================"
    echo "      TAMBAH SUBDOMAIN (BUG) BARU     "
    echo "======================================"
    read -p "Masukkan Domain/Subdomain: " input_bug
    
    if [[ "$input_bug" == "x" || "$input_bug" == "X" || -z "$input_bug" ]]; then return; fi
    
    echo -e "\nMemeriksa resolusi DNS..."
    
    # Skenario 1: Cek apakah input adalah Full Domain / SNI utuh
    domain_ip=$(getent ahostsv4 "$input_bug" | awk '{ print $1 }' | head -n 1)
    
    if [[ "$domain_ip" == "$IP_ADD" ]]; then
        full_domain="$input_bug"
    else
        # Skenario 2: Asumsikan input adalah prefix subdomain dari domain utama
        clean_input=${input_bug%.$DOMAIN}
        full_domain="${clean_input}.${DOMAIN}"
        domain_ip=$(getent ahostsv4 "$full_domain" | awk '{ print $1 }' | head -n 1)
        
        if [[ "$domain_ip" != "$IP_ADD" ]]; then
            echo -e "\n\e[31m[ERROR]\e[0m Resolusi DNS Gagal!"
            echo -e "Domain \e[33m$input_bug\e[0m atau \e[33m$full_domain\e[0m tidak mengarah ke IP $IP_ADD."
            sleep 4; return
        fi
    fi
    
    if grep -q "^$full_domain$" /usr/local/etc/srpcom/extra_domains.txt 2>/dev/null; then
        echo -e "\n\e[33m[INFO]\e[0m Domain sudah ada di dalam daftar."
        sleep 2; return
    fi
    
    echo "$full_domain" >> /usr/local/etc/srpcom/extra_domains.txt
    rebuild_caddyfile
    echo -e "\n\e[32m[SUCCESS]\e[0m Bug $full_domain ditambahkan!"
    sleep 2
}

del_extra_domain() {
    clear
    echo "======================================"
    echo "         HAPUS EXTRA DOMAIN           "
    echo "======================================"
    mapfile -t domains < /usr/local/etc/srpcom/extra_domains.txt
    
    if [ ${#domains[@]} -eq 0 ]; then
        echo "Belum ada domain tambahan."
        pause; return
    fi

    for i in "${!domains[@]}"; do
        echo "$((i+1)). ${domains[$i]}"
    done
    echo "0. Kembali"
    echo "======================================"
    read -p "Pilih nomor domain [1-${#domains[@]} or 0]: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#domains[@]}" ]]; then
        selected_domain="${domains[$((choice-1))]}"
        sed -i "/^${selected_domain}$/d" /usr/local/etc/srpcom/extra_domains.txt
        rebuild_caddyfile
        echo -e "\n\e[32m[SUCCESS]\e[0m Domain $selected_domain dihapus!"
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; del_extra_domain
    fi
}

list_extra_domain() {
    clear
    echo "======================================"
    echo "        DAFTAR EXTRA DOMAIN / SNI     "
    echo "======================================"
    if [ ! -s "/usr/local/etc/srpcom/extra_domains.txt" ]; then
        echo "Belum ada domain tambahan."
    else
        awk '{print "- " $1}' /usr/local/etc/srpcom/extra_domains.txt
    fi
    echo "======================================"
    pause
}

import_github_domain() {
    clear
    echo "======================================"
    echo "         IMPORT EXTRA DOMAIN          "
    echo "======================================"
    echo "=> Sedang mengambil data dari GitHub..."
    
    wget -q -O /tmp/new_domains.txt "$GITHUB_RAW/core/extra_domains.txt"
    if [ ! -s /tmp/new_domains.txt ]; then
        echo -e "\e[31m[ERROR]\e[0m Gagal mengambil data dari GitHub!"
        rm -f /tmp/new_domains.txt; sleep 2; return
    fi
    
    touch /usr/local/etc/srpcom/extra_domains.txt
    echo -e "\n\e[36m[ DAFTAR DOMAIN DI GITHUB ]\e[0m"
    awk '{print "- " $1}' /tmp/new_domains.txt
    echo "======================================"
    read -p "Import data di atas? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Batal."; rm -f /tmp/new_domains.txt; sleep 1; return
    fi

    echo -e "\n=> Memproses import dan validasi DNS..."
    local has_new=false
    while read -r raw_domain; do
        if [ -z "$raw_domain" ]; then continue; fi
        
        # Skenario 1: Cek apakah raw_domain adalah Full Domain
        domain_ip=$(getent ahostsv4 "$raw_domain" | awk '{ print $1 }' | head -n 1)
        
        if [[ "$domain_ip" == "$IP_ADD" ]]; then
            full_domain="$raw_domain"
        else
            # Skenario 2: Asumsikan raw_domain adalah prefix subdomain
            clean_input=${raw_domain%.$DOMAIN}
            full_domain="${clean_input}.${DOMAIN}"
            domain_ip=$(getent ahostsv4 "$full_domain" | awk '{ print $1 }' | head -n 1)
        fi
        
        # Validasi akhir untuk disimpan ke sistem
        if [[ "$domain_ip" == "$IP_ADD" ]]; then
            # Hindari duplikat
            if grep -q "^${full_domain}$" /usr/local/etc/srpcom/extra_domains.txt 2>/dev/null; then
                echo -e " \e[33m[SKIP]\e[0m $full_domain (Sudah ada)"
            else
                echo "$full_domain" >> /usr/local/etc/srpcom/extra_domains.txt
                echo -e " \e[32m[ OK ]\e[0m $full_domain"
                has_new=true
            fi
        else
            echo -e " \e[31m[FAIL]\e[0m $raw_domain (IP tidak cocok/tidak resolve)"
        fi
    done < /tmp/new_domains.txt
    
    rm -f /tmp/new_domains.txt

    if [ "$has_new" = true ]; then
        rebuild_caddyfile
        echo -e "\n\e[32m[SUCCESS]\e[0m Domain yang valid berhasil ditambahkan!"
    else
        echo -e "\n\e[33m[INFO]\e[0m Tidak ada data baru yang ditambahkan."
    fi
    echo "======================================"
    pause
}

menu_extra_domain() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║        MANAJEMEN BUG / SNI         ║"
        echo "╚════════════════════════════════════╝"
        echo " 1. Tambah Subdomain Baru"
        echo " 2. Hapus Subdomain"
        echo " 3. Lihat Daftar Subdomain"
        echo " 4. Import dari GitHub"
        echo "--------------------------------------"
        echo " 0/x. Kembali"
        echo "======================================"
        read -p " Pilih opsi [0-4 or x]: " opt
        case $opt in
            1) add_extra_domain ;;
            2) del_extra_domain ;;
            3) list_extra_domain ;;
            4) import_github_domain ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

change_banner() {
    while true; do
        clear
        echo "======================================"
        echo "       UBAH BANNER LOGIN SSH/VPN      "
        echo "======================================"
        echo " 1. Gunakan Template TUBAN.STORE (HTML)"
        echo " 2. Edit Manual (Editor Nano)"
        echo " 0. Kembali"
        echo "======================================"
        read -p " Pilih opsi [0-2]: " opt
        
        case $opt in
            1)
                echo -e "\n=> Menerapkan Template TUBAN.STORE..."
                cat > /etc/issue.net << EOF
<font color="#00FF00">======================================</font><br>
<font color="#00FFFF"><b>WELCOME TO SRPCOM SCRIPT</b></font><br>
<font color="#00FFFF"><b>dev : t.me/srpcomadmin</b></font><br>
<font color="#00FF00">======================================</font><br>
<font color="#00FFFF"><b>Server : $DOMAIN</b></font><br>
<font color="#FFFF00"><b>PERINGATAN PENGGUNAAN SERVER:</b></font><br>
<font color="#FFFFFF">Dilarang keras menggunakan layanan ini untuk:</font><br>
<font color="#FF0000">✖ Carding & Fraud</font><br>
<font color="#FF0000">✖ Hacking & DDOS</font><br>
<font color="#FF0000">✖ Spamming & Torrent</font><br>
<font color="#FF9900"><b>Jika melanggar, akun akan di-BANNED permanen!</b></font><br>
<font color="#00FF00">======================================</font><br>
EOF
                break
                ;;
            2)
                echo -e "\n=> Membuka editor nano..."
                sleep 1
                nano /etc/issue.net
                break
                ;;
            0) return ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done

    echo -e "\n=> Mengonfigurasi Dropbear & OpenSSH..."
    
    if grep -q "^DROPBEAR_BANNER=" /etc/default/dropbear 2>/dev/null; then
        sed -i 's|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER="/etc/issue.net"|g' /etc/default/dropbear
    else
        echo 'DROPBEAR_BANNER="/etc/issue.net"' >> /etc/default/dropbear
    fi
    
    if grep -q "^Banner" /etc/ssh/sshd_config 2>/dev/null; then
        sed -i 's|^Banner.*|Banner /etc/issue.net|g' /etc/ssh/sshd_config
    elif grep -q "^#Banner" /etc/ssh/sshd_config 2>/dev/null; then
        sed -i 's|^#Banner.*|Banner /etc/issue.net|g' /etc/ssh/sshd_config
    else
        echo "Banner /etc/issue.net" >> /etc/ssh/sshd_config
    fi
    
    echo "=> Merestart layanan SSH & Dropbear..."
    systemctl restart ssh sshd dropbear 2>/dev/null
    
    echo -e "\n\e[32m[SUCCESS]\e[0m Banner Login berhasil diperbarui dan diterapkan!"
    sleep 2
}

restore_data() {
    clear
    echo "======================================"
    echo "     RESTORE DATA (TERENKRIPSI)       "
    echo "======================================"
    echo "1. Restore dari Local VPS (Otomatis)"
    echo "2. Restore dari Link Bashupload"
    echo "0. Kembali"
    echo "======================================"
    read -p "Pilih Metode Restore [0-2]: " rest_opt

    local target_file="/tmp/target_backup.tar.gz.enc"
    rm -f "$target_file"

    if [[ "$rest_opt" == "1" ]]; then
        local local_file=$(ls /root/srpcom-backup-*.tar.gz.enc 2>/dev/null | head -n 1)
        if [ -z "$local_file" ]; then
            echo -e "\n\e[31m[ERROR]\e[0m Tidak ditemukan file backup terenkripsi di /root/"
            sleep 2; return
        fi
        echo -e "\n=> Menggunakan file: $local_file"
        cp "$local_file" "$target_file"
    elif [[ "$rest_opt" == "2" ]]; then
        echo ""
        read -p "Masukkan URL Bashupload: " cloud_url
        if [ -z "$cloud_url" ]; then return; fi
        echo "=> Mengunduh file dari Cloud..."
        wget -qO "$target_file" "$cloud_url"
        if [ ! -s "$target_file" ]; then
            echo -e "\n\e[31m[ERROR]\e[0m Gagal mengunduh file atau link tidak valid/expired!"
            sleep 2; return
        fi
    else
        return
    fi

    echo -e "\n=> Membuka dekripsi file..."
    local BACKUP_PASS="Suruan646$"

    openssl enc -aes-256-cbc -d -in "$target_file" -out /tmp/backup-ready.tar.gz -pass pass:"$BACKUP_PASS" -pbkdf2 2>/dev/null
    
    if [ $? -ne 0 ]; then
        echo -e "\n\e[31m[ERROR]\e[0m Gagal dekripsi! File rusak atau password tidak valid."
        rm -f "$target_file" /tmp/backup-ready.tar.gz
        sleep 3; return
    fi

    echo -e "\nMetode Merge Data:"
    echo "1. Replace (Ganti total)"
    echo "2. Merge (Tambahkan data lama)"
    read -p "Pilih Metode [1-2]: " restore_mode

    if [[ "$restore_mode" != "1" && "$restore_mode" != "2" ]]; then
        echo "Batal."; rm -f "$target_file" /tmp/backup-ready.tar.gz; sleep 1; return
    fi

    echo -e "\nMemproses pemulihan data..."
    mkdir -p /tmp/restore_temp
    tar -xzf /tmp/backup-ready.tar.gz -C /tmp/restore_temp 2>/dev/null
    
    if [ "$(cat /tmp/restore_temp/usr/local/etc/srpcom/backup_sign.txt 2>/dev/null)" != "SRPCOM_V5_VALID" ]; then
        echo -e "\n\e[31m[ERROR]\e[0m Validasi Gagal! File ini bukan file backup resmi dari sistem SRPCOM V5."
        rm -rf /tmp/restore_temp "$target_file" /tmp/backup-ready.tar.gz
        sleep 3; return
    fi
    
    if [ -f "/tmp/restore_temp/usr/local/etc/xray/config.json" ]; then
        if [ "$restore_mode" == "1" ]; then
            jq -s '.[0].inbounds[0].settings.clients = .[1].inbounds[0].settings.clients | .[0]' \
               /usr/local/etc/xray/config.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v1.json
            jq -s '.[0].inbounds[1].settings.clients = .[1].inbounds[1].settings.clients | .[0]' \
               /tmp/merged_v1.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v2.json
            jq -s '.[0].inbounds[2].settings.clients = .[1].inbounds[2].settings.clients | .[0]' \
               /tmp/merged_v2.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v3.json
            mv /tmp/merged_v3.json /usr/local/etc/xray/config.json
        else
            jq -s '.[0].inbounds[0].settings.clients = (.[0].inbounds[0].settings.clients + .[1].inbounds[0].settings.clients | unique_by(.email)) | .[0]' \
               /usr/local/etc/xray/config.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v1.json
            jq -s '.[0].inbounds[1].settings.clients = (.[0].inbounds[1].settings.clients + .[1].inbounds[1].settings.clients | unique_by(.email)) | .[0]' \
               /tmp/merged_v1.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v2.json
            jq -s '.[0].inbounds[2].settings.clients = (.[0].inbounds[2].settings.clients + .[1].inbounds[2].settings.clients | unique_by(.email)) | .[0]' \
               /tmp/merged_v2.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v3.json
            mv /tmp/merged_v3.json /usr/local/etc/xray/config.json
        fi
    fi
    
    ACCOUNT_FILES="usr/local/etc/xray/expiry.txt usr/local/etc/xray/limit.txt usr/local/etc/srpcom/l2tp_expiry.txt usr/local/etc/srpcom/ssh_expiry.txt usr/local/etc/srpcom/ssh_limit.txt etc/ppp/chap-secrets"
    
    for txt_file in $ACCOUNT_FILES; do
        if [ -f "/tmp/restore_temp/$txt_file" ]; then
            touch "/$txt_file" 2>/dev/null
            if [ "$restore_mode" == "1" ]; then
                cp -f "/tmp/restore_temp/$txt_file" "/$txt_file"
            else
                cat "/$txt_file" "/tmp/restore_temp/$txt_file" | sort -k1,1 -u > "/tmp/merged_$(basename $txt_file)"
                mv "/tmp/merged_$(basename $txt_file)" "/$txt_file"
            fi
        fi
    done
    
    if [ -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
        echo "=> Membangun OS User SSH..."
        while read -r user pass exp_date exp_time; do
            if [ -n "$user" ] && ! id "$user" &>/dev/null; then
                useradd -e "$exp_date" -s /bin/false -M "$user"
                echo -e "$pass\n$pass" | passwd "$user" &> /dev/null
            fi
        done < /usr/local/etc/srpcom/ssh_expiry.txt
    fi

    rm -rf /tmp/restore_temp "$target_file" /tmp/backup-ready.tar.gz
    systemctl restart xray caddy xray-api ipsec xl2tpd dropbear ssh-ws srpcom-bot
    echo -e "\n\e[32m[SUCCESS]\e[0m Restore Berhasil!"
    pause
}

menu_api_key() {
    while true; do
        clear
        echo "======================================"
        echo "       SETTING API KEY WEBSITE        "
        echo "======================================"
        current_key=$(cat /usr/local/etc/xray/api_key.conf 2>/dev/null)
        auth_status=$(cat /usr/local/etc/xray/api_auth.conf 2>/dev/null)

        if [[ -z "$auth_status" ]]; then auth_status="OFF"; fi

        if [[ "$auth_status" == "ON" ]]; then
            st="\e[32m[ ON ]\e[0m"
        else
            st="\e[31m[ OFF ]\e[0m"
        fi

        echo -e "Status API Auth : $st"
        if [[ "$auth_status" == "ON" ]]; then
            echo "Web Panel       : https://${DOMAIN}/panel"
        fi
        echo "Current Key     : ${current_key}"
        echo "======================================"
        echo " 1. Turn ON / OFF API Authentication"
        echo " 2. Ubah API Key"
        echo " 0. Kembali"
        echo "======================================"
        read -p " Pilih opsi [0-2]: " opt
        case $opt in
            1)
                if [[ "$auth_status" == "ON" ]]; then
                    echo "OFF" > /usr/local/etc/xray/api_auth.conf
                    echo -e "\n=> API Authentication DIMATIKAN!"
                else
                    echo "ON" > /usr/local/etc/xray/api_auth.conf
                    echo -e "\n=> API Authentication DIAKTIFKAN!"
                fi
                systemctl restart xray-api
                sleep 2
                ;;
            2)
                echo ""
                read -p "Input New Key (x=batal): " new_key
                if [[ "$new_key" != "x" && "$new_key" != "X" && -n "$new_key" ]]; then
                    echo "$new_key" > /usr/local/etc/xray/api_key.conf
                    systemctl restart xray-api
                    echo -e "\n\e[32m[SUCCESS]\e[0m Berhasil disimpan!"
                    sleep 2
                fi
                ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_node_server() {
    local srv_file="/usr/local/etc/xray/servers.json"
    if [ ! -f "$srv_file" ]; then echo '{"nodes": []}' > "$srv_file"; fi

    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║        MANAJEMEN NODE SERVER       ║"
        echo "╚════════════════════════════════════╝"
        echo "Daftar Remote Server:"
        local count=$(jq '.nodes | length' "$srv_file" 2>/dev/null || echo 0)
        if [[ "$count" -eq 0 ]]; then
            echo " - Kosong"
        else
            jq -r '.nodes | to_entries | .[] | " \(.key+1). \(.value.name)"' "$srv_file"
        fi
        echo "--------------------------------------"
        echo " 1. Tambah Node Server"
        echo " 2. Hapus Node Server"
        echo " 0. Kembali"
        echo "======================================"
        read -p " Pilih opsi [0-2]: " opt
        case $opt in
            1)
                echo ""
                read -p "Nama Server (misal SG 1): " n_name
                read -p "Domain Server: " n_dom
                read -p "API Key Server: " n_key
                if [[ -n "$n_name" && -n "$n_dom" && -n "$n_key" ]]; then
                    jq --arg name "$n_name" --arg dom "$n_dom" --arg key "$n_key" \
                       '.nodes += [{"name": $name, "domain": $dom, "api_key": $key}]' "$srv_file" > /tmp/srv.json
                    mv /tmp/srv.json "$srv_file"
                    systemctl restart srpcom-bot
                    echo -e "\n=> Berhasil ditambahkan!"; sleep 2
                fi
                ;;
            2)
                echo ""
                read -p "Pilih nomor yang dihapus: " del_id
                if [[ "$del_id" =~ ^[0-9]+$ ]] && [[ "$del_id" -gt 0 ]] && [[ "$del_id" -le "$count" ]]; then
                    local idx=$((del_id-1))
                    jq "del(.nodes[$idx])" "$srv_file" > /tmp/srv.json
                    mv /tmp/srv.json "$srv_file"
                    systemctl restart srpcom-bot
                    echo -e "\n=> Berhasil dihapus!"; sleep 2
                fi
                ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_settings() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║        SETTINGS & BACKUP           ║"
        echo "╚════════════════════════════════════╝"
        echo " 1. Autobackup via Bot Telegram"
        echo " 2. Autosend Created VPN via Bot"
        echo " 3. Backup Manual"
        echo " 4. Restore Data VPS"
        echo " 5. Setting API Key Web"
        echo " 6. Ganti Domain VPS"
        echo " 7. Setting Auto-Kill"
        echo " 8. Setting Auto-Expired"
        echo " 9. Setting Telegram Admin Bot"
        echo " 10. Setting Telegram Notif Bot"
        echo " 11. Manajemen Bug / SNI"
        echo " 12. Manajemen Node Server"
        echo " 13. Rubah Banner Login SSH/VPN"
        echo "--------------------------------------"
        echo " 0/x. Kembali ke Menu Utama"
        echo "======================================"
        read -p " Pilih opsi [0-13 or x]: " opt
        case $opt in
            1) menu_autobackup ;;
            2) menu_autosend ;;
            3) manual_backup_telegram ;;
            4) restore_data ;;
            5) menu_api_key ;;
            6) change_domain ;;
            7) menu_autokill ;;
            8) menu_auto_expired ;;
            9) menu_bot_admin ;;
            10) menu_bot_notif ;;
            11) menu_extra_domain ;;
            12) menu_node_server ;;
            13) change_banner ;;
            0|x|X) break ;;
            *) echo "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

main_menu() {
    while true; do
        print_header
        
        echo " 1. MENU XRAY (Vmess, Vless, Trojan)"
        echo " 2. MENU SSH & OVPN"
        echo " 3. MENU L2TP"
        echo " 4. MONITORING PANEL"
        echo " 5. SETTINGS (Backup/Autokill/Bot)"
        echo " 6. RESTART SERVICES (All)"
        echo " 7. CEK STATUS SERVICES"
        echo " 8. UPDATE SCRIPT"
        echo " 0/x. Exit CLI"
        echo ""
        read -p " Pilih opsi [0-8 or x]: " opt
        case $opt in
            1) menu_xray ;;
            2) menu_ssh ;;
            3) menu_l2tp ;;
            4) menu_monitor ;;
            5) menu_settings ;;
            6) 
                echo -e "\n=> Restarting Services..."
                systemctl reload caddy 2>/dev/null
                systemctl restart xray cron xray-api ipsec xl2tpd srpcom-bot 2>/dev/null
                echo -e "=> Selesai!"
                sleep 2 ;;
            7)
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
                echo -n "ADMIN BOT     : "
                if systemctl is-active --quiet srpcom-bot; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ OFF / STANDBY ]\e[0m"; fi
                echo -n "L2TP (IPsec)  : "
                if systemctl is-active --quiet ipsec; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "L2TP (xl2tpd) : "
                if systemctl is-active --quiet xl2tpd; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "DROPBEAR (SSH): "
                if systemctl is-active --quiet dropbear; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "SSH-WS PROXY  : "
                if systemctl is-active --quiet ssh-ws; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "OPENVPN SERVER: "
                if systemctl is-active --quiet openvpn-server@server-udp; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "BADVPN (UDPGW): "
                if systemctl is-active --quiet badvpn-7100; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo "======================================"
                pause ;;
            8) menu_update ;;
            0|x|X) clear; exit 0 ;;
            *) echo "Tidak valid!"; sleep 1 ;;
        esac
    done
}
