#!/bin/bash
# ==========================================
# xray.sh
# MODULE: XRAY LOGIC
# Berisi logika pembuatan, penghapusan, dan manajemen akun Xray
# ==========================================

source /usr/local/etc/srpcom/env.conf

# Fungsi Pintar untuk membuat Tabel Daftar User Xray (Mobile Optimized)
print_user_table() {
    local back_type=$1
    printf " %-3s | %-16s | %-10s\n" "No" "Username" "Sisa Hari"
    echo "--------------------------------------"
    for i in "${!users[@]}"; do
        local user="${users[$i]}"
        local exp_data=$(grep "^$user " /usr/local/etc/xray/expiry.txt 2>/dev/null)
        local exp_date=""
        local sisa_hari=""
        
        if [ -z "$exp_data" ]; then
            sisa_hari="Lifetime"
        else
            exp_date=$(echo "$exp_data" | awk '{print $2}')
            local exp_time=$(echo "$exp_data" | awk '{print $3}')
            local exp_sec=$(date -d "$exp_date $exp_time" +%s 2>/dev/null)
            local now_sec=$(date +%s)
            
            if [ -n "$exp_sec" ]; then
                local diff=$((exp_sec - now_sec))
                if [ "$diff" -lt 0 ]; then
                    sisa_hari="Expired"
                else
                    sisa_hari=$((diff / 86400))
                    if [ "$sisa_hari" -eq 0 ]; then
                        sisa_hari="<1 Hari"
                    else
                        sisa_hari="${sisa_hari} Hari"
                    fi
                fi
            else
                sisa_hari="Unknown"
            fi
        fi
        
        # Potong panjang string user max 16 char agar tabel HP tidak pecah
        local display_user="${user:0:16}"
        printf " %-3s | %-16s | %-10s\n" "$((i+1))." "$display_user" "$sisa_hari"
    done
    
    if [ "$back_type" == "hide_back" ]; then
        : # Tidak print tombol back
    elif [ "$back_type" == "back_to_protocol" ]; then
        echo "--------------------------------------"
        echo " 0.  | Kembali ke Menu Protocol"
    else
        echo "--------------------------------------"
        echo " 0.  | Kembali"
    fi
}

