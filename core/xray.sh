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
    read -p "Expired (Days)       : " masaaktif
    read -p "Limit IP (0 = Unli)  : " limit_ip
    read -p "Limit Kuota GB (0=Unli): " limit_quota
    
    if [ -z "$limit_ip" ]; then limit_ip=0; fi
    if [ -z "$limit_quota" ]; then limit_quota=0; fi

    uuid=$(uuidgen)
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt
    echo "$user $limit_ip $limit_quota" >> /usr/local/etc/xray/limit.txt

    jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    
    tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
    link_tls="vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
    link_none_tls="vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
    
    msg_cli=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : ${uuid}\nNetwork : Websocket\nWebsocket Path : /vmessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\nLimit Kuota : ${limit_quota} GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    msg_tg=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : \`${uuid}\`\nNetwork : Websocket\nWebsocket Path : /vmessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\nLimit Kuota : ${limit_quota} GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

add_vless_ws() {
    clear
    echo "======================================"
    echo "       CREATE VLESS WS ACCOUNT        "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    read -p "Expired (Days)       : " masaaktif
    read -p "Limit IP (0 = Unli)  : " limit_ip
    read -p "Limit Kuota GB (0=Unli): " limit_quota
    
    if [ -z "$limit_ip" ]; then limit_ip=0; fi
    if [ -z "$limit_quota" ]; then limit_quota=0; fi

    uuid=$(uuidgen)
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt
    echo "$user $limit_ip $limit_quota" >> /usr/local/etc/xray/limit.txt

    jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    
    link_tls="vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    link_none_tls="vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
    
    msg_cli=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : ${uuid}\nNetwork : Websocket\nWebsocket Path : /vlessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\nLimit Kuota : ${limit_quota} GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    msg_tg=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : \`${uuid}\`\nNetwork : Websocket\nWebsocket Path : /vlessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\nLimit Kuota : ${limit_quota} GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

add_trojan_ws() {
    clear
    echo "======================================"
    echo "       CREATE TROJAN WS ACCOUNT       "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    read -p "Expired (Days)       : " masaaktif
    read -p "Limit IP (0 = Unli)  : " limit_ip
    read -p "Limit Kuota GB (0=Unli): " limit_quota
    
    if [ -z "$limit_ip" ]; then limit_ip=0; fi
    if [ -z "$limit_quota" ]; then limit_quota=0; fi

    uuid=$(uuidgen)
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt
    echo "$user $limit_ip $limit_quota" >> /usr/local/etc/xray/limit.txt

    jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    mv /tmp/config.json /usr/local/etc/xray/config.json
    systemctl restart xray
    
    link_tls="trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    
    msg_cli=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPassword : ${uuid}\nNetwork : Websocket\nWebsocket Path : /trojanws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\nLimit Kuota : ${limit_quota} GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    msg_tg=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPassword : \`${uuid}\`\nNetwork : Websocket\nWebsocket Path : /trojanws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\nLimit Kuota : ${limit_quota} GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
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
    limit_ip=1
    limit_quota=1
    
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
    echo "$user $limit_ip $limit_quota" >> /usr/local/etc/xray/limit.txt
    systemctl restart xray
    
    if [[ "$prot" == "vmess" ]]; then
        tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
        none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
        link_tls="vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
        link_none_tls="vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
        port_none="80"
        path="/vmessws"
    elif [[ "$prot" == "vless" ]]; then
        link_tls="vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
        link_none_tls="vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
        port_none="80"
        path="/vlessws"
    elif [[ "$prot" == "trojan" ]]; then
        link_tls="trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
        link_none_tls="-"
        port_none="-"
        path="/trojanws"
    fi

    msg_str_cli="━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/${prot^^} WS TRIAL ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : ${port_none}\nID/PW : ${uuid}\nNetwork : Websocket\nWebsocket Path : ${path}\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : 1 IP\nLimit Kuota : 1 GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━"
    
    msg_str_tg="━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/${prot^^} WS TRIAL ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : ${port_none}\nID/PW : \`${uuid}\`\nNetwork : Websocket\nWebsocket Path : ${path}\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : 1 IP\nLimit Kuota : 1 GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━"
    
    if [[ "$prot" != "trojan" ]]; then
        msg_str_cli="${msg_str_cli}\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━"
        msg_str_tg="${msg_str_tg}\nLINK WS NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━"
    fi
    msg_str_cli="${msg_str_cli}\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif})"
    msg_str_tg="${msg_str_tg}\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif})"
    
    msg_cli=$(echo -e "$msg_str_cli")
    msg_tg=$(echo -e "$msg_str_tg")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
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
        sed -i "/^$user /d" /usr/local/etc/xray/limit.txt 2>/dev/null
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
        echo "=> Expired Baru: $new_exp_date $new_exp_time WIB"
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

show_detail() {
    prot=$1
    user=$2
    from_menu=$3
    clear
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "❖ XRAY/${prot^^} WS ❖"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Remarks : ${user}"
    echo "IP Address : ${IP_ADD}"
    echo "Domain : ${DOMAIN}"
    echo "Port TLS : 443"
    
    if [[ "$prot" == "vmess" ]]; then
        uuid=$(jq -r '.inbounds[] | select(.protocol=="vmess") | .settings.clients[] | select(.email=="'$user'") | .id' /usr/local/etc/xray/config.json)
        echo "Port NONE-TLS : 80"
        echo "ID : ${uuid}"
        echo "Network : Websocket"
        echo "Websocket Path : /vmessws"
        echo "━━━━━━━━━━━━━━━━━━━━"
        tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
        none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
        echo "LINK WS TLS : vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "LINK WS NONE-TLS : vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
    elif [[ "$prot" == "vless" ]]; then
        uuid=$(jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[] | select(.email=="'$user'") | .id' /usr/local/etc/xray/config.json)
        echo "Port NONE-TLS : 80"
        echo "ID : ${uuid}"
        echo "Network : Websocket"
        echo "Websocket Path : /vlessws"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "LINK WS TLS : vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "LINK WS NONE-TLS : vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
    elif [[ "$prot" == "trojan" ]]; then
        uuid=$(jq -r '.inbounds[] | select(.protocol=="trojan") | .settings.clients[] | select(.email=="'$user'") | .password' /usr/local/etc/xray/config.json)
        echo "Password : ${uuid}"
        echo "Network : Websocket"
        echo "Websocket Path : /trojanws"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "LINK WS TLS : trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    fi
    echo "━━━━━━━━━━━━━━━━━━━━"
    
    # Mengambil Info Limit
    limit_info=$(grep "^$user " /usr/local/etc/xray/limit.txt 2>/dev/null)
    lim_ip=$(echo "$limit_info" | awk '{print $2}')
    lim_q=$(echo "$limit_info" | awk '{print $3}')
    if [ -z "$lim_ip" ] || [ "$lim_ip" == "0" ]; then lim_ip="Unlimited"; else lim_ip="${lim_ip} IP"; fi
    if [ -z "$lim_q" ] || [ "$lim_q" == "0" ]; then lim_q="Unlimited"; else lim_q="${lim_q} GB"; fi
    echo "Limit IP : $lim_ip"
    echo "Limit Kuota : $lim_q"
    echo "━━━━━━━━━━━━━━━━━━━━"

    exp_date=$(grep "^$user " /usr/local/etc/xray/expiry.txt | cut -d' ' -f2-)
    if [ -z "$exp_date" ]; then exp_date="Lifetime / No Exp"; else exp_date="$exp_date WIB"; fi
    echo "Expired On : $exp_date"
    echo ""
    pause
    if [ "$from_menu" == "change_uuid" ]; then
        menu_change_uuid
    else
        detail_list "$prot"
    fi
}

detail_list() {
    prot=$1
    clear
    echo "======================================"
    echo "       SELECT ${prot^^} ACCOUNT       "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then
        echo "Tidak ada akun di protokol ini."
        echo "======================================"
        pause
        detail_xray
        return
    fi
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    echo "0. Back to Protocol Selection"
    echo "======================================"
    read -p "Select Account [0-${#users[@]}]: " acc_opt
    
    if [[ "$acc_opt" == "0" ]]; then detail_xray; return
    elif [[ "$acc_opt" -gt 0 && "$acc_opt" -le "${#users[@]}" ]]; then
        selected_user="${users[$((acc_opt-1))]}"
        show_detail "$prot" "$selected_user"
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; detail_list "$prot"
    fi
}

detail_xray() {
    clear
    echo "======================================"
    echo "          DETAIL XRAY ACCOUNT         "
    echo "======================================"
    c_vm=$(jq '[.inbounds[] | select(.protocol=="vmess") | .settings.clients[]] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    c_vl=$(jq '[.inbounds[] | select(.protocol=="vless") | .settings.clients[]] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    c_tr=$(jq '[.inbounds[] | select(.protocol=="trojan") | .settings.clients[]] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)

    echo "1. VMESS ($c_vm)"
    echo "2. VLESS ($c_vl)"
    echo "3. TROJAN ($c_tr)"
    echo "0. Back to XRAY Menu"
    echo "======================================"
    read -p "Select Protocol [0-3]: " prot_opt
    case $prot_opt in
        1) detail_list "vmess" ;;
        2) detail_list "vless" ;;
        3) detail_list "trojan" ;;
        0) return ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; detail_xray ;;
    esac
}

change_protocol_uuid() {
    prot=$1
    clear
    echo "======================================"
    echo "     CHANGE UUID/PASS ${prot^^} WS    "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then
        echo "Tidak ada akun di protokol ini."
        echo "======================================"
        pause
        menu_change_uuid
        return
    fi
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    echo "0. Back"
    echo "======================================"
    read -p "Select Account [0-${#users[@]}]: " acc_opt
    
    if [[ "$acc_opt" == "0" ]]; then menu_change_uuid; return
    elif [[ "$acc_opt" -gt 0 && "$acc_opt" -le "${#users[@]}" ]]; then
        selected_user="${users[$((acc_opt-1))]}"
        read -p "Input New UUID/Password (Press Enter to auto-generate): " new_uuid
        if [ -z "$new_uuid" ]; then new_uuid=$(uuidgen); fi
        
        if [[ "$prot" == "vmess" || "$prot" == "vless" ]]; then
            jq '(.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[] | select(.email=="'$selected_user'") | .id) = "'$new_uuid'"' /usr/local/etc/xray/config.json > /tmp/config.json
        elif [[ "$prot" == "trojan" ]]; then
            jq '(.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[] | select(.email=="'$selected_user'") | .password) = "'$new_uuid'"' /usr/local/etc/xray/config.json > /tmp/config.json
        fi
        mv /tmp/config.json /usr/local/etc/xray/config.json
        systemctl restart xray
        echo -e "\n=> UUID/Password untuk '$selected_user' berhasil diubah!"
        sleep 2
        show_detail "$prot" "$selected_user" "change_uuid"
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; change_protocol_uuid "$prot"
    fi
}

menu_change_uuid() {
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "   CHANGE UUID OR PASSWORD XRAY   "
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " [1]  CHANGE UUID/PASS FOR VMESS WS"
    echo " [2]  CHANGE UUID/PASS FOR VLESS WS"
    echo " [3]  CHANGE UUID/PASS FOR TROJAN WS"
    echo "----------------------------------"
    echo " [0]  Back"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    read -p "  Select From Options [1-3 or 0] : " opt
    case $opt in
        1) change_protocol_uuid "vmess" ;;
        2) change_protocol_uuid "vless" ;;
        3) change_protocol_uuid "trojan" ;;
        0) return ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; menu_change_uuid ;;
    esac
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
        echo "5. Detail XRAY Account"
        echo "6. Change UUID/Password"
        echo "0. Back to Main Menu"
        echo "======================================"
        read -p "Please select an option [0-6]: " opt
        case $opt in
            1) create_xray ;; 
            2) delete_xray ;; 
            3) renew_xray ;; 
            4) list_xray ;;
            5) detail_xray ;;
            6) menu_change_uuid ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
