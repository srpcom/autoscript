#!/bin/bash
# ==========================================
# xray.sh
# MODULE: XRAY LOGIC
# Berisi logika pembuatan, penghapusan, dan manajemen akun Xray
# ==========================================

source /usr/local/etc/srpcom/env.conf

add_vmess_ws() {
    clear
    echo "======================================"
    echo "       CREATE VMESS WS ACCOUNT        "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    
    tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
    link_tls="vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
    link_none_tls="vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
    
    msg="━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : ${uuid}\nNetwork : Websocket\nWebsocket Path : /vmessws\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} (${masaaktif} days)"
    
    clear; echo -e "$msg"
    send_telegram "$msg"
    pause
}

add_vless_ws() {
    clear
    echo "======================================"
    echo "       CREATE VLESS WS ACCOUNT        "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    
    link_tls="vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    link_none_tls="vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
    
    msg="━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : ${uuid}\nNetwork : Websocket\nWebsocket Path : /vlessws\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} (${masaaktif} days)"
    
    clear; echo -e "$msg"
    send_telegram "$msg"
    pause
}

add_trojan_ws() {
    clear
    echo "======================================"
    echo "       CREATE TROJAN WS ACCOUNT       "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    
    link_tls="trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    
    msg="━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPassword : ${uuid}\nNetwork : Websocket\nWebsocket Path : /trojanws\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} (${masaaktif} days)"
    
    clear; echo -e "$msg"
    send_telegram "$msg"
    pause
}

add_trial() {
    clear
    echo "======================================"
    echo "       CREATE TRIAL ACCOUNT (60M)     "
    echo "======================================"
    echo "1. VMESS WS"
    echo "2. VLESS WS"
    echo "3. TROJAN WS"
    echo "0. Back"
    read -p "Select Protocol [1-3 or 0]: " prot_opt
    
    if [[ "$prot_opt" == "0" ]]; then return; fi
    
    user="trialsrp-$(date +%m%d%H%M)"
    masaaktif="60 Minutes"
    exp_date=$(date -d "+60 minutes" +"%Y-%m-%d")
    exp_time=$(date -d "+60 minutes" +"%H:%M:%S")
    uuid=$(uuidgen)
    
    if [[ "$prot_opt" == "1" ]]; then
        prot="vmess"
        jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    elif [[ "$prot_opt" == "2" ]]; then
        prot="vless"
        jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    elif [[ "$prot_opt" == "3" ]]; then
        prot="trojan"
        jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; add_trial; return
    fi
    
    mv /tmp/config.json /usr/local/etc/xray/config.json
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt
    systemctl restart xray
    
    echo -e "\n\e[32m[SUCCESS] Trial Account ${prot^^} Created!\e[0m"
    echo "ID: $uuid"
    echo "Expired: $exp_date $exp_time"
    pause
}

create_xray() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║             CREATE XRAY            ║"
    echo "╚════════════════════════════════════╝"
    echo "1.  VMESS WS"
    echo "2.  VLESS WS"
    echo "3.  TROJAN WS"
    echo "4.  TRIAL ACCOUNT (60 Minutes)"
    echo "0.  Back"
    echo "======================================"
    read -p "Please select an option [0-4]: " opt
    case $opt in
        1) add_vmess_ws ;;
        2) add_vless_ws ;;
        3) add_trojan_ws ;;
        4) add_trial ;;
        0) return ;;
        *) echo "Pilihan tidak valid!"; sleep 1; create_xray ;;
    esac
}

delete_xray() {
    clear
    echo "======================================"
    echo "          DELETE XRAY ACCOUNT         "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[].settings.clients[].email' /usr/local/etc/xray/config.json | sort -u)
    
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then
        echo "Tidak ada akun untuk dihapus."
        pause; return
    fi

    for i in "${!users[@]}"; do
        echo "$((i+1)). ${users[$i]}"
    done
    echo "0. Back"
    echo "======================================"
    read -p "Pilih nomor akun untuk dihapus [1-${#users[@]}]: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        jq '(.inbounds[].settings.clients) |= map(select(.email != "'$user'"))' /usr/local/etc/xray/config.json > /tmp/config.json
        mv /tmp/config.json /usr/local/etc/xray/config.json
        sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
        systemctl restart xray
        echo -e "\n\e[32m=> Akun '$user' berhasil dihapus!\e[0m"
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; delete_xray
    fi
}

