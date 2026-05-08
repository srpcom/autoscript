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
    
    msg_out=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : ${uuid}\nNetwork : Websocket\nWebsocket Path : /vmessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\nLimit Kuota : ${limit_quota} GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB")
    
    clear; echo "$msg_out"
    send_telegram "$msg_out"
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
    
    msg_out=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : ${uuid}\nNetwork : Websocket\nWebsocket Path : /vlessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\nLimit Kuota : ${limit_quota} GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB")
    
    clear; echo "$msg_out"
    send_telegram "$msg_out"
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
    
    msg_out=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPassword : ${uuid}\nNetwork : Websocket\nWebsocket Path : /trojanws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\nLimit Kuota : ${limit_quota} GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB")
    
    clear; echo "$msg_out"
    send_telegram "$msg_out"
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

    msg_out=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/${prot^^} WS TRIAL ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : ${port_none}\nID/PW : ${uuid}\nNetwork : Websocket\nWebsocket Path : ${path}\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : 1 IP\nLimit Kuota : 1 GB\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB")
    
    clear; echo "$msg_out"
    send_telegram "$msg_out"
    pause
}

delete_xray() {
    clear
    echo "======================================"
    echo "          DELETE XRAY ACCOUNT         "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[].settings.clients[].email' /usr/local/etc/xray/config.json | sort -u)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then echo "Tidak ada akun."; pause; return; fi
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    read -p "Pilih nomor akun untuk dihapus [1-${#users[@]}]: " choice
    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        jq '(.inbounds[].settings.clients) |= map(select(.email != "'$user'"))' /usr/local/etc/xray/config.json > /tmp/config.json
        mv /tmp/config.json /usr/local/etc/xray/config.json
        sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
        sed -i "/^$user /d" /usr/local/etc/xray/limit.txt 2>/dev/null
        systemctl restart xray; echo -e "\nAkun '$user' dihapus!"; sleep 2
    fi
}

renew_xray() {
    clear
    echo "======================================"
    echo "          RENEW XRAY ACCOUNT          "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[].settings.clients[].email' /usr/local/etc/xray/config.json | sort -u)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then echo "Tidak ada akun."; pause; return; fi
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    read -p "Pilih nomor akun: " choice
    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"; read -p "Tambah (Hari): " masaaktif
        curr_data=$(grep "^$user " /usr/local/etc/xray/expiry.txt)
        new_exp_date=$(date -d "$(echo "$curr_data" | awk '{print $2}') $(echo "$curr_data" | awk '{print $3}') + $masaaktif days" +"%Y-%m-%d")
        new_exp_time=$(date -d "$(echo "$curr_data" | awk '{print $2}') $(echo "$curr_data" | awk '{print $3}') + $masaaktif days" +"%H:%M:%S")
        sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
        echo "$user $new_exp_date $new_exp_time" >> /usr/local/etc/xray/expiry.txt
        echo -e "\nAkun '$user' diperpanjang!"; sleep 2
    fi
}

list_xray() {
    clear
    echo "======================================"
    echo "          LIST XRAY ACCOUNTS          "
    echo "======================================"
    for p in vmess vless trojan; do
        echo -e "\n\e[32m[ ${p^^} WS ]\e[0m"
        jq -r '.inbounds[] | select(.protocol=="'$p'") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null | awk '{print "- " $0}'
    done
    echo -e "\n======================================"; pause
}

show_detail() {
    prot=$1; user=$2; from_menu=$3; clear
    uuid=$(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[] | select(.email=="'$user'") | .id // .password' /usr/local/etc/xray/config.json)
    exp_date=$(grep "^$user " /usr/local/etc/xray/expiry.txt | cut -d' ' -f2-)
    limit_info=$(grep "^$user " /usr/local/etc/xray/limit.txt 2>/dev/null)
    lim_ip=$(echo "$limit_info" | awk '{print $2}'); lim_q=$(echo "$limit_info" | awk '{print $3}')
    
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "❖ XRAY/${prot^^} WS ❖"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Remarks : ${user}"
    echo "IP Address : ${IP_ADD}"
    echo "Domain : ${DOMAIN}"
    echo "Port TLS : 443"
    [ "$prot" != "trojan" ] && echo "Port NONE-TLS : 80"
    echo "ID/PW : ${uuid}"
    echo "Network : Websocket"
    echo "Websocket Path : /${prot}ws"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Limit IP : ${lim_ip:-0} IP"
    echo "Limit Kuota : ${lim_q:-0} GB"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Expired On : ${exp_date:-Lifetime} WIB"
    echo ""
    pause
    [ "$from_menu" == "change_uuid" ] && menu_change_uuid || detail_list "$prot"
}

detail_list() {
    prot=$1; clear
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then detail_xray; return; fi
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    read -p "Select Account [0-${#users[@]}]: " acc_opt
    [[ "$acc_opt" -gt 0 ]] && show_detail "$prot" "${users[$((acc_opt-1))]}" || detail_xray
}

detail_xray() {
    clear; echo "1. VMESS"; echo "2. VLESS"; echo "3. TROJAN"; echo "0. Back"
    read -p "Select Protocol [0-3]: " opt
    case $opt in 1) detail_list "vmess" ;; 2) detail_list "vless" ;; 3) detail_list "trojan" ;; *) return ;; esac
}

menu_change_uuid() {
    clear; echo "1. VMESS"; echo "2. VLESS"; echo "3. TROJAN"; echo "0. Back"
    read -p "Select Protocol: " opt
    [ "$opt" == "0" ] && return
    prot_list=("" "vmess" "vless" "trojan"); prot=${prot_list[$opt]}
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[].email' /usr/local/etc/xray/config.json 2>/dev/null)
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    read -p "Select Account: " acc_opt
    if [[ "$acc_opt" -gt 0 ]]; then
        user=${users[$((acc_opt-1))]}; read -p "New UUID (Enter=Auto): " new_id; [ -z "$new_id" ] && new_id=$(uuidgen)
        field="id"; [ "$prot" == "trojan" ] && field="password"
        jq '(.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[] | select(.email=="'$user'") | .'$field') = "'$new_id'"' /usr/local/etc/xray/config.json > /tmp/config.json
        mv /tmp/config.json /usr/local/etc/xray/config.json; systemctl restart xray; show_detail "$prot" "$user" "change_uuid"
    fi
}

menu_xray() {
    while true; do
        clear; echo "1. Create"; echo "2. Delete"; echo "3. Renew"; echo "4. List"; echo "5. Detail"; echo "6. Change UUID"; echo "0. Back"
        read -p "Option: " opt
        case $opt in 1) create_xray ;; 2) delete_xray ;; 3) renew_xray ;; 4) list_xray ;; 5) detail_xray ;; 6) menu_change_uuid ;; 0) break ;; esac
    done
}
