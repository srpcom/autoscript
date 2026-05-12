#!/bin/bash
# ==========================================
# telegram.sh
# MODULE: TELEGRAM BOT & BACKUP LOGIC (SQLITE)
# Mengelola notifikasi bot dan auto/manual backup
# ==========================================

source /usr/local/etc/srpcom/env.conf
DB_PATH="/usr/local/etc/srpcom/database.db"

# ==========================================
# FUNGSI HELPER: AMBIL PENGATURAN DARI DB
# ==========================================
get_setting() {
    sqlite3 "$DB_PATH" "SELECT key_value FROM system_settings WHERE key_name='$1';" 2>/dev/null
}

# ==========================================
# FUNGSI PENGIRIMAN PESAN
# ==========================================
send_telegram() {
    local msg="$1"
    
    local token=$(get_setting "bot_token")
    local chat_id=$(get_setting "admin_id")
    local autosend=$(get_setting "bot_autosend")
    
    if [[ "$autosend" == "ON" && -n "$token" && -n "$chat_id" ]]; then
        # Menggunakan urlencode agar karakter spesial aman
        curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
             --data-urlencode "chat_id=${chat_id}" \
             --data-urlencode "text=${msg}" \
             --data-urlencode "parse_mode=Markdown" > /dev/null
    fi
}

# ==========================================
# FUNGSI AUTO BACKUP DATABASE (LEBIH SIMPEL)
# ==========================================
run_autobackup() {
    local token=$(get_setting "bot_token")
    local chat_id=$(get_setting "admin_id")
    
    if [[ -z "$token" || -z "$chat_id" ]]; then
        echo "Bot Token atau Admin ID belum disetting."
        return
    fi

    echo "Menyiapkan file Backup Database SQLite..."
    BACKUP_DIR="/tmp/backup_vpn"
    mkdir -p $BACKUP_DIR
    
    # Cukup amankan 1 file Database (Berisi semua data VPN & Setting)
    cp $DB_PATH $BACKUP_DIR/database.db
    cp /usr/local/etc/srpcom/env.conf $BACKUP_DIR/env.conf 2>/dev/null
    
    DATE_STR=$(date +"%Y-%m-%d_%H-%M")
    ZIP_FILE="/tmp/Backup_SRPCOM_${DATE_STR}.zip"
    
    cd /tmp
    zip -r $ZIP_FILE backup_vpn > /dev/null
    
    CAPTION="📦 *AUTO BACKUP DATABASE SRPCOM V5* 📦%0A%0A🗓 Tanggal: $(date +"%Y-%m-%d")%0A⏰ Waktu: $(date +"%H:%M:%S") WIB%0A🌐 Domain: ${DOMAIN}%0A%0A_Ini adalah backup Database murni. Restore sangat mudah._"
    
    curl -s -F chat_id="${chat_id}" -F document=@"${ZIP_FILE}" -F caption="${CAPTION}" -F parse_mode="Markdown" "https://api.telegram.org/bot${token}/sendDocument" > /dev/null
    
    rm -rf $BACKUP_DIR
    rm -f $ZIP_FILE
}

# ==========================================
# MENU PENGATURAN BOT TELEGRAM
# ==========================================
menu_bot_setting() {
    while true; do
        clear
        curr_token=$(get_setting "bot_token")
        curr_id=$(get_setting "admin_id")
        curr_autosend=$(get_setting "bot_autosend")
        if [ -z "$curr_autosend" ]; then curr_autosend="OFF"; fi

        echo "======================================"
        echo "       TELEGRAM BOT SETTING V5        "
        echo "======================================"
        echo " Token Bot  : ${curr_token:-Belum Diatur}"
        echo " Admin ID   : ${curr_id:-Belum Diatur}"
        echo " Auto Send  : $curr_autosend"
        echo "======================================"
        echo "1. Set Token Bot & Admin ID"
        echo "2. Turn ON Auto Send Notif"
        echo "3. Turn OFF Auto Send Notif"
        echo "0. Back"
        echo "======================================"
        read -p "Select Option [0-3]: " opt
        case $opt in
            1) 
                read -p " Masukkan Token Bot : " new_token
                read -p " Masukkan Admin ID  : " new_id
                sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO system_settings (key_name, key_value) VALUES ('bot_token', '$new_token');"
                sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO system_settings (key_name, key_value) VALUES ('admin_id', '$new_id');"
                systemctl restart srpcom-bot 2>/dev/null
                echo -e "\n=> Konfigurasi Bot berhasil disimpan & di-restart!"; sleep 2 ;;
            2) 
                sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO system_settings (key_name, key_value) VALUES ('bot_autosend', 'ON');"
                echo -e "\n=> Auto Send Notif BERHASIL DIAKTIFKAN!"; sleep 2 ;;
            3) 
                sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO system_settings (key_name, key_value) VALUES ('bot_autosend', 'OFF');"
                echo -e "\n=> Auto Send Notif DIMATIKAN!"; sleep 2 ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

if [[ "$1" == "run_autobackup" ]]; then
    run_autobackup
    exit 0
fi
