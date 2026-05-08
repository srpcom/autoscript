#!/bin/bash
# ==========================================
# xray.sh
# MODULE: XRAY LOGIC
# ==========================================

source /usr/local/etc/srpcom/env.conf

# File Database Xray
XRAY_CONF="/usr/local/etc/xray/config.json"
XRAY_EXP="/usr/local/etc/xray/expiry.txt"

# Fungsi pembantu untuk membungkus link vmess ke JSON
get_vmess_link() {
    local u=$1; local i=$2; local tls=$3; local port=$4
    local sni=""; local tls_str=""
    if [ "$tls" == "tls" ]; then sni="${DOMAIN}"; tls_str="tls"; fi
    local json="{\"v\":\"2\",\"ps\":\"${u}\",\"add\":\"${DOMAIN}\",\"port\":\"${port}\",\"id\":\"${i}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"${tls_str}\",\"sni\":\"${sni}\"}"
    echo "vmess://$(echo -n "$json" | jq -c . | base64 -w 0)"
}

add_vmess_ws() {
    clear; echo "======================================"
    echo "       CREATE VMESS WS ACCOUNT        "
    echo "======================================"
    read -p "Username : " user
    if grep -qw "^$user " $XRAY_EXP 2>/dev/null; then echo -e "\n=> Error: Username sudah ada!"; sleep 2; return; fi
    read -p "Expired (Hari) : " masaaktif
    
    uuid=$(uuidgen)
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    
    echo "$user $exp_date $exp_time" >> $XRAY_EXP
    jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' $XRAY_CONF > /tmp/config.json && mv /tmp/config.json $XRAY_CONF
    systemctl restart xray
    
    link_tls=$(get_vmess_link "$user" "$uuid" "tls" "443")
    link_none=$(get_vmess_link "$user" "$uuid" "" "80")
    
    msg_cli=$(echo -e "Remarks : ${user}\nID : ${uuid}\nLINK TLS : ${link_tls}\n\nLINK NONE : ${link_none}\nExp : ${exp_date} ${exp_time} WIB")
    msg_tg=$(echo -e "Remarks : \`${user}\`\nID : \`${uuid}\`\nLINK TLS : \`${link_tls}\`\n\nLINK NONE : \`${link_none}\`\nExp : ${exp_date} ${exp_time} WIB")
    
    clear; echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\n$msg_cli"; send_telegram "$msg_tg"; pause
}

add_vless_ws() {
    clear; echo "======================================"
    echo "       CREATE VLESS WS ACCOUNT        "
    echo "======================================"
    read -p "Username : " user
    if grep -qw "^$user " $XRAY_EXP 2>/dev/null; then echo -e "\n=> Error: Username sudah ada!"; sleep 2; return; fi
    read -p "Expired (Hari) : " masaaktif
    
    uuid=$(uuidgen)
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    
    echo "$user $exp_date $exp_time" >> $XRAY_EXP
    jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'$uuid'", "email": "'$user'"}]' $XRAY_CONF > /tmp/config.json && mv /tmp/config.json $XRAY_CONF
    systemctl restart xray
    
    link_tls="vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    link_none="vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
    
    msg_cli=$(echo -e "Remarks : ${user}\nID : ${uuid}\nLINK TLS : ${link_tls}\n\nLINK NONE : ${link_none}\nExp : ${exp_date} ${exp_time} WIB")
    msg_tg=$(echo -e "Remarks : \`${user}\`\nID : \`${uuid}\`\nLINK TLS : \`${link_tls}\`\n\nLINK NONE : \`${link_none}\`\nExp : ${exp_date} ${exp_time} WIB")
    
    clear; echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\n$msg_cli"; send_telegram "$msg_tg"; pause
}

