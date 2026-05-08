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
                ip_count=$(grep "email: $user$" /tmp/xray_access.log | awk '{print $3}' | cut -d: -f1 | sort -u | wc -l)
                
                if [[ "$ip_count" -gt "$limit_ip" ]]; then
                    msg="🚫 *AUTO KILL XRAY (MULTI LOGIN)* 🚫\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nLimit IP : $limit_ip IP\nTerdeteksi : $ip_count IP\nStatus : *DELETED*\n━━━━━━━━━━━━━━━━━━━━"
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
                total_bytes=$(($dl + $ul))
                
                # Konversi Bytes ke Megabytes untuk akurasi komparasi Bash
                total_mb=$(($total_bytes / 1048576))
                limit_mb=$(($limit_quota * 1024))
                
                if [[ "$total_mb" -ge "$limit_mb" ]]; then
                    total_gb=$(($total_mb / 1024))
                    msg="🚫 *AUTO KILL XRAY (LIMIT KUOTA)* 🚫\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nLimit : $limit_quota GB\nTerpakai : $total_gb GB\nStatus : *DELETED*\n━━━━━━━━━━━━━━━━━━━━"
                    send_telegram "$msg"
                    is_killed=true
                fi
            fi
            
            # --- C. EKSEKUSI PENGHAPUSAN XRAY JIKA MELANGGAR ---
            if [[ "$is_killed" == true ]]; then
                # Hapus dari konfigurasi secara aman (Mencegah Xray config 0 bytes)
                jq '(.inbounds[] | select(.protocol == "vmess" or .protocol == "vless" or .protocol == "trojan") | .settings.clients) |= map(select(.email != "'$user'"))' /usr/local/etc/xray/config.json > /tmp/config.json
                
                if [ -s /tmp/config.json ]; then 
                    mv /tmp/config.json /usr/local/etc/xray/config.json
                fi
                
                # Hapus dari database txt
                sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
                sed -i "/^$user /d" /usr/local/etc/xray/limit.txt
                
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
