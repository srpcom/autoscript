#!/bin/bash
# ==========================================
# telegram.sh
# MODULE: TELEGRAM BOT & BACKUP LOGIC
# Mengelola notifikasi bot dan auto/manual backup
# ==========================================

source /usr/local/etc/srpcom/env.conf

# ==========================================
# FUNGSI PENGIRIMAN PESAN
# ==========================================
send_telegram() {
    local msg="$1"
    
    # Ambil Token dan ID dari file bot_admin (Disetting dari Menu 9)
    local token=$(grep "^BOT_TOKEN=" /usr/local/etc/xray/bot_admin.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    local chat_id=$(grep "^ADMIN_ID=" /usr/local/etc/xray/bot_admin.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    
    # Cek status izin pengiriman (Autosend)
    local autosend=$(grep "^AUTOSEND_STATUS=" /usr/local/etc/xray/bot_setting.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    
    if [[ "$autosend" == "ON" && -n "$token" && -n "$chat_id" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
            -d chat_id="${chat_id}" \
            -d text="$msg" \
            -d parse_mode="Markdown" > /dev/null 2>&1
    fi
}

# ==========================================
# FUNGSI BACKUP (DIPANGGIL DARI CRONJOB)
# ==========================================
run_autobackup() {
    local token=$(grep "^BOT_TOKEN=" /usr/local/etc/xray/bot_admin.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    local chat_id=$(grep "^ADMIN_ID=" /usr/local/etc/xray/bot_admin.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    
    if [[ -z "$token" || -z "$chat_id" ]]; then exit 0; fi
    
    local date_str=$(date +"%Y-%m-%d_%H-%M")
    local backup_file="/tmp/srpcom-backup-${date_str}.tar.gz"
    
    # Mengompresi HANYA file database akun (Xray, SSH, L2TP) tanpa settingan sistem
    local valid_files=""
    for f in /usr/local/etc/xray/config.json /usr/local/etc/xray/expiry.txt /usr/local/etc/xray/limit.txt /usr/local/etc/srpcom/l2tp_expiry.txt /usr/local/etc/srpcom/ssh_expiry.txt /usr/local/etc/srpcom/ssh_limit.txt /etc/ppp/chap-secrets; do
        if [ -f "$f" ]; then valid_files="$valid_files $f"; fi
    done
    tar -czf "$backup_file" $valid_files 2>/dev/null
    
    local caption="📦 *AUTO BACKUP HARIAN*\n━━━━━━━━━━━━━━━━━━━━\nDomain : ${DOMAIN}\nIP VPS : ${IP_ADD}\nTanggal : $(date +"%Y-%m-%d %H:%M:%S")\n━━━━━━━━━━━━━━━━━━━━\n_Pesan otomatis dari server_"
    
    # Mengirim file ke Telegram
    curl -s -X POST "https://api.telegram.org/bot${token}/sendDocument" \
        -F chat_id="${chat_id}" \
        -F document=@"${backup_file}" \
        -F caption="$(echo -e "$caption")" \
        -F parse_mode="Markdown" > /dev/null 2>&1
        
    rm -f "$backup_file"
}

# ==========================================
# MENU BACKUP MANUAL
# ==========================================
manual_backup_telegram() {
    clear
    echo "======================================"
    echo "      BACKUP DATA VIA TELEGRAM        "
    echo "======================================"
    local token=$(grep "^BOT_TOKEN=" /usr/local/etc/xray/bot_admin.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    local chat_id=$(grep "^ADMIN_ID=" /usr/local/etc/xray/bot_admin.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    
    if [[ -z "$token" || -z "$chat_id" ]]; then
        echo -e "\e[31m[ERROR]\e[0m Bot Token atau Admin ID belum disetting!"
        echo "Silakan setting terlebih dahulu di menu [9]."
        pause; return
    fi
    
    echo "=> Sedang membuat file backup..."
    local date_str=$(date +"%Y-%m-%d_%H-%M")
    local backup_file="/root/srpcom-backup-${date_str}.tar.gz"
    
    # Mengompresi HANYA file database akun (Xray, SSH, L2TP) tanpa settingan sistem
    local valid_files=""
    for f in /usr/local/etc/xray/config.json /usr/local/etc/xray/expiry.txt /usr/local/etc/xray/limit.txt /usr/local/etc/srpcom/l2tp_expiry.txt /usr/local/etc/srpcom/ssh_expiry.txt /usr/local/etc/srpcom/ssh_limit.txt /etc/ppp/chap-secrets; do
        if [ -f "$f" ]; then valid_files="$valid_files $f"; fi
    done
    tar -czf "$backup_file" $valid_files 2>/dev/null
    
    echo "=> Sedang mengirim file ke Telegram Anda..."
    local caption="📦 *MANUAL BACKUP VPS*\n━━━━━━━━━━━━━━━━━━━━\nDomain : ${DOMAIN}\nIP VPS : ${IP_ADD}\nTanggal : $(date +"%Y-%m-%d %H:%M:%S")\n━━━━━━━━━━━━━━━━━━━━"
    
    res=$(curl -s -X POST "https://api.telegram.org/bot${token}/sendDocument" \
        -F chat_id="${chat_id}" \
        -F document=@"${backup_file}" \
        -F caption="$(echo -e "$caption")" \
        -F parse_mode="Markdown")
        
    if echo "$res" | grep -q '"ok":true'; then
        echo -e "\n\e[32m[SUCCESS]\e[0m File Backup berhasil dikirim ke Bot Telegram Anda!"
        rm -f "$backup_file"
    else
        echo -e "\n\e[31m[ERROR]\e[0m Gagal mengirim backup. Pastikan Bot Token benar dan Anda sudah 'Start' bot tersebut."
    fi
    pause
}

# ==========================================
# MENU AUTOBACKUP TOGGLE DENGAN FREKUENSI
# ==========================================
menu_autobackup() {
    while true; do
        clear
        local status=$(grep "^AUTOBACKUP_STATUS=" /usr/local/etc/xray/bot_setting.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        local freq_info=""
        
        if [[ "$status" == "ON" ]]; then 
            st="\e[32m[ ON ]\e[0m"
            # Mengecek frekuensi dari file cron
            if grep -q "0 \*/12" /etc/cron.d/xray_autobackup 2>/dev/null; then freq_info="(Setiap 12 Jam / 2x Sehari)"
            elif grep -q "0 \*/6" /etc/cron.d/xray_autobackup 2>/dev/null; then freq_info="(Setiap 6 Jam / 4x Sehari)"
            elif grep -q "0 \*/4" /etc/cron.d/xray_autobackup 2>/dev/null; then freq_info="(Setiap 4 Jam / 6x Sehari)"
            elif grep -q "0 \*/2" /etc/cron.d/xray_autobackup 2>/dev/null; then freq_info="(Setiap 2 Jam / 12x Sehari)"
            elif grep -q "0 \*" /etc/cron.d/xray_autobackup 2>/dev/null; then freq_info="(Setiap 1 Jam / 24x Sehari)"
            elif grep -q "0 0" /etc/cron.d/xray_autobackup 2>/dev/null; then freq_info="(Setiap Jam 00:00 / 1x Sehari)"
            else freq_info="(Aktif)"
            fi
        else 
            st="\e[31m[ OFF ]\e[0m"
        fi
        
        echo "======================================"
        echo "     AUTO BACKUP TELEGRAM SETTING     "
        echo "======================================"
        echo -e "Status Auto Backup : $st $freq_info"
        echo "======================================"
        echo "Fitur ini akan mencadangkan seluruh data"
        echo "akun VPN Anda dan mengirimkannya ke bot"
        echo "Telegram otomatis sesuai frekuensi."
        echo "======================================"
        echo "1. Turn ON / Ubah Frekuensi Backup"
        echo "2. Turn OFF Auto Backup"
        echo "0. Back"
        echo "======================================"
        read -p "Select Option [0-2]: " opt
        case $opt in
            1) 
                echo ""
                echo "Pilih Frekuensi Backup:"
                echo "1. 1 Kali Sehari (Tengah Malam/Jam 00:00)"
                echo "2. 2 Kali Sehari (Setiap 12 Jam)"
                echo "3. 4 Kali Sehari (Setiap 6 Jam)"
                echo "4. 6 Kali Sehari (Setiap 4 Jam)"
                echo "5. 12 Kali Sehari (Setiap 2 Jam)"
                echo "6. 24 Kali Sehari (Setiap 1 Jam)"
                read -p "Pilih Frekuensi [1-6]: " freq
                
                local cron_time=""
                case $freq in
                    1) cron_time="0 0 * * *" ;;
                    2) cron_time="0 */12 * * *" ;;
                    3) cron_time="0 */6 * * *" ;;
                    4) cron_time="0 */4 * * *" ;;
                    5) cron_time="0 */2 * * *" ;;
                    6) cron_time="0 * * * *" ;;
                    *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; continue ;;
                esac

                sed -i 's/^AUTOBACKUP_STATUS=.*/AUTOBACKUP_STATUS="ON"/g' /usr/local/etc/xray/bot_setting.conf
                echo "$cron_time root /usr/local/bin/srpcom/telegram.sh run_autobackup >/dev/null 2>&1" > /etc/cron.d/xray_autobackup
                systemctl restart cron
                echo -e "\n=> Auto Backup BERHASIL DIAKTIFKAN dengan frekuensi baru!"; sleep 2 ;;
            2) 
                sed -i 's/^AUTOBACKUP_STATUS=.*/AUTOBACKUP_STATUS="OFF"/g' /usr/local/etc/xray/bot_setting.conf
                rm -f /etc/cron.d/xray_autobackup
                systemctl restart cron
                echo -e "\n=> Auto Backup DIMATIKAN!"; sleep 2 ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

# ==========================================
# MENU AUTOSEND TOGGLE
# ==========================================
menu_autosend() {
    while true; do
        clear
        local status=$(grep "^AUTOSEND_STATUS=" /usr/local/etc/xray/bot_setting.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        if [[ "$status" == "ON" ]]; then st="\e[32m[ ON ]\e[0m"; else st="\e[31m[ OFF ]\e[0m"; fi
        
        echo "======================================"
        echo "       AUTO SEND NOTIF SETTING        "
        echo "======================================"
        echo -e "Status Auto Send : $st"
        echo "======================================"
        echo "Jika ON, setiap kali Anda membuat akun"
        echo "melalui terminal VPS (CLI) atau panel,"
        echo "detail link VPN akan otomatis terkirim"
        echo "ke chat Telegram Admin."
        echo "======================================"
        echo "1. Turn ON Auto Send Notif"
        echo "2. Turn OFF Auto Send Notif"
        echo "0. Back"
        echo "======================================"
        read -p "Select Option [0-2]: " opt
        case $opt in
            1) 
                sed -i 's/^AUTOSEND_STATUS=.*/AUTOSEND_STATUS="ON"/g' /usr/local/etc/xray/bot_setting.conf
                echo -e "\n=> Auto Send Notif BERHASIL DIAKTIFKAN!"; sleep 2 ;;
            2) 
                sed -i 's/^AUTOSEND_STATUS=.*/AUTOSEND_STATUS="OFF"/g' /usr/local/etc/xray/bot_setting.conf
                echo -e "\n=> Auto Send Notif DIMATIKAN!"; sleep 2 ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

# ==========================================
# CRONJOB TRIGGER HANDLER
# ==========================================
# Jika script ini dipanggil dengan parameter 'run_autobackup' dari crontab
if [[ "$1" == "run_autobackup" ]]; then
    run_autobackup
    exit 0
fi
