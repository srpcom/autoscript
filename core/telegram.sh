#!/bin/bash
# ==========================================
# telegram.sh
# MODULE: TELEGRAM & BACKUP
# Berisi fungsi integrasi bot Telegram dan Backup
# ==========================================

source /usr/local/etc/srpcom/env.conf

load_bot_setting() {
    source /usr/local/etc/xray/bot_setting.conf
}

save_bot_setting() {
    cat > /usr/local/etc/xray/bot_setting.conf << CONFIG_EOF
BOT_TOKEN="${BOT_TOKEN}"
CHAT_ID="${CHAT_ID}"
AUTOBACKUP_STATUS="${AUTOBACKUP_STATUS}"
BACKUP_TIME="${BACKUP_TIME}"
AUTOSEND_STATUS="${AUTOSEND_STATUS}"
CONFIG_EOF
}

setup_autobackup_cron() {
    if [[ "$AUTOBACKUP_STATUS" == "ON" ]]; then
        if [[ "$BACKUP_TIME" == *":"* ]]; then BACKUP_TIME="24"; fi
        case $BACKUP_TIME in
            2) cron_exp="0 */12 * * *" ;;
            4) cron_exp="0 */6 * * *" ;;
            6) cron_exp="0 */4 * * *" ;;
            12) cron_exp="0 */2 * * *" ;;
            24) cron_exp="0 * * * *" ;;
            *) cron_exp="0 * * * *" ;;
        esac
        echo "$cron_exp root /usr/local/bin/srpcom/telegram.sh cron_backup" > /etc/cron.d/xray_autobackup
    else
        rm -f /etc/cron.d/xray_autobackup
    fi
    systemctl restart cron
}

