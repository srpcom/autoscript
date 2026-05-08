#!/bin/bash
# ==========================================
# telegram.sh
# MODULE: TELEGRAM & BACKUP
# Berisi fungsi integrasi bot Telegram dan Backup
# ==========================================

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
        # Kita panggil telegram.sh dengan argumen 'cron_backup'
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
        echo -e "${RED}API Bot atau Chat ID belum disetting!${NC}"
        sleep 3; return
    fi
    
    source /usr/local/etc/srpcom/env.conf
    XRAY_C=$(jq '[.inbounds[].settings.clients | length] | add' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    BACKUP_NAME="xray-backup-$(date +"%Y%m%d_%H%M%S").tar.gz"
    BACKUP_FILE="/root/$BACKUP_NAME"

    tar -czf "$BACKUP_FILE" -C / usr/local/etc/xray/config.json usr/local/etc/xray/expiry.txt usr/local/etc/xray/bot_setting.conf usr/local/etc/srpcom/env.conf 2>/dev/null
    
    echo "Sedang mengirim file backup ke Telegram..."
    curl -s -F chat_id="${CHAT_ID}" -F document=@"${BACKUP_FILE}" -F caption="Backup XRAY | ${XRAY_C} account | IP: ${IP_ADD} | Date: $(date)" "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" > /dev/null
    
    echo -e "\n${GREEN}[SUCCESS] Backup berhasil dikirim!${NC}"
    pause
}

# --- Eksekusi Khusus Cronjob ---
if [[ "$1" == "cron_backup" ]]; then
    manual_backup_telegram
    exit 0
fi
