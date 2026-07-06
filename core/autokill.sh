#!/bin/bash
# ==========================================
# autokill.sh
# MODULE: AUTO KILL MULTI LOGIN & QUOTA LIMIT
# Mengecek limit IP dan Kuota setiap 3 Menit
# ==========================================

source /usr/local/etc/srpcom/env.conf
source /usr/local/bin/srpcom/telegram.sh

run_autokill() {
    # ==========================================
    # 1. PENGECEKAN LIMIT SSH & DROPBEAR
    # ==========================================
    if [ -f "/usr/local/etc/srpcom/ssh_limit.txt" ]; then
        grep -v "^$" /usr/local/etc/srpcom/ssh_limit.txt | while read -r user limit_ip; do
            if [[ "$limit_ip" -gt 0 ]]; then
                # Hitung jumlah proses SSH/Dropbear yang sedang aktif atas nama user ini
                total_login=$(ps -u "$user" 2>/dev/null | grep -E -c "sshd|dropbear")
                
                if [[ "$total_login" -gt "$limit_ip" ]]; then
                    # Eksekusi Penguncian (Lock) User OS
                    usermod -L "$user" 2>/dev/null
                    killall -u "$user" 2>/dev/null
                    
                    # Kirim Notifikasi ke Telegram
                    msg="🚫 *AUTO KILL SSH (MULTI LOGIN)* 🚫\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nLimit IP : $limit_ip Login\nTerdeteksi : $total_login Login\nStatus : *LOCKED*\n━━━━━━━━━━━━━━━━━━━━\n_User dapat dibuka kembali dengan fitur Renew atau Ganti Password._"
                    send_telegram "$msg"
                fi
            fi
        done
    fi

    # ==========================================
    # 2. PENGECEKAN LIMIT XRAY (VMESS, VLESS, TROJAN)
    # ==========================================
    if [ -f "/usr/local/etc/xray/limit.txt" ]; then
        
        # Salin access log Xray dan bersihkan aslinya agar perhitungan IP akurat di siklus 3 menit berikutnya
        cp /var/log/xray/access.log /tmp/xray_access.log
        > /var/log/xray/access.log
        
        # Tarik data pemakaian kuota langsung dari API Xray Internal
        stats_json=$(/usr/local/bin/xray api statsquery --server=127.0.0.1:10085 2>/dev/null)
        
        grep -v "^$" /usr/local/etc/xray/limit.txt | while read -r user limit_ip limit_quota; do
            is_killed=false
            
            # --- A. CEK LIMIT IP (MULTI LOGIN) ---
            if [[ "$limit_ip" -gt 0 ]]; then
                # Ekstrak IP unik dari log yang mengandung email/user tersebut
                ip_count=$(grep -w "$user" /tmp/xray_access.log 2>/dev/null | grep "accepted" | awk '{for(i=1;i<NF;i++){if($i=="from"){ip=$(i+1);sub(/^tcp:/,"",ip);sub(/^udp:/,"",ip);split(ip,a,":");if(a[1]!=""&&a[1]!="127.0.0.1")print a[1]}}}' | sort -u | wc -l)
                
                if [[ "$ip_count" -gt "$limit_ip" ]]; then
                    msg="🚫 *AUTO LOCK XRAY (MULTI LOGIN)* 🚫\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nLimit IP : $limit_ip IP\nTerdeteksi : $ip_count IP\nStatus : *LOCKED*\n━━━━━━━━━━━━━━━━━━━━\n_Gunakan fitur Unlock di Menu / Bot untuk membuka kunci._"
                    send_telegram "$msg"
                    is_killed=true
                    lock_reason="Multi Login ($ip_count IP / Max $limit_ip IP)"
                fi
            fi
            
            # --- B. CEK LIMIT KUOTA GB ---
            if [[ "$is_killed" == false && "$limit_quota" -gt 0 ]]; then
                # Hitung Total Downlink + Uplink menggunakan JQ
                dl=$(echo "$stats_json" | jq -r '.stat[] | select(.name == "user>>>'${user}'>>>traffic>>>downlink") | .value' 2>/dev/null)
                ul=$(echo "$stats_json" | jq -r '.stat[] | select(.name == "user>>>'${user}'>>>traffic>>>uplink") | .value' 2>/dev/null)
                
                dl=${dl:-0}
                ul=${ul:-0}
                total_bytes=$(($dl + $ul))
                
                # Konversi Bytes ke Megabytes untuk akurasi komparasi Bash
                total_mb=$(($total_bytes / 1048576))
                limit_mb=$(($limit_quota * 1024))
                
                if [[ "$total_mb" -ge "$limit_mb" ]]; then
                    total_gb=$(($total_mb / 1024))
                    msg="🚫 *AUTO LOCK XRAY (LIMIT KUOTA)* 🚫\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nLimit : $limit_quota GB\nTerpakai : $total_gb GB\nStatus : *LOCKED*\n━━━━━━━━━━━━━━━━━━━━\n_Gunakan fitur Unlock di Menu / Bot untuk membuka kunci._"
                    send_telegram "$msg"
                    is_killed=true
                    lock_reason="Limit Kuota ($total_gb GB / Max $limit_quota GB)"
                fi
            fi
            
            # --- C. EKSEKUSI PENGUNCIAN (AUTO LOCK) XRAY JIKA MELANGGAR ---
            if [[ "$is_killed" == true ]]; then
                # Simpan data client dan status locked ke /usr/local/etc/xray/locked.json
                LOCKED_FILE="/usr/local/etc/xray/locked.json"
                if [ ! -f "$LOCKED_FILE" ] || [ ! -s "$LOCKED_FILE" ]; then echo "{}" > "$LOCKED_FILE"; fi
                
                client_obj=$(jq -c '(.inbounds[] | select(.protocol == "vmess" or .protocol == "vless" or .protocol == "trojan") | .settings.clients[]) | select(.email == "'$user'")' /usr/local/etc/xray/config.json 2>/dev/null | head -n 1)
                
                if [ -n "$client_obj" ]; then
                    now_date=$(date "+%Y-%m-%d %H:%M:%S")
                    jq --arg u "$user" --arg r "$lock_reason" --arg t "$now_date" --argjson c "$client_obj" \
                       '.[$u] = {"user": $u, "reason": $r, "locked_at": $t, "client_data": $c}' \
                       "$LOCKED_FILE" > /tmp/locked.json && mv /tmp/locked.json "$LOCKED_FILE"
                fi

                # Lepas dari inbounds config.json secara aman
                jq '(.inbounds[] | select(.protocol == "vmess" or .protocol == "vless" or .protocol == "trojan") | .settings.clients) |= map(select(.email != "'$user'"))' /usr/local/etc/xray/config.json > /tmp/config.json
                
                if [ -s /tmp/config.json ]; then 
                    mv /tmp/config.json /usr/local/etc/xray/config.json
                fi
                
                touch /tmp/xray_restart.flag
            fi
            
        done
        
        # Eksekusi Restart Xray satu kali saja di akhir (Efisien)
        if [ -f /tmp/xray_restart.flag ]; then 
            systemctl restart xray
            rm -f /tmp/xray_restart.flag
        fi
        
        # Bersihkan file log sementara
        rm -f /tmp/xray_access.log
    fi
}

# ==========================================
# TRIGGER HANDLER DARI CRONJOB
# ==========================================
# Script ini akan mengeksekusi fungsinya HANYA JIKA dipanggil dengan parameter 'run_kill'
# (Agar aman jika tidak sengaja dieksekusi manual oleh user tanpa tujuan yang jelas)

if [[ "$1" == "run_kill" ]]; then
    run_autokill
    exit 0
fi