send_telegram() {
    local text="$1"
    load_bot_setting
    if [[ "$AUTOSEND_STATUS" == "ON" && -n "$BOT_TOKEN" && -n "$CHAT_ID" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -H "Content-Type: application/json" \
            -d "$(jq -n --arg chat_id "$CHAT_ID" --arg text "$text" --arg pm "Markdown" '{chat_id: $chat_id, text: $text, parse_mode: $pm}')" >/dev/null 2>&1
    fi
}

manual_backup_telegram() {
    clear
    load_bot_setting
    echo "======================================"
    echo "     MANUAL BACKUP VIA TELEGRAM       "
    echo "======================================"
    if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
        echo -e "\e[31mAPI Bot atau Chat ID belum disetting!\e[0m"
        echo "Silakan setting di menu Autobackup/Autosend terlebih dahulu."
        sleep 3; return
    fi
    
    XRAY_C=$(jq '[.inbounds[].settings.clients | length] | add' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    SSH_C=$(wc -l < /usr/local/etc/srpcom/ssh_expiry.txt 2>/dev/null || echo 0)
    L2TP_C=$(wc -l < /usr/local/etc/srpcom/l2tp_expiry.txt 2>/dev/null || echo 0)
    TOTAL_ACC=$((XRAY_C + SSH_C + L2TP_C))
    
    BACKUP_NAME="srpcom-backup-$(date +"%Y%m%d_%H%M%S").tar.gz"
    BACKUP_FILE="/root/$BACKUP_NAME"

    # PERBAIKAN: Memasukkan semua file Xray, SSH, L2TP, dan Limit ke dalam Backup
    tar -czf "$BACKUP_FILE" -C / \
        usr/local/etc/xray/config.json \
        usr/local/etc/xray/expiry.txt \
        usr/local/etc/xray/limit.txt \
        usr/local/etc/xray/locked.json \
        usr/local/etc/xray/bot_setting.conf \
        usr/local/etc/srpcom/env.conf \
        usr/local/etc/srpcom/l2tp_expiry.txt \
        usr/local/etc/srpcom/ssh_expiry.txt \
        usr/local/etc/srpcom/ssh_limit.txt \
        etc/ppp/chap-secrets 2>/dev/null
    
    echo "Sedang mengirim file backup ke Telegram..."
    curl -s -F chat_id="${CHAT_ID}" -F document=@"${BACKUP_FILE}" -F caption="📦 BACKUP VPS VPN | Total Akun: ${TOTAL_ACC} | IP: ${IP_ADD} | Date: $(date)" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" > /dev/null
    
    echo -e "\n\e[32m[SUCCESS]\e[0m Backup berhasil dikirim ke Telegram!"
    pause
}

menu_autobackup() {
    clear
    load_bot_setting
    if [[ "$BACKUP_TIME" == *":"* ]]; then BACKUP_TIME="24"; fi
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   » Backup Data Via Telegram Bot «"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Status Autobackup Data Via Bot Is [$AUTOBACKUP_STATUS]"
    echo "   [1]  Start Backup Data (Enable)"
    echo "   [2]  Change Api Bot & Chat ID"
    echo "   [3]  Change Backup Frequency (Current: $BACKUP_TIME kali/hari)"
    echo "   [4]  Stop Autobackup Data (Disable)"
    echo "   [0]  Back to Settings"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
    read -p "   Select From Options [1-4 or 0] : " opt
    case $opt in
        1) AUTOBACKUP_STATUS="ON"; save_bot_setting; setup_autobackup_cron; echo "Autobackup Enabled!"; sleep 1 ;;
        2) 
            read -p "Input New API Bot: " new_api; BOT_TOKEN="$new_api"
            read -p "Input New Chat ID: " new_id; CHAT_ID="$new_id"
            save_bot_setting; echo "Data Bot Tersimpan!"; sleep 1 ;;
        3) 
            echo -e "\nPilih Frekuensi Backup:"
            echo " [1] 2 Kali Sehari  (Tiap 12 Jam)"
            echo " [2] 4 Kali Sehari  (Tiap 6 Jam)"
            echo " [3] 6 Kali Sehari  (Tiap 4 Jam)"
            echo " [4] 12 Kali Sehari (Tiap 2 Jam)"
            echo " [5] 24 Kali Sehari (Tiap 1 Jam)"
            read -p " Pilih opsi [1-5]: " freq_opt
            case $freq_opt in
                1) BACKUP_TIME="2" ;;
                2) BACKUP_TIME="4" ;;
                3) BACKUP_TIME="6" ;;
                4) BACKUP_TIME="12" ;;
                5) BACKUP_TIME="24" ;;
                *) echo "Pilihan tidak valid!"; sleep 1; return ;;
            esac
            save_bot_setting; setup_autobackup_cron; echo "Frekuensi Backup Diubah menjadi $BACKUP_TIME kali sehari!"; sleep 1.5 ;;
        4) AUTOBACKUP_STATUS="OFF"; save_bot_setting; setup_autobackup_cron; echo "Autobackup Disabled!"; sleep 1 ;;
        0) return ;;
        *) echo "Pilihan tidak valid!"; sleep 1 ;;
    esac
}

menu_autosend() {
    clear
    load_bot_setting
    echo "======================"
    echo "AUTOSEND ACCOUNT VPN"
    echo "AFTER CREATED"
    echo "======================"
    echo "STATUS AUTOSEND ACCOUNT ($AUTOSEND_STATUS !)"
    echo "Current IDtelegram : $CHAT_ID"
    echo "Current API BOT : $BOT_TOKEN"
    echo "======================"
    echo " [1] Change User ID (warn: don't use id group)"
    echo " [2] Change API BOT TELEGRAM"
    if [ "$AUTOSEND_STATUS" == "ON" ]; then
        echo " [3] Stop AUTOSEND ACCOUNT"
    else
        echo " [3] Start AUTOSEND ACCOUNT"
    fi
    echo " [0] Back to Settings"
    echo ""
    read -p " Select From Options [1-3 or 0] : " opt
    case $opt in
        1) read -p "Input New Chat ID: " new_id; CHAT_ID="$new_id"; save_bot_setting ;;
        2) read -p "Input New API Bot: " new_api; BOT_TOKEN="$new_api"; save_bot_setting ;;
        3) 
            if [ "$AUTOSEND_STATUS" == "ON" ]; then AUTOSEND_STATUS="OFF"; else AUTOSEND_STATUS="ON"; fi
            save_bot_setting ;;
        0) return ;;
        *) echo "Pilihan tidak valid!"; sleep 1 ;;
    esac
}

# Eksekusi Cronjob jika dijalankan langsung oleh sistem (Bukan menu)
if [[ "$1" == "cron_backup" ]]; then
    manual_backup_telegram
    exit 0
fi