add_trojan_ws() {
    clear; echo "======================================"
    echo "       CREATE TROJAN WS ACCOUNT       "
    echo "======================================"
    read -p "Username : " user
    if grep -qw "^$user " $XRAY_EXP 2>/dev/null; then echo -e "\n=> Error: Username sudah ada!"; sleep 2; return; fi
    read -p "Expired (Hari) : " masaaktif
    
    uuid=$(uuidgen)
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    
    echo "$user $exp_date $exp_time" >> $XRAY_EXP
    jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'$uuid'", "email": "'$user'"}]' $XRAY_CONF > /tmp/config.json && mv /tmp/config.json $XRAY_CONF
    systemctl restart xray
    
    link_tls="trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    
    msg_cli=$(echo -e "Remarks : ${user}\nPassword : ${uuid}\nLINK TLS : ${link_tls}\nExp : ${exp_date} ${exp_time} WIB")
    msg_tg=$(echo -e "Remarks : \`${user}\`\nPassword : \`${uuid}\`\nLINK TLS : \`${link_tls}\`\nExp : ${exp_date} ${exp_time} WIB")
    
    clear; echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS ❖\n━━━━━━━━━━━━━━━━━━━━\n$msg_cli"; send_telegram "$msg_tg"; pause
}

del_xray() {
    clear; echo "======================================"
    echo "         DELETE XRAY ACCOUNT          "
    echo "======================================"
    if [ ! -s "$XRAY_EXP" ]; then echo "Tidak ada akun Xray."; pause; return; fi

    mapfile -t users < <(awk '{print $1}' $XRAY_EXP)
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    echo "0. Back"
    echo "======================================"
    read -p "Pilih nomor akun untuk dihapus [1-${#users[@]}]: " choice
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        jq '(.inbounds[].settings.clients) |= map(select(.email != "'$user'"))' $XRAY_CONF > /tmp/config.json && mv /tmp/config.json $XRAY_CONF
        sed -i "/^$user /d" $XRAY_EXP
        sed -i "/^$user /d" /usr/local/etc/xray/limit.txt 2>/dev/null
        systemctl restart xray
        echo -e "\n=> Akun Xray '$user' berhasil dihapus!"; sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; del_xray
    fi
}

renew_xray() {
    clear; echo "======================================"
    echo "         RENEW XRAY ACCOUNT           "
    echo "======================================"
    if [ ! -s "$XRAY_EXP" ]; then echo "Tidak ada akun Xray."; pause; return; fi

    mapfile -t users < <(awk '{print $1}' $XRAY_EXP)
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    echo "0. Back"
    echo "======================================"
    read -p "Pilih nomor akun [1-${#users[@]}]: " choice
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        read -p "Tambah Masa Aktif (Hari): " masaaktif
        
        current_data=$(grep "^$user " $XRAY_EXP)
        current_date=$(echo "$current_data" | awk '{print $2}')
        current_time=$(echo "$current_data" | awk '{print $3}')
        
        if [ -z "$current_date" ]; then current_date=$(date +"%Y-%m-%d"); fi
        if [ -z "$current_time" ]; then current_time=$(date +"%H:%M:%S"); fi
        
        new_exp_date=$(date -d "$current_date $current_time + $masaaktif days" +"%Y-%m-%d")
        new_exp_time=$(date -d "$current_date $current_time + $masaaktif days" +"%H:%M:%S")
        
        sed -i "/^$user /d" $XRAY_EXP
        echo "$user $new_exp_date $new_exp_time" >> $XRAY_EXP
        
        echo -e "\n=> Akun '$user' diperpanjang $masaaktif Hari!"
        echo "=> Expired Baru: $new_exp_date $new_exp_time WIB"; sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; renew_xray
    fi
}

list_xray() {
    clear; echo "======================================"
    echo "          LIST XRAY ACCOUNTS          "
    echo "======================================"
    if [ ! -s "$XRAY_EXP" ]; then echo "Tidak ada akun."; else awk '{print "- "$1" (Exp: "$2" "$3" WIB)"}' $XRAY_EXP; fi
    echo "======================================"; pause
}

menu_xray() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║            MENU XRAY               ║"
        echo "╚════════════════════════════════════╝"
        echo "1. Create VMESS WS Account"
        echo "2. Create VLESS WS Account"
        echo "3. Create TROJAN WS Account"
        echo "4. Delete Xray Account"
        echo "5. Renew Xray Account"
        echo "6. List Xray Account"
        echo "0. Back to Main Menu"
        echo "======================================"
        read -p "Please select an option [0-6]: " opt
        case $opt in
            1) add_vmess_ws ;;
            2) add_vless_ws ;;
            3) add_trojan_ws ;;
            4) del_xray ;;
            5) renew_xray ;;
            6) list_xray ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
