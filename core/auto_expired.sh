#!/bin/bash
# ==========================================
# auto_expired.sh
# MODULE: AUTO DELETE EXPIRED ACCOUNTS & SYNC LICENSE
# ==========================================

source /usr/local/etc/srpcom/env.conf
source /usr/local/bin/srpcom/telegram.sh

now_sec=$(date +%s)
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
            EXP_DATE=$(echo "$JSON_BODY" | jq -r '.data.expires_at')
            echo "STATUS=\"ACTIVE\"" > /usr/local/etc/srpcom/license.info
            echo "EXP_DATE=\"$EXP_DATE\"" >> /usr/local/etc/srpcom/license.info
        elif [ "$HTTP_STATUS" == "403" ]; then
            echo "STATUS=\"EXPIRED\"" > /usr/local/etc/srpcom/license.info
            echo "EXP_DATE=\"EXPIRED\"" >> /usr/local/etc/srpcom/license.info
        fi
        # Jika respon 500/Timeout, hiraukan (gunakan cache terakhir untuk mencegah Lock tanpa sengaja)
    fi
fi

# ==========================================
# 1. CEK SSH & OVPN EXPIRED
# ==========================================
if [ -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
    grep -v "^$" /usr/local/etc/srpcom/ssh_expiry.txt | while read -r user pass exp_date exp_time; do
        if [[ "$exp_date" == "Lifetime" || -z "$exp_date" ]]; then continue; fi
        exp_sec=$(date -d "$exp_date $exp_time" +%s 2>/dev/null)
        if [[ -n "$exp_sec" && $now_sec -ge $exp_sec ]]; then
            userdel -f "$user" 2>/dev/null
            sed -i "/^$user /d" /usr/local/etc/srpcom/ssh_expiry.txt
            sed -i "/^$user /d" /usr/local/etc/srpcom/ssh_limit.txt
            echo "👤 SSH / OVPN: $user" >> /tmp/deleted_acc.txt
        fi
    done
fi

# ==========================================
# 2. CEK XRAY EXPIRED (VMESS, VLESS, TROJAN)
# ==========================================
if [ -f "/usr/local/etc/xray/expiry.txt" ]; then
    grep -v "^$" /usr/local/etc/xray/expiry.txt | while read -r user exp_date exp_time; do
        if [[ "$exp_date" == "Lifetime" || -z "$exp_date" ]]; then continue; fi
        exp_sec=$(date -d "$exp_date $exp_time" +%s 2>/dev/null)
        if [[ -n "$exp_sec" && $now_sec -ge $exp_sec ]]; then
            jq '(.inbounds[] | select(.protocol == "vmess" or .protocol == "vless" or .protocol == "trojan") | .settings.clients) |= map(select(.email != "'$user'"))' /usr/local/etc/xray/config.json > /tmp/config.json
            
            if [ -s /tmp/config.json ]; then
                mv /tmp/config.json /usr/local/etc/xray/config.json
            fi
            
            sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
            sed -i "/^$user /d" /usr/local/etc/xray/limit.txt
            touch /tmp/xray_restart.flag
            echo "👤 XRAY WS: $user" >> /tmp/deleted_acc.txt
        fi
    done
fi

# ==========================================
# 3. CEK L2TP IPsec EXPIRED
# ==========================================
if [ -f "/usr/local/etc/srpcom/l2tp_expiry.txt" ]; then
    grep -v "^$" /usr/local/etc/srpcom/l2tp_expiry.txt | while read -r user pass exp_date exp_time; do
        if [[ "$exp_date" == "Lifetime" || -z "$exp_date" ]]; then continue; fi
        exp_sec=$(date -d "$exp_date $exp_time" +%s 2>/dev/null)
        if [[ -n "$exp_sec" && $now_sec -ge $exp_sec ]]; then
            sed -i "/^\"$user\" l2tpd/d" /etc/ppp/chap-secrets
            sed -i "/^$user /d" /usr/local/etc/srpcom/l2tp_expiry.txt
            touch /tmp/l2tp_restart.flag
            echo "👤 L2TP VPN: $user" >> /tmp/deleted_acc.txt
        fi
    done
fi

# RESTART SERVICE JIKA ADA AKUN DIHAPUS
if [ -f /tmp/xray_restart.flag ]; then 
    systemctl restart xray
    rm -f /tmp/xray_restart.flag
fi
if [ -f /tmp/l2tp_restart.flag ]; then 
    systemctl restart ipsec xl2tpd
    rm -f /tmp/l2tp_restart.flag
fi

# KIRIM NOTIFIKASI KE BOT TELEGRAM JIKA ADA PENGHAPUSAN
if [ -s /tmp/deleted_acc.txt ]; then
    deleted_list=$(cat /tmp/deleted_acc.txt)
    full_msg=$(echo -e "🗑 *AUTO DELETE EXPIRED* 🗑\n━━━━━━━━━━━━━━━━━━━━\nAkun berikut telah dihapus otomatis karena masa aktif (Expired) telah habis:\n\n${deleted_list}\n━━━━━━━━━━━━━━━━━━━━\n_Pesan otomatis dari server_")
    send_telegram "$full_msg"
fi
rm -f /tmp/deleted_acc.txt
