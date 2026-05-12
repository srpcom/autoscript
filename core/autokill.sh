#!/bin/bash
# ==========================================
# autokill.sh
# MODULE: AUTO KILL MULTI LOGIN & QUOTA LIMIT
# SQLITE & API-DRIVEN VERSION
# ==========================================

source /usr/local/etc/srpcom/env.conf
source /usr/local/bin/srpcom/telegram.sh

DB_PATH="/usr/local/etc/srpcom/database.db"

# Ambil API Key untuk otentikasi eksekusi lokal
API_KEY=$(sqlite3 "$DB_PATH" "SELECT key_value FROM system_settings WHERE key_name='api_key';" 2>/dev/null)
if [ -z "$API_KEY" ]; then API_KEY="SANGATRAHASIA123"; fi

run_autokill() {
    # ==========================================
    # 1. PENGECEKAN LIMIT SSH & DROPBEAR
    # ==========================================
    # Ambil user SSH yang memiliki limit IP > 0 dari Database
    SSH_USERS=$(sqlite3 "$DB_PATH" "SELECT username, limit_ip FROM vpn_accounts WHERE protocol='ssh' AND limit_ip > 0 AND status='active';" 2>/dev/null)
    
    if [ -n "$SSH_USERS" ]; then
        for row in $SSH_USERS; do
            user=$(echo "$row" | cut -d'|' -f1)
            limit_ip=$(echo "$row" | cut -d'|' -f2)
            
            # Hitung jumlah proses SSH/Dropbear yang sedang aktif atas nama user ini
            total_login=$(ps -u "$user" 2>/dev/null | grep -E -c "sshd|dropbear")
            
            if [[ "$total_login" -gt "$limit_ip" ]]; then
                # Eksekusi Penguncian (Lock) User OS
                usermod -L "$user" 2>/dev/null
                killall -u "$user" 2>/dev/null
                
                # Update status di database menjadi locked
                sqlite3 "$DB_PATH" "UPDATE vpn_accounts SET status='locked' WHERE username='$user' AND protocol='ssh';"
                
                # Kirim Notifikasi ke Telegram
                msg="🚫 *AUTO KILL SSH (MULTI LOGIN)* 🚫\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nLimit IP : $limit_ip Login\nTerdeteksi : $total_login Login\nStatus : *LOCKED*\n━━━━━━━━━━━━━━━━━━━━\n_Sistem Database SQLite_"
                send_telegram "$msg"
            fi
        done
    fi

    # ==========================================
    # 2. PENGECEKAN LIMIT XRAY (VMESS, VLESS, TROJAN)
    # ==========================================
    # Salin access log Xray dan bersihkan aslinya agar perhitungan IP akurat di siklus berikutnya
    if [ -f /var/log/xray/access.log ]; then
        cp /var/log/xray/access.log /tmp/xray_access.log
        > /var/log/xray/access.log
    else
        touch /tmp/xray_access.log
    fi
    
    # Tarik data pemakaian kuota langsung dari API Xray Internal
    stats_json=$(/usr/local/bin/xray api statsquery --server=127.0.0.1:10085 2>/dev/null)
    
    # Ambil user Xray (yang memiliki limit > 0) dari Database
    XRAY_USERS=$(sqlite3 "$DB_PATH" "SELECT username, protocol, limit_ip, limit_quota FROM vpn_accounts WHERE protocol IN ('vmessws', 'vlessws', 'trojanws') AND (limit_ip > 0 OR limit_quota > 0) AND status='active';" 2>/dev/null)
    
    if [ -n "$XRAY_USERS" ]; then
        for row in $XRAY_USERS; do
            user=$(echo "$row" | cut -d'|' -f1)
            prot=$(echo "$row" | cut -d'|' -f2)
            limit_ip=$(echo "$row" | cut -d'|' -f3)
            limit_quota=$(echo "$row" | cut -d'|' -f4)
            
            is_killed=false
            
            # --- A. CEK LIMIT IP (MULTI LOGIN) ---
            if [[ "$limit_ip" -gt 0 ]]; then
                ip_count=$(grep "email: $user$" /tmp/xray_access.log 2>/dev/null | awk '{print $3}' | cut -d: -f1 | sort -u | wc -l)
                if [[ "$ip_count" -gt "$limit_ip" ]]; then
                    msg="🚫 *AUTO KILL XRAY (MULTI LOGIN)* 🚫\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nProtocol : ${prot^^}\nLimit IP : $limit_ip IP\nTerdeteksi : $ip_count IP\nStatus : *DELETED*\n━━━━━━━━━━━━━━━━━━━━"
                    send_telegram "$msg"
                    is_killed=true
                fi
            fi
            
            # --- B. CEK LIMIT KUOTA GB ---
            if [[ "$is_killed" == false && "$limit_quota" -gt 0 ]]; then
                # Hitung Total Downlink + Uplink menggunakan JQ
                dl=$(echo "$stats_json" | jq -r '.stat[] | select(.name == "user>>>'${user}'>>>traffic>>>downlink") | .value' 2>/dev/null)
                ul=$(echo "$stats_json" | jq -r '.stat[] | select(.name == "user>>>'${user}'>>>traffic>>>uplink") | .value' 2>/dev/null)
                
                dl=${dl:-0}
                ul=${ul:-0}
                total_bytes=$((dl + ul))
                
                total_mb=$((total_bytes / 1048576))
                limit_mb=$((limit_quota * 1024))
                
                if [[ "$total_mb" -ge "$limit_mb" ]]; then
                    total_gb=$((total_mb / 1024))
                    msg="🚫 *AUTO KILL XRAY (LIMIT KUOTA)* 🚫\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nProtocol : ${prot^^}\nLimit : $limit_quota GB\nTerpakai : $total_gb GB\nStatus : *DELETED*\n━━━━━━━━━━━━━━━━━━━━"
                    send_telegram "$msg"
                    is_killed=true
                fi
            fi
            
            # --- C. EKSEKUSI PENGHAPUSAN XRAY MELALUI API ---
            if [[ "$is_killed" == true ]]; then
                # Delegasikan penghapusan aman (Update DB + Config) ke Python API
                curl -s -X DELETE -H "Content-Type: application/json" -H "x-api-key: $API_KEY" \
                     -d "{\"user\":\"$user\"}" "http://127.0.0.1:5000/user_legend/del-$prot" > /dev/null
            fi
            
        done
    fi
    
    # Bersihkan file log sementara
    rm -f /tmp/xray_access.log
}

# ==========================================
# TRIGGER HANDLER DARI CRONJOB
# ==========================================
if [[ "$1" == "run_kill" ]]; then
    run_autokill
    exit 0
fi
