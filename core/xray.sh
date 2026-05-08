#!/bin/bash
# ==========================================
# xray.sh
# MODULE: XRAY LOGIC
# ==========================================

source /usr/local/etc/srpcom/env.conf

# Fungsi pembantu untuk membungkus link vmess ke JSON
get_vmess_link() {
    local u=$1; local i=$2; local tls=$3; local port=$4
    local sni=""; local tls_str=""
    if [ "$tls" == "tls" ]; then sni="${DOMAIN}"; tls_str="tls"; fi
    local json="{\"v\":\"2\",\"ps\":\"${u}\",\"add\":\"${DOMAIN}\",\"port\":\"${port}\",\"id\":\"${i}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"${tls_str}\",\"sni\":\"${sni}\"}"
    echo "vmess://$(echo -n "$json" | jq -c . | base64 -w 0)"
}

add_vmess_ws() {
    clear; echo "CREATE VMESS WS ACCOUNT"
    read -p "Username : " user; read -p "Expired : " masaaktif
    uuid=$(uuidgen); exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d"); exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt
    jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json && mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    link_tls=$(get_vmess_link "$user" "$uuid" "tls" "443"); link_none=$(get_vmess_link "$user" "$uuid" "" "80")
    
    msg_cli=$(echo -e "Remarks : ${user}\nID : ${uuid}\nLINK TLS : ${link_tls}\nLINK NONE : ${link_none}\nExp : ${exp_date}")
    msg_tg=$(echo -e "Remarks : \`${user}\`\nID : \`${uuid}\`\nLINK TLS : \`${link_tls}\`\nLINK NONE : \`${link_none}\`\nExp : ${exp_date}")
    
    clear; echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\n$msg_cli"; send_telegram "$msg_tg"; pause
}

# (Lakukan pola yang sama untuk vless dan trojan di file asli Anda)
# Pastikan setiap add_vless, add_trojan, dan add_trial memiliki msg_cli (polos) dan msg_tg (backtick)