add_vmess_ws() {
    clear
    echo "======================================"
    echo "       CREATE VMESS WS ACCOUNT        "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    
    # Cek apakah user sudah ada di config.json, jika ada tambahkan angka berurutan
    original_user="$user"
    counter=2
    while grep -q "\"email\": \"$user\"" /usr/local/etc/xray/config.json; do
        user="${original_user}${counter}"
        ((counter++))
    done
    if [[ "$original_user" != "$user" ]]; then
        echo -e "\n\e[33m[INFO]\e[0m Username '$original_user' sudah digunakan. Akun akan dibuat dengan nama: $user"
    fi
    
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    if [ -s /tmp/config.json ]; then mv /tmp/config.json /usr/local/etc/xray/config.json; fi
    systemctl restart xray
    [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
    
    tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
    link_tls="vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
    link_none_tls="vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
    
    msg_cli=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : ${uuid}\nNetwork : Websocket\nWebsocket Path : /vmessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    msg_tg=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : \`${uuid}\`\nNetwork : Websocket\nWebsocket Path : /vmessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    
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
    
    # Cek apakah user sudah ada di config.json, jika ada tambahkan angka berurutan
    original_user="$user"
    counter=2
    while grep -q "\"email\": \"$user\"" /usr/local/etc/xray/config.json; do
        user="${original_user}${counter}"
        ((counter++))
    done
    if [[ "$original_user" != "$user" ]]; then
        echo -e "\n\e[33m[INFO]\e[0m Username '$original_user' sudah digunakan. Akun akan dibuat dengan nama: $user"
    fi
    
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    if [ -s /tmp/config.json ]; then mv /tmp/config.json /usr/local/etc/xray/config.json; fi
    systemctl restart xray
    [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
    
    link_tls="vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    link_none_tls="vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
    
    msg_cli=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : ${uuid}\nNetwork : Websocket\nWebsocket Path : /vlessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    msg_tg=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : \`${uuid}\`\nNetwork : Websocket\nWebsocket Path : /vlessws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    
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
    
    # Cek apakah user sudah ada di config.json, jika ada tambahkan angka berurutan
    original_user="$user"
    counter=2
    while grep -q "\"email\": \"$user\"" /usr/local/etc/xray/config.json; do
        user="${original_user}${counter}"
        ((counter++))
    done
    if [[ "$original_user" != "$user" ]]; then
        echo -e "\n\e[33m[INFO]\e[0m Username '$original_user' sudah digunakan. Akun akan dibuat dengan nama: $user"
    fi
    
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    if [ -s /tmp/config.json ]; then mv /tmp/config.json /usr/local/etc/xray/config.json; fi
    systemctl restart xray
    [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
    
    link_tls="trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
    link_none_tls="trojan://${uuid}@${DOMAIN}:80?path=/trojanws&security=none&host=${DOMAIN}&type=ws#${user}"
    
    msg_cli=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nPassword : ${uuid}\nNetwork : Websocket\nWebsocket Path : /trojanws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    msg_tg=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN WS ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nPassword : \`${uuid}\`\nNetwork : Websocket\nWebsocket Path : /trojanws\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

add_vmess_grpc() {
    clear
    echo "======================================"
    echo "      CREATE VMESS GRPC ACCOUNT       "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    
    # Cek apakah user sudah ada di config.json, jika ada tambahkan angka berurutan
    original_user="$user"
    counter=2
    while grep -q "\"email\": \"$user\"" /usr/local/etc/xray/config.json; do
        user="${original_user}${counter}"
        ((counter++))
    done
    if [[ "$original_user" != "$user" ]]; then
        echo -e "\n\e[33m[INFO]\e[0m Username '$original_user' sudah digunakan. Akun akan dibuat dengan nama: $user"
    fi
    
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    if [ -s /tmp/config.json ]; then mv /tmp/config.json /usr/local/etc/xray/config.json; fi
    systemctl restart xray
    [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
    
    tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"vmessgrpc\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
    none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"vmessgrpc\",\"tls\":\"\",\"sni\":\"\"}"
    link_tls="vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
    link_none_tls="vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
    
    msg_cli=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS GRPC ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : ${uuid}\nNetwork : gRPC\nService Name : vmessgrpc\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    msg_tg=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VMESS GRPC ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : \`${uuid}\`\nNetwork : gRPC\nService Name : vmessgrpc\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

add_vless_grpc() {
    clear
    echo "======================================"
    echo "      CREATE VLESS GRPC ACCOUNT       "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    
    # Cek apakah user sudah ada di config.json, jika ada tambahkan angka berurutan
    original_user="$user"
    counter=2
    while grep -q "\"email\": \"$user\"" /usr/local/etc/xray/config.json; do
        user="${original_user}${counter}"
        ((counter++))
    done
    if [[ "$original_user" != "$user" ]]; then
        echo -e "\n\e[33m[INFO]\e[0m Username '$original_user' sudah digunakan. Akun akan dibuat dengan nama: $user"
    fi
    
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    if [ -s /tmp/config.json ]; then mv /tmp/config.json /usr/local/etc/xray/config.json; fi
    systemctl restart xray
    [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
    
    link_tls="vless://${uuid}@${DOMAIN}:443?mode=gun&security=tls&encryption=none&host=${DOMAIN}&type=grpc&serviceName=vlessgrpc&sni=${DOMAIN}#${user}"
    link_none_tls="vless://${uuid}@${DOMAIN}:80?mode=gun&security=none&encryption=none&host=${DOMAIN}&type=grpc&serviceName=vlessgrpc#${user}"
    
    msg_cli=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS GRPC ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : ${uuid}\nNetwork : gRPC\nService Name : vlessgrpc\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    msg_tg=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/VLESS GRPC ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID : \`${uuid}\`\nNetwork : gRPC\nService Name : vlessgrpc\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

add_trojan_grpc() {
    clear
    echo "======================================"
    echo "      CREATE TROJAN GRPC ACCOUNT      "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    
    # Cek apakah user sudah ada di config.json, jika ada tambahkan angka berurutan
    original_user="$user"
    counter=2
    while grep -q "\"email\": \"$user\"" /usr/local/etc/xray/config.json; do
        user="${original_user}${counter}"
        ((counter++))
    done
    if [[ "$original_user" != "$user" ]]; then
        echo -e "\n\e[33m[INFO]\e[0m Username '$original_user' sudah digunakan. Akun akan dibuat dengan nama: $user"
    fi
    
    read -p "Expired (Days) : " masaaktif
    uuid=$(uuidgen)
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt

    jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    if [ -s /tmp/config.json ]; then mv /tmp/config.json /usr/local/etc/xray/config.json; fi
    systemctl restart xray
    [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
    
    link_tls="trojan://${uuid}@${DOMAIN}:443?mode=gun&security=tls&host=${DOMAIN}&type=grpc&serviceName=trojangrpc&sni=${DOMAIN}#${user}"
    link_none_tls="trojan://${uuid}@${DOMAIN}:80?mode=gun&security=none&type=grpc&serviceName=trojangrpc#${user}"
    
    msg_cli=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN GRPC ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nPassword : ${uuid}\nNetwork : gRPC\nService Name : trojangrpc\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    msg_tg=$(echo -e "Pembuatan akun baru berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/TROJAN GRPC ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nPassword : \`${uuid}\`\nNetwork : gRPC\nService Name : trojangrpc\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : Unlimited\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

add_trial() {
    clear
    echo "======================================"
    echo "       CREATE TRIAL ACCOUNT (60M)     "
    echo "======================================"
    echo " 1. VMESS WS"
    echo " 2. VLESS WS"
    echo " 3. TROJAN WS"
    echo " 4. VMESS GRPC"
    echo " 5. VLESS GRPC"
    echo " 6. TROJAN GRPC"
    echo " 0. Kembali"
    echo "======================================"
    read -p "Select Protocol [1-6 or 0]: " prot_opt
    
    if [[ "$prot_opt" == "0" ]]; then return; fi
    
    # Format Jam-Menit-Detik + 1 Karakter Random
    rand_char=$(tr -dc 'a-z' < /dev/urandom | head -c 1)
    user="trialsrp-$(date +%H%M%S)${rand_char}"
    
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
    elif [[ "$prot_opt" == "4" ]]; then
        prot="vmess_grpc"
        jq '(.inbounds[] | select(.protocol=="vmess") | .settings.clients) += [{"id": "'$uuid'", "alterId": 0, "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    elif [[ "$prot_opt" == "5" ]]; then
        prot="vless_grpc"
        jq '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    elif [[ "$prot_opt" == "6" ]]; then
        prot="trojan_grpc"
        jq '(.inbounds[] | select(.protocol=="trojan") | .settings.clients) += [{"password": "'$uuid'", "email": "'$user'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; add_trial; return
    fi
    
    if [ -s /tmp/config.json ]; then mv /tmp/config.json /usr/local/etc/xray/config.json; fi
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt
    systemctl restart xray
    [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
    
    if [[ "$prot" == "vmess" ]]; then
        tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
        none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
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
        link_none_tls="trojan://${uuid}@${DOMAIN}:80?path=/trojanws&security=none&host=${DOMAIN}&type=ws#${user}"
        port_none="80"
        path="/trojanws"
    elif [[ "$prot" == "vmess_grpc" ]]; then
        tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"vmessgrpc\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
        none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"vmessgrpc\",\"tls\":\"\",\"sni\":\"\"}"
        link_tls="vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
        link_none_tls="vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
        port_none="80"
        path="vmessgrpc"
    elif [[ "$prot" == "vless_grpc" ]]; then
        link_tls="vless://${uuid}@${DOMAIN}:443?mode=gun&security=tls&encryption=none&host=${DOMAIN}&type=grpc&serviceName=vlessgrpc&sni=${DOMAIN}#${user}"
        link_none_tls="vless://${uuid}@${DOMAIN}:80?mode=gun&security=none&encryption=none&host=${DOMAIN}&type=grpc&serviceName=vlessgrpc#${user}"
        port_none="80"
        path="vlessgrpc"
    elif [[ "$prot" == "trojan_grpc" ]]; then
        link_tls="trojan://${uuid}@${DOMAIN}:443?mode=gun&security=tls&host=${DOMAIN}&type=grpc&serviceName=trojangrpc&sni=${DOMAIN}#${user}"
        link_none_tls="trojan://${uuid}@${DOMAIN}:80?mode=gun&security=none&type=grpc&serviceName=trojangrpc#${user}"
        port_none="80"
        path="trojangrpc"
    fi

    if [[ "$prot" == *"grpc"* ]]; then
        local display_prot=$(echo "$prot" | cut -d'_' -f1 | tr 'a-z' 'A-Z')
        msg_str_cli="Pembuatan akun trial berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/${display_prot} GRPC TRIAL ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : ${port_none}\nID/PW : ${uuid}\nNetwork : gRPC\nService Name : ${path}\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : 1 IP\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB (${masaaktif})"
        msg_str_tg="Pembuatan akun trial berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/${display_prot} GRPC TRIAL ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : ${port_none}\nID/PW : \`${uuid}\`\nNetwork : gRPC\nService Name : \`${path}\`\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : 1 IP\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK GRPC NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB (${masaaktif})"
    else
        msg_str_cli="Pembuatan akun trial berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/${prot^^} WS TRIAL ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : ${port_none}\nID/PW : ${uuid}\nNetwork : Websocket\nWebsocket Path : ${path}\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : 1 IP\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : ${link_tls}\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : ${link_none_tls}\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB (${masaaktif})"
        msg_str_tg="Pembuatan akun trial berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/${prot^^} WS TRIAL ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : ${port_none}\nID/PW : \`${uuid}\`\nNetwork : Websocket\nWebsocket Path : ${path}\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : 1 IP\nLimit Kuota : Unlimited\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date} ${exp_time} WIB (${masaaktif})"
    fi
    
    msg_cli=$(echo -e "$msg_str_cli")
    msg_tg=$(echo -e "$msg_str_tg")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

create_xray() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║            CREATE XRAY             ║"
    echo "╚════════════════════════════════════╝"
    echo " 1. VMESS WS"
    echo " 2. VLESS WS"
    echo " 3. TROJAN WS"
    echo " 4. VMESS gRPC"
    echo " 5. VLESS gRPC"
    echo " 6. TROJAN gRPC"
    echo " 7. TRIAL ACCOUNT (60 Minutes)"
    echo "--------------------------------------"
    echo " 0. Kembali"
    echo "======================================"
    read -p " Pilih opsi [0-7]: " opt
    case $opt in
        1) add_vmess_ws ;;
        2) add_vless_ws ;;
        3) add_trojan_ws ;;
        4) add_vmess_grpc ;;
        5) add_vless_grpc ;;
        6) add_trojan_grpc ;;
        7) add_trial ;;
        0) return ;;
        *) echo "Pilihan tidak valid!"; sleep 1; create_xray ;;
    esac
}

delete_xray() {
    clear
    echo "======================================"
    echo "         DELETE XRAY ACCOUNT          "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="vmess" or .protocol=="vless" or .protocol=="trojan") | .settings.clients[]?.email' /usr/local/etc/xray/config.json 2>/dev/null | sort -u)
    
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then
        echo "Tidak ada akun untuk dihapus."
        pause; return
    fi

    print_user_table "normal_back"
    echo "======================================"
    read -p "Pilih nomor akun untuk dihapus: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        
        jq '(.inbounds[] | select(.protocol=="vmess" or .protocol=="vless" or .protocol=="trojan") | .settings.clients) |= map(select(.email != "'$user'"))' /usr/local/etc/xray/config.json > /tmp/config.json
        
        if [ -s /tmp/config.json ]; then
            mv /tmp/config.json /usr/local/etc/xray/config.json
            sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
            sed -i "/^$user /d" /usr/local/etc/xray/limit.txt
            systemctl restart xray
            [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
            echo -e "\n\e[32m=> Akun '$user' berhasil dihapus!\e[0m"
        else
            echo -e "\n\e[31m[ERROR]\e[0m Gagal menghapus file JSON."
            rm -f /tmp/config.json
        fi
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; delete_xray
    fi
}

renew_xray() {
    clear
    echo "======================================"
    echo "         RENEW XRAY ACCOUNT           "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="vmess" or .protocol=="vless" or .protocol=="trojan") | .settings.clients[]?.email' /usr/local/etc/xray/config.json 2>/dev/null | sort -u)
    
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then
        echo "Tidak ada akun untuk diperpanjang."
        pause; return
    fi

    print_user_table "normal_back"
    echo "======================================"
    read -p "Pilih nomor akun [1-${#users[@]}]: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        read -p "Tambah Masa Aktif (Hari): " masaaktif
        
        current_data=$(grep "^$user " /usr/local/etc/xray/expiry.txt)
        current_date=$(echo "$current_data" | awk '{print $2}')
        current_time=$(echo "$current_data" | awk '{print $3}')
        
        if [ -z "$current_date" ] || [ "$current_date" == "Lifetime" ]; then current_date=$(date +"%Y-%m-%d"); fi
        if [ -z "$current_time" ]; then current_time=$(date +"%H:%M:%S"); fi
        
        now_sec=$(date +%s)
        current_sec=$(date -d "$current_date $current_time" +%s 2>/dev/null)
        if [ -z "$current_sec" ]; then current_sec=$now_sec; fi
        
        if [ "$now_sec" -gt "$current_sec" ]; then
            current_sec=$now_sec
        fi
        
        new_sec=$((current_sec + (masaaktif * 86400)))
        new_exp_date=$(date -d "@$new_sec" +"%Y-%m-%d")
        new_exp_time=$(date -d "@$new_sec" +"%H:%M:%S")
        
        sed -i "/^$user /d" /usr/local/etc/xray/expiry.txt
        echo "$user $new_exp_date $new_exp_time" >> /usr/local/etc/xray/expiry.txt
        [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
        
        echo -e "\n\e[32m=> Akun '$user' diperpanjang $masaaktif Hari!\e[0m"
        echo "=> Expired Baru: $new_exp_date $new_exp_time WIB"
        
        # Ambil tipe protokol secara otomatis dari config.json
        user_prot=$(jq -r '.inbounds[] | select(.settings.clients[]?.email == "'$user'") | .protocol' /usr/local/etc/xray/config.json 2>/dev/null | head -1)
        user_prot_up=${user_prot^^}
        if [ -z "$user_prot_up" ]; then user_prot_up="XRAY"; fi
        
        # --- TELEGRAM NOTIF RENEW ---
        msg_tg=$(echo -e "🕑 Akun Diperpanjang\n\n💻 Server: ${DOMAIN}\nType : ${user_prot_up} WS\n🔑 Akun: \`${user}\`\n⏳ Durasi: +${masaaktif} hari\n📅 Expired Baru: ${new_exp_date} ${new_exp_time} WIB")
        send_telegram "$msg_tg"
        # ----------------------------
        
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
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="vmess") | .settings.clients[]?.email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then echo "Tidak ada akun."; else print_user_table "hide_back"; fi
    
    echo -e "\n\e[32m[ VLESS WS ]\e[0m"
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[]?.email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then echo "Tidak ada akun."; else print_user_table "hide_back"; fi
    
    echo -e "\n\e[32m[ TROJAN WS ]\e[0m"
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="trojan") | .settings.clients[]?.email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then echo "Tidak ada akun."; else print_user_table "hide_back"; fi
    
    echo -e "\n======================================"
    pause
}

show_detail() {
    prot=$1
    user=$2
    from_menu=$3
    clear
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "❖ XRAY/${prot^^} CONFIG DETAILS ❖"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Remarks : ${user}"
    echo "IP Address : ${IP_ADD}"
    echo "Domain : ${DOMAIN}"
    echo "Port TLS : 443"
    echo "Port NONE-TLS : 80"
    
    if [[ "$prot" == "vmess" ]]; then
        uuid=$(jq -r '.inbounds[] | select(.protocol=="vmess") | .settings.clients[] | select(.email=="'$user'") | .id' /usr/local/etc/xray/config.json 2>/dev/null)
        echo "ID : ${uuid}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "--- WEBSOCKET CONFIG ---"
        tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
        none_tls_json="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
        echo "LINK WS TLS : vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
        echo "LINK WS NONE-TLS : vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "--- gRPC CONFIG ---"
        tls_grpc="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"vmessgrpc\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
        none_tls_grpc="{\"v\":\"2\",\"ps\":\"${user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"grpc\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"vmessgrpc\",\"tls\":\"\",\"sni\":\"\"}"
        echo "LINK GRPC TLS : vmess://$(echo -n "$tls_grpc" | jq -c . | base64 -w 0)"
        echo "LINK GRPC NONE-TLS : vmess://$(echo -n "$none_tls_grpc" | jq -c . | base64 -w 0)"
        
    elif [[ "$prot" == "vless" ]]; then
        uuid=$(jq -r '.inbounds[] | select(.protocol=="vless") | .settings.clients[] | select(.email=="'$user'") | .id' /usr/local/etc/xray/config.json 2>/dev/null)
        echo "ID : ${uuid}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "--- WEBSOCKET CONFIG ---"
        echo "LINK WS TLS : vless://${uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
        echo "LINK WS NONE-TLS : vless://${uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${user}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "--- gRPC CONFIG ---"
        echo "LINK GRPC TLS : vless://${uuid}@${DOMAIN}:443?mode=gun&security=tls&encryption=none&host=${DOMAIN}&type=grpc&serviceName=vlessgrpc&sni=${DOMAIN}#${user}"
        echo "LINK GRPC NONE-TLS : vless://${uuid}@${DOMAIN}:80?mode=gun&security=none&encryption=none&host=${DOMAIN}&type=grpc&serviceName=vlessgrpc#${user}"
        
    elif [[ "$prot" == "trojan" ]]; then
        uuid=$(jq -r '.inbounds[] | select(.protocol=="trojan") | .settings.clients[] | select(.email=="'$user'") | .password' /usr/local/etc/xray/config.json 2>/dev/null)
        echo "Password : ${uuid}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "--- WEBSOCKET CONFIG ---"
        echo "LINK WS TLS : trojan://${uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${user}"
        echo "LINK WS NONE-TLS : trojan://${uuid}@${DOMAIN}:80?path=/trojanws&security=none&host=${DOMAIN}&type=ws#${user}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "--- gRPC CONFIG ---"
        echo "LINK GRPC TLS : trojan://${uuid}@${DOMAIN}:443?mode=gun&security=tls&host=${DOMAIN}&type=grpc&serviceName=trojangrpc&sni=${DOMAIN}#${user}"
        echo "LINK GRPC NONE-TLS : trojan://${uuid}@${DOMAIN}:80?mode=gun&security=none&type=grpc&serviceName=trojangrpc#${user}"
    fi
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
    echo "        SELECT ${prot^^} ACCOUNT       "
    echo "======================================"
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[]?.email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then
        echo "Tidak ada akun di protokol ini."
        echo "======================================"
        pause
        detail_xray
        return
    fi
    
    print_user_table "back_to_protocol"
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
    echo "         DETAIL XRAY ACCOUNT          "
    echo "======================================"
    c_vm=$(jq '[.inbounds[] | select(.protocol=="vmess") | .settings.clients[]?.email] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    c_vl=$(jq '[.inbounds[] | select(.protocol=="vless") | .settings.clients[]?.email] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    c_tr=$(jq '[.inbounds[] | select(.protocol=="trojan") | .settings.clients[]?.email] | length' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)

    echo " 1. VMESS ($c_vm)"
    echo " 2. VLESS ($c_vl)"
    echo " 3. TROJAN ($c_tr)"
    echo " 0. Back to XRAY Menu"
    echo "======================================"
    read -p " Select Protocol [0-3]: " prot_opt
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
    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[]?.email' /usr/local/etc/xray/config.json 2>/dev/null)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ] || [ "${users[0]}" == "null" ]; then
        echo "Tidak ada akun di protokol ini."
        echo "======================================"
        pause
        menu_change_uuid
        return
    fi
    
    print_user_table "back_to_protocol"
    echo "======================================"
    read -p "Select Account [0-${#users[@]}]: " acc_opt
    
    if [[ "$acc_opt" == "0" ]]; then menu_change_uuid; return
    elif [[ "$acc_opt" -gt 0 && "$acc_opt" -le "${#users[@]}" ]]; then
        selected_user="${users[$((acc_opt-1))]}"
        
        echo "$selected_user"
        
        if [[ "$prot" == "vmess" || "$prot" == "vless" ]]; then
            old_uuid=$(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[] | select(.email=="'$selected_user'") | .id' /usr/local/etc/xray/config.json 2>/dev/null)
        elif [[ "$prot" == "trojan" ]]; then
            old_uuid=$(jq -r '.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[] | select(.email=="'$selected_user'") | .password' /usr/local/etc/xray/config.json 2>/dev/null)
        fi
        
        echo "old UUID : $old_uuid"
        
        read -p "New UUID/Pass (Kosong = Auto): " new_uuid
        if [ -z "$new_uuid" ]; then new_uuid=$(uuidgen); fi
        
        if [[ "$prot" == "vmess" || "$prot" == "vless" ]]; then
            jq '(.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[] | select(.email=="'$selected_user'") | .id) = "'$new_uuid'"' /usr/local/etc/xray/config.json > /tmp/config.json
        elif [[ "$prot" == "trojan" ]]; then
            jq '(.inbounds[] | select(.protocol=="'$prot'") | .settings.clients[] | select(.email=="'$selected_user'") | .password) = "'$new_uuid'"' /usr/local/etc/xray/config.json > /tmp/config.json
        fi
        
        if [ -s /tmp/config.json ]; then
            mv /tmp/config.json /usr/local/etc/xray/config.json
            systemctl restart xray
            echo -e "\n=> UUID/Pass '$selected_user' diganti!"
            sleep 2
            
            if [[ "$prot" == "vmess" ]]; then
                tls_json="{\"v\":\"2\",\"ps\":\"${selected_user}\",\"add\":\"${DOMAIN}\",\"port\":\"443\",\"id\":\"${new_uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}"
                none_tls_json="{\"v\":\"2\",\"ps\":\"${selected_user}\",\"add\":\"${DOMAIN}\",\"port\":\"80\",\"id\":\"${new_uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"ws\",\"type\":\"none\",\"host\":\"${DOMAIN}\",\"path\":\"/vmessws\",\"tls\":\"\",\"sni\":\"\"}"
                link_tls="vmess://$(echo -n "$tls_json" | jq -c . | base64 -w 0)"
                link_none_tls="vmess://$(echo -n "$none_tls_json" | jq -c . | base64 -w 0)"
            elif [[ "$prot" == "vless" ]]; then
                link_tls="vless://${new_uuid}@${DOMAIN}:443?path=/vlessws&security=tls&encryption=none&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${selected_user}"
                link_none_tls="vless://${new_uuid}@${DOMAIN}:80?path=/vlessws&security=none&encryption=none&host=${DOMAIN}&type=ws#${selected_user}"
            elif [[ "$prot" == "trojan" ]]; then
                link_tls="trojan://${new_uuid}@${DOMAIN}:443?path=/trojanws&security=tls&host=${DOMAIN}&type=ws&sni=${DOMAIN}#${selected_user}"
                link_none_tls="trojan://${new_uuid}@${DOMAIN}:80?path=/trojanws&security=none&host=${DOMAIN}&type=ws#${selected_user}"
            fi

            exp_date=$(grep "^$selected_user " /usr/local/etc/xray/expiry.txt | cut -d' ' -f2-)
            if [ -z "$exp_date" ]; then exp_date="Lifetime / No Exp"; else exp_date="$exp_date WIB"; fi

            msg_tg=$(echo -e "Update UUID/Password berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ XRAY/${prot^^} WS (UPDATE) ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${selected_user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nPort TLS : 443\nPort NONE-TLS : 80\nID/Password : \`${new_uuid}\`\nNetwork : Websocket\nWebsocket Path : /${prot}ws\n━━━━━━━━━━━━━━━━━━━━\nLINK WS TLS : \`${link_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nLINK WS NONE-TLS : \`${link_none_tls}\`\n━━━━━━━━━━━━━━━━━━━━\nExpired On : ${exp_date}")
            send_telegram "$msg_tg"
            
            show_detail "$prot" "$selected_user" "change_uuid"
        else
            echo -e "\n\e[31m[ERROR]\e[0m Gagal memproses JSON."
            rm -f /tmp/config.json
            sleep 2
        fi
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; change_protocol_uuid "$prot"
    fi
}

menu_change_uuid() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║        CHANGE UUID OR PASS         ║"
    echo "╚════════════════════════════════════╝"
    echo " 1. CHANGE FOR VMESS WS"
    echo " 2. CHANGE FOR VLESS WS"
    echo " 3. CHANGE FOR TROJAN WS"
    echo "--------------------------------------"
    echo " 0. Kembali"
    echo "======================================"
    read -p " Pilih Opsi [1-3 or 0] : " opt
    case $opt in
        1) change_protocol_uuid "vmess" ;;
        2) change_protocol_uuid "vless" ;;
        3) change_protocol_uuid "trojan" ;;
        0) return ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; menu_change_uuid ;;
    esac
}

list_locked_xray() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║       DAFTAR AKUN XRAY TERKUNCI    ║"
    echo "╚════════════════════════════════════╝"
    LOCKED_FILE="/usr/local/etc/xray/locked.json"
    if [ ! -f "$LOCKED_FILE" ] || [ "$(jq 'length' "$LOCKED_FILE" 2>/dev/null)" -eq 0 ]; then
        echo -e " \e[32mTidak ada akun Xray yang sedang ter-lock.\e[0m"
    else
        printf " %-3s | %-12s | %-20s | %-16s\n" "No" "User" "Alasan" "Waktu Lock"
        echo "--------------------------------------------------------"
        no=1
        jq -r 'to_entries[] | "\(.value.user)|\(.value.reason)|\(.value.locked_at)"' "$LOCKED_FILE" 2>/dev/null | while IFS='|' read -r u r t; do
            printf " %-3s | %-12s | %-20s | %-16s\n" "$no." "$u" "${r:0:20}" "$t"
            ((no++))
        done
    fi
    echo "======================================"
    pause
}

unlock_xray_user() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║        UNLOCK AKUN XRAY (OPEN)     ║"
    echo "╚════════════════════════════════════╝"
    LOCKED_FILE="/usr/local/etc/xray/locked.json"
    if [ ! -f "$LOCKED_FILE" ] || [ "$(jq 'length' "$LOCKED_FILE" 2>/dev/null)" -eq 0 ]; then
        echo -e " \e[32mTidak ada akun Xray yang sedang ter-lock.\e[0m"
        sleep 2; return
    fi
    
    mapfile -t locked_users < <(jq -r 'keys[]' "$LOCKED_FILE" 2>/dev/null)
    echo "Pilih Akun Xray yang ingin di-unlock:"
    no=1
    for u in "${locked_users[@]}"; do
        r=$(jq -r --arg u "$u" '.[$u].reason' "$LOCKED_FILE" 2>/dev/null)
        echo " $no) $u (Alasan: $r)"
        ((no++))
    done
    echo " 0) Batal"
    echo "--------------------------------------"
    read -p " Pilih Opsi [1-${#locked_users[@]} or 0]: " sel
    if [[ "$sel" == "0" || -z "$sel" ]]; then return; fi
    
    idx=$((sel - 1))
    if [ $idx -ge 0 ] && [ $idx -lt ${#locked_users[@]} ]; then
        target_user="${locked_users[$idx]}"
        client_data=$(jq -c --arg u "$target_user" '.[$u].client_data' "$LOCKED_FILE" 2>/dev/null)
        
        if [ -n "$client_data" ] && [ "$client_data" != "null" ]; then
            jq --argjson c "$client_data" '(.inbounds[] | select(.protocol == "vmess" or .protocol == "vless" or .protocol == "trojan") | .settings.clients) += [$c]' /usr/local/etc/xray/config.json > /tmp/config.json
            if [ -s /tmp/config.json ]; then
                mv /tmp/config.json /usr/local/etc/xray/config.json
                jq --arg u "$target_user" 'del(.[$u])' "$LOCKED_FILE" > /tmp/locked.json && mv /tmp/locked.json "$LOCKED_FILE"
                systemctl restart xray
                [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
                echo -e "\n\e[32m[SUCCESS]\e[0m Akun \e[33m$target_user\e[0m berhasil di-unlock dan aktif kembali!"
            else
                echo -e "\n\e[31m[ERROR]\e[0m Gagal memperbarui config.json Xray."
            fi
        else
            echo -e "\n\e[31m[ERROR]\e[0m Data client untuk $target_user tidak ditemukan."
        fi
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1
    fi
    sleep 2
}

menu_xray() {
    XRAY_VER=$(/usr/local/bin/xray version 2>/dev/null | head -n 1 | awk '{print $1" "$2}')
    if [[ -z "$XRAY_VER" ]]; then XRAY_VER="Xray 24.11.11"; fi
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║              MENU XRAY             ║"
        echo "╚════════════════════════════════════╝"
        echo " Versi: ${XRAY_VER}"
        echo "======================================"
        echo " 1. Create XRAY Account"
        echo " 2. Delete XRAY Account"
        echo " 3. Renew XRAY Account"
        echo " 4. List XRAY Account"
        echo " 5. Detail XRAY Account"
        echo " 6. Change UUID / Password"
        echo " 7. List Locked Accounts"
        echo " 8. Unlock XRAY Account"
        echo "--------------------------------------"
        echo " 0. Kembali ke Menu Utama"
        echo "======================================"
        read -p " Pilih opsi [0-8]: " opt
        case $opt in
            1) create_xray ;; 
            2) delete_xray ;; 
            3) renew_xray ;; 
            4) list_xray ;;
            5) detail_xray ;;
            6) menu_change_uuid ;;
            7) list_locked_xray ;;
            8) unlock_xray_user ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
