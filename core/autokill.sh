#!/bin/bash
# ==========================================
# autokill.sh
# MODULE: AUTO KILL & LIMIT TRACKER
# Mengecek dan mengunci akun yang melanggar batas Limit IP dan Kuota
# ==========================================

source /usr/local/etc/srpcom/env.conf
source /usr/local/bin/srpcom/telegram.sh

API_URL="http://127.0.0.1:5000/user_legend"
API_KEY=$(cat /usr/local/etc/xray/api_key.conf 2>/dev/null)

run_kill() {
    # =======================================
    # 1. CEK LIMIT KUOTA XRAY
    # =======================================
    python3 -c "
import json, os, subprocess
try:
    out = subprocess.run(['/usr/local/bin/xray', 'api', 'statsquery', '--server=127.0.0.1:10085'], capture_output=True, text=True)
    data = json.loads(out.stdout)
    stats = {}
    for item in data.get('stat', []):
        parts = item['name'].split('>>>')
        if len(parts) >= 4 and parts[0] == 'user':
            user = parts[1]
            if user not in stats: stats[user] = {'downlink': 0, 'uplink': 0}
            stats[user][parts[3]] = item.get('value', 0)
    
    limit_data = {}
    if os.path.exists('/usr/local/etc/xray/limit.txt'):
        with open('/usr/local/etc/xray/limit.txt', 'r') as f:
            for line in f:
                p = line.strip().split()
                if len(p) >= 3: limit_data[p[0]] = int(p[2])
                
    locked = {}
    if os.path.exists('/usr/local/etc/xray/locked.json'):
        with open('/usr/local/etc/xray/locked.json', 'r') as f: locked = json.load(f)
        
    for user, s in stats.items():
        tot_gb = (s['downlink'] + s['uplink']) / (1024**3)
        limit_gb = limit_data.get(user, 0)
        if limit_gb > 0 and tot_gb > limit_gb and user not in locked:
            print(f'LOCK_XRAY_QUOTA {user} {tot_gb:.2f} {limit_gb}')
except: pass
" > /tmp/xray_quota_action.txt

    while read -r action user usage limit; do
        if [ "$action" == "LOCK_XRAY_QUOTA" ]; then
            curl -s -X GET "$API_URL/lock-xray" -H "x-api-key: $API_KEY" -H "Content-Type: application/json" -d "{\"user\": \"$user\"}" >/dev/null
            msg_tg=$(echo -e "⚠️ *LIMIT KUOTA TERCAPAI* ⚠️\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nProtokol : Xray\nPemakaian : $usage GB\nBatas : $limit GB\nStatus : 🔒 *AKUN DIKUNCI (LOCKED)*\n━━━━━━━━━━━━━━━━━━━━\n_Pesan otomatis dari server._")
            send_telegram "$msg_tg"
        fi
    done < /tmp/xray_quota_action.txt

    # =======================================
    # 2. CEK LIMIT IP XRAY
    # =======================================
    if [ -f "/var/log/xray/access.log" ]; then
        tail -n 3000 /var/log/xray/access.log | grep "accepted" | grep -v "127.0.0.1" | awk '{print $7, $3}' | sed 's/tcp://g' | sed 's/udp://g' | cut -d: -f1 | sort | uniq | awk '{ip_count[$1]++} END {for (user in ip_count) {print user " " ip_count[user]}}' > /tmp/xray_ip_count.txt
        
        while read -r user active_ip; do
            limit_ip=$(grep "^$user " /usr/local/etc/xray/limit.txt 2>/dev/null | awk '{print $2}')
            if [ -n "$limit_ip" ] && [ "$limit_ip" -gt 0 ] && [ "$active_ip" -gt "$limit_ip" ]; then
                is_locked=$(grep "\"$user\"" /usr/local/etc/xray/locked.json 2>/dev/null)
                if [ -z "$is_locked" ]; then
                    curl -s -X GET "$API_URL/lock-xray" -H "x-api-key: $API_KEY" -H "Content-Type: application/json" -d "{\"user\": \"$user\"}" >/dev/null
                    msg_tg=$(echo -e "⚠️ *MULTI-LOGIN TERDETEKSI* ⚠️\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nProtokol : Xray\nIP Aktif : $active_ip IP\nBatas : $limit_ip IP\nStatus : 🔒 *AKUN DIKUNCI (LOCKED)*\n━━━━━━━━━━━━━━━━━━━━\n_Pesan otomatis dari server._")
                    send_telegram "$msg_tg"
                fi
            fi
        done < /tmp/xray_ip_count.txt
    fi

    # =======================================
    # 3. CEK LIMIT IP SSH
    # =======================================
    netstat -tnpa | grep ESTABLISHED | grep -E "dropbear|sshd" | awk '{print $7, $5}' | cut -d'/' -f1 > /tmp/ssh_raw.txt
    > /tmp/ssh_users.txt
    while read -r pid ip; do
        user=$(ps -o user= -p $pid 2>/dev/null | tail -n 1 | tr -d ' ')
        ip=$(echo $ip | cut -d':' -f1)
        if [ -n "$user" ] && [ "$user" != "root" ]; then
            echo "$user $ip" >> /tmp/ssh_users.txt
        fi
    done < /tmp/ssh_raw.txt
    
    cat /tmp/ssh_users.txt | sort | uniq | awk '{ip_count[$1]++} END {for (user in ip_count) {print user " " ip_count[user]}}' > /tmp/ssh_ip_count.txt
    
    while read -r user active_ip; do
        limit_ip=$(grep "^$user " /usr/local/etc/srpcom/ssh_limit.txt 2>/dev/null | awk '{print $2}')
        if [ -n "$limit_ip" ] && [ "$limit_ip" -gt 0 ] && [ "$active_ip" -gt "$limit_ip" ]; then
            # Cek apakah user belum dilock di linux (! di dalam string bayangan)
            status_passwd=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
            if [[ "$status_passwd" != "L" && "$status_passwd" != "LK" ]]; then
                curl -s -X POST "$API_URL/lock-ssh" -H "x-api-key: $API_KEY" -H "Content-Type: application/json" -d "{\"user\": \"$user\"}" >/dev/null
                msg_tg=$(echo -e "⚠️ *MULTI-LOGIN TERDETEKSI* ⚠️\n━━━━━━━━━━━━━━━━━━━━\nUser : \`$user\`\nProtokol : SSH/Dropbear\nIP Aktif : $active_ip IP\nBatas : $limit_ip IP\nStatus : 🔒 *AKUN DIKUNCI (LOCKED)*\n━━━━━━━━━━━━━━━━━━━━\n_Pesan otomatis dari server._")
                send_telegram "$msg_tg"
            fi
        fi
    done < /tmp/ssh_ip_count.txt
}

# Jika file dijalankan oleh cron dengan argumen run_kill
if [ "$1" == "run_kill" ]; then
    run_kill
fi