renew_xray() {
    clear
    echo "======================================"
    echo "          RENEW XRAY ACCOUNT          "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[].settings.clients[].email' /usr/local/etc/xray/config.json | sort -u)
    
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then
        echo "Tidak ada akun untuk diperpanjang."
        pause; return
    fi

    for i in "${!users[@]}"; do
        echo "$((i+1)). ${users[$i]}"
    done
    echo "0. Back"
    echo "======================================"
    read -p "Pilih nomor akun [1-${#users[@]}]: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        read -p "Tambah Masa Aktif (Hari): " masaaktif
        
        current_data=$(grep "^$user " /usr/local/etc/xray/expiry.txt)
        current_date=$(echo "$current_data" | awk '{print $2}')
        current_time=$(echo "$current_data" | awk '{print $3}')
        
        if [ -z "$current_date" ]; then current_date=$(date +"%Y-%m-%d"); fi
        if [ -z "$current_time" ]; then current_time=$(date +"%H:%M:%S"); fi
        
        new_exp_date=$(date -d "$current_date $current_time + $masaaktif days" +"%Y-%m-%d")
        new_exp_time=$(date -d "$current_date $current_time + $masaaktif days" +"%H:%M:%S")
        
        sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
        echo "$user $new_exp_date $new_exp_time" >> /usr/local/etc/xray/expiry.txt
        
        echo -e "\n\e[32m=> Akun '$user' diperpanjang $masaaktif Hari!\e[0m"
        echo "=> Expired Baru: $new_exp_date $new_exp_time"
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; renew_xray
    fi
}

list_xray() {
    clear
    echo "======================================"
    echo "          LIST XRAY ACCOUNTS          "
    echo "======================================"
    echo -e "\n\e[32m[ VMESS WS ]\e[0m"
    echo "--------------------------------------"
    vmess_users=$(jq -r '.inbounds[] | select(.protocol=="vmess") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ -z "$vmess_users" ] || [ "$vmess_users" == "null" ]; then echo "Tidak ada akun."; else echo "$vmess_users" | awk '{print "- " $0}'; fi
    
    echo -e "\n\e[32m[ VLESS WS ]\e[0m"
    echo "--------------------------------------"
    vless_users=$(jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ -z "$vless_users" ] || [ "$vless_users" == "null" ]; then echo "Tidak ada akun."; else echo "$vless_users" | awk '{print "- " $0}'; fi
    
    echo -e "\n\e[32m[ TROJAN WS ]\e[0m"
    echo "--------------------------------------"
    trojan_users=$(jq -r '.inbounds[] | select(.protocol=="trojan") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ -z "$trojan_users" ] || [ "$trojan_users" == "null" ]; then echo "Tidak ada akun."; else echo "$trojan_users" | awk '{print "- " $0}'; fi
    
    echo -e "\n======================================"
    pause
}

menu_xray() {
    XRAY_VER=$(/usr/local/bin/xray version 2>/dev/null | head -n 1 | awk '{print $1" "$2}')
    if [[ -z "$XRAY_VER" ]]; then XRAY_VER="Xray 24.11.11"; fi
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║              MENU XRAY             ║"
        echo "╚════════════════════════════════════╝"
        echo "Xray Version: ${XRAY_VER}"
        echo "======================================"
        echo "1. Create XRAY Account"
        echo "2. Delete XRAY Account"
        echo "3. Renew XRAY Account"
        echo "4. List XRAY Account"
        echo "0. Back to Main Menu"
        echo "======================================"
        read -p "Please select an option [0-4]: " opt
        case $opt in
            1) create_xray ;; 
            2) delete_xray ;; 
            3) renew_xray ;; 
            4) list_xray ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
