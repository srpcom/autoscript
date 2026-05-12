#!/bin/bash
# ==========================================
# auto_expired.sh
# MODULE: AUTO DELETE EXPIRED ACCOUNTS & SYNC LICENSE
# SQLITE & API-DRIVEN VERSION
# ==========================================

source /usr/local/etc/srpcom/env.conf
source /usr/local/bin/srpcom/telegram.sh

DB_PATH="/usr/local/etc/srpcom/database.db"
now_date=$(date +"%Y-%m-%d %H:%M:%S")

> /tmp/deleted_acc.txt

# ==========================================
# 0. SINKRONISASI LISENSI SCRIPT (CACHE LOCAL)
# ==========================================
if [ -n "$VPS_NAME" ] && [ -n "$IP_ADD" ]; then
    FORMATTED_NAME=$(echo "$VPS_NAME" | sed 's/ /%20/g')
    API_CHECK_URL="https://tuban.store/api/license/check?ip=$IP_ADD&name=$FORMATTED_NAME"
    
    # Timeout 10 detik agar tidak membebani memori jika server pusat maintenance
    RESPONSE=$(curl -sS --max-time 10 -w "\n%{http_code}" "$API_CHECK_URL" 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        HTTP_STATUS=$(echo "$RESPONSE" | tail -n1)
        JSON_BODY=$(echo "$RESPONSE" | sed '$d')
        
        if [ "$HTTP_STATUS" == "200" ]; then
            # Menggunakan grep karena jq mungkin belum terinstall di beberapa versi OS ringan
            EXP_DATE=$(echo "$JSON_BODY" | grep -o '"expires_at":"[^"]*' | cut -d'"' -f4)
            echo "STATUS=\"ACTIVE\"" > /usr/local/etc/srpcom/license.info
            echo "EXP_DATE=\"$EXP_DATE\"" >> /usr/local/etc/srpcom/license.info
        elif [ "$HTTP_STATUS" == "403" ]; then
            echo "STATUS=\"EXPIRED\"" > /usr/local/etc/srpcom/license.info
            echo "EXP_DATE=\"EXPIRED\"" >> /usr/local/etc/srpcom/license.info
        fi
    fi
fi

# ==========================================
# 1. AMBIL API KEY DARI DATABASE
# ==========================================
# Mengambil API Key dari tabel system_settings agar bisa mengakses Endpoint lokal
API_KEY=$(sqlite3 "$DB_PATH" "SELECT key_value FROM system_settings WHERE key_name='api_key';" 2>/dev/null)
if [ -z "$API_KEY" ]; then 
    API_KEY="SANGATRAHASIA123"
fi

# ==========================================
# 2. CARI AKUN EXPIRED DI DATABASE & HAPUS
# ==========================================
# Query SQL untuk mencari semua user yang exp_date-nya sudah lewat dari waktu saat ini.
# Output SQLite default dipisahkan oleh karakter '|', misalnya: client01|vmessws
EXPIRED_LIST=$(sqlite3 "$DB_PATH" "SELECT username, protocol FROM vpn_accounts WHERE expired_at != 'Lifetime' AND expired_at <= '$now_date';" 2>/dev/null)

if [ -n "$EXPIRED_LIST" ]; then
    # Loop untuk setiap user yang terdeteksi Expired
    for row in $EXPIRED_LIST; do
        user=$(echo "$row" | cut -d'|' -f1)
        prot=$(echo "$row" | cut -d'|' -f2)

        # Delegasikan proses penghapusan ke API Backend lokal
        # API akan mengurus penghapusan data DB, Config JSON, dan Perintah OS (userdel)
        curl -s -X DELETE -H "Content-Type: application/json" -H "x-api-key: $API_KEY" \
             -d "{\"user\":\"$user\"}" "http://127.0.0.1:5000/user_legend/del-$prot" > /dev/null

        # Mencatat user yang berhasil dihapus untuk laporan
        echo "👤 [${prot^^}] $user" >> /tmp/deleted_acc.txt
    done
fi

# ==========================================
# 3. KIRIM NOTIFIKASI KE BOT TELEGRAM
# ==========================================
if [ -s /tmp/deleted_acc.txt ]; then
    deleted_list=$(cat /tmp/deleted_acc.txt)
    full_msg=$(echo -e "🗑 *AUTO DELETE EXPIRED* 🗑\n━━━━━━━━━━━━━━━━━━━━\nAkun berikut telah otomatis dihapus dari Database karena masa aktif habis:\n\n${deleted_list}\n━━━━━━━━━━━━━━━━━━━━\n_Sistem Database SQLite_")
    
    # Fungsi ini berasal dari file telegram.sh
    send_telegram "$full_msg"
fi

# Bersihkan file temporari
rm -f /tmp/deleted_acc.txt
