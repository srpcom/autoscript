#!/bin/bash
# ==========================================
# ssh.sh
# MODULE: SSH & OVPN LOGIC
# Mengelola akun OpenSSH, Dropbear, SSH-WS, OVPN, BadVPN
# ==========================================

source /usr/local/etc/srpcom/env.conf

add_ssh() {
    clear
    echo "======================================"
    echo "       CREATE SSH & OVPN ACCOUNT      "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    
    # Cek apakah user sudah ada di OS, jika ada tambahkan angka berurutan
    original_user="$user"
    counter=2
    while id "$user" &>/dev/null; do
        user="${original_user}${counter}"
        ((counter++))
    done
    
    if [[ "$original_user" != "$user" ]]; then
        echo -e "\n\e[33m[INFO]\e[0m Username '$original_user' sudah digunakan. Akun akan dibuat dengan nama: $user"
    fi
    
    read -p "Password       : " password
    read -p "Limit IP       : " limit_ip
    read -p "Expired (Days) : " masaaktif
    
    if [ -z "$limit_ip" ]; then limit_ip=0; fi
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    
    # Buat user di Linux
    useradd -e "$exp_date" -s /bin/false -M "$user"
    echo "$user:$password" | chpasswd
    
    # Simpan ke database
    echo "$user $password $exp_date $exp_time" >> /usr/local/etc/srpcom/ssh_expiry.txt
    echo "$user $limit_ip" >> /usr/local/etc/srpcom/ssh_limit.txt
    [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
    
    lim_str="${limit_ip} IP"
    if [ "$limit_ip" -eq 0 ]; then lim_str="Not Active (Unli)"; fi

    msg_cli=$(echo -e "Akun Berhasil Dibuat!\n\n━━━━━━━━━━━━━━━━━━━━\nINFORMASI PREMIUM\nSSH & OVPN ACCOUNT\n━━━━━━━━━━━━━━━━━━━━\nIP-Address: ${IP_ADD}\nHostname: ${DOMAIN}\nUsername: ${user}\nPassword: ${password}\nLimit IP: ${lim_str}\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH: 22\nPort Dropbear: 109, 143\nPort SSH WS HTTPS (TLS): 443\nPort SSH WS HTTP (NTLS): 80\nPort BadVPN/UDPGW: 7100, 7200, 7300\n━━━━━━━━━━━━━━━━━━━━\nOPENVPN TCP (1194): http://${DOMAIN}/ovpn/tcp.ovpn\nOPENVPN UDP (2200): http://${DOMAIN}/ovpn/udp.ovpn\n━━━━━━━━━━━━━━━━━━━━\nPayload SSH WS: GET /sshws HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]\n━━━━━━━━━━━━━━━━━━━━\nPayload WS ENHANCED: GET /sshws HTTP/1.1[crlf]Host: ISI_BUG_DISINI[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]\n━━━━━━━━━━━━━━━━━━━━\nExpired on: ${exp_date} ${exp_time} WIB (${masaaktif} Hari)")
    
    msg_tg=$(echo -e "Akun Berhasil Dibuat!\n\n━━━━━━━━━━━━━━━━━━━━\nINFORMASI PREMIUM\nSSH & OVPN ACCOUNT\n━━━━━━━━━━━━━━━━━━━━\nIP-Address: ${IP_ADD}\nHostname: ${DOMAIN}\nUsername: \`${user}\`\nPassword: \`${password}\`\nLimit IP: ${lim_str}\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH: 22\nPort Dropbear: 109, 143\nPort SSH WS HTTPS (TLS): 443\nPort SSH WS HTTP (NTLS): 80\nPort BadVPN/UDPGW: 7100, 7200, 7300\n━━━━━━━━━━━━━━━━━━━━\nOPENVPN TCP (1194): \`http://${DOMAIN}/ovpn/tcp.ovpn\`\nOPENVPN UDP (2200): \`http://${DOMAIN}/ovpn/udp.ovpn\`\n━━━━━━━━━━━━━━━━━━━━\nPayload SSH WS: \`GET /sshws HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]\`\n━━━━━━━━━━━━━━━━━━━━\nPayload WS ENHANCED: \`GET /sshws HTTP/1.1[crlf]Host: ISI_BUG_DISINI[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]\`\n━━━━━━━━━━━━━━━━━━━━\nExpired on: ${exp_date} ${exp_time} WIB (${masaaktif} Hari)")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

add_trial_ssh() {
    clear
    echo "======================================"
    echo "     CREATE TRIAL SSH ACCOUNT (60M)   "
    echo "======================================"
    
    # Format Jam-Menit-Detik + 1 Karakter Random
    rand_char=$(tr -dc 'a-z' < /dev/urandom | head -c 1)
    user="trialsrp-$(date +%H%M%S)${rand_char}"
    
    password="1"
    limit_ip=1
    masaaktif="60 Minutes"
    
    exp_date=$(date -d "+60 minutes" +"%Y-%m-%d")
    exp_time=$(date -d "+60 minutes" +"%H:%M:%S")
    
    useradd -e "$exp_date" -s /bin/false -M "$user"
    echo "$user:$password" | chpasswd
    
    echo "$user $password $exp_date $exp_time" >> /usr/local/etc/srpcom/ssh_expiry.txt
    echo "$user $limit_ip" >> /usr/local/etc/srpcom/ssh_limit.txt
    [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
    
    msg_cli=$(echo -e "Akun Trial Dibuat!\n\n━━━━━━━━━━━━━━━━━━━━\nINFORMASI TRIAL\nSSH & OVPN ACCOUNT\n━━━━━━━━━━━━━━━━━━━━\nIP-Address: ${IP_ADD}\nHostname: ${DOMAIN}\nUsername: ${user}\nPassword: ${password}\nLimit IP: ${limit_ip} IP\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH: 22\nPort Dropbear: 109, 143\nPort SSH WS HTTPS (TLS): 443\nPort SSH WS HTTP (NTLS): 80\nPort BadVPN/UDPGW: 7100, 7200, 7300\n━━━━━━━━━━━━━━━━━━━━\nOPENVPN TCP (1194): http://${DOMAIN}/ovpn/tcp.ovpn\nOPENVPN UDP (2200): http://${DOMAIN}/ovpn/udp.ovpn\n━━━━━━━━━━━━━━━━━━━━\nPayload SSH WS: GET /sshws HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]\n━━━━━━━━━━━━━━━━━━━━\nPayload WS ENHANCED: GET /sshws HTTP/1.1[crlf]Host: ISI_BUG_DISINI[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]\n━━━━━━━━━━━━━━━━━━━━\nExpired on: ${exp_date} ${exp_time} WIB (${masaaktif})")
    
    msg_tg=$(echo -e "Akun Trial Dibuat!\n\n━━━━━━━━━━━━━━━━━━━━\nINFORMASI TRIAL\nSSH & OVPN ACCOUNT\n━━━━━━━━━━━━━━━━━━━━\nIP-Address: ${IP_ADD}\nHostname: ${DOMAIN}\nUsername: \`${user}\`\nPassword: \`${password}\`\nLimit IP: ${limit_ip} IP\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH: 22\nPort Dropbear: 109, 143\nPort SSH WS HTTPS (TLS): 443\nPort SSH WS HTTP (NTLS): 80\nPort BadVPN/UDPGW: 7100, 7200, 7300\n━━━━━━━━━━━━━━━━━━━━\nOPENVPN TCP (1194): \`http://${DOMAIN}/ovpn/tcp.ovpn\`\nOPENVPN UDP (2200): \`http://${DOMAIN}/ovpn/udp.ovpn\`\n━━━━━━━━━━━━━━━━━━━━\nPayload SSH WS: \`GET /sshws HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]\`\n━━━━━━━━━━━━━━━━━━━━\nPayload WS ENHANCED: \`GET /sshws HTTP/1.1[crlf]Host: ISI_BUG_DISINI[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]\`\n━━━━━━━━━━━━━━━━━━━━\nExpired on: ${exp_date} ${exp_time} WIB (${masaaktif})")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

delete_ssh() {
    clear
    echo "======================================"
    echo "         DELETE SSH ACCOUNT           "
    echo "======================================"
    if [ ! -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
        echo "Belum ada akun SSH yang dibuat."
        pause; return
    fi
    
    mapfile -t users < <(awk '{print $1}' /usr/local/etc/srpcom/ssh_expiry.txt)
    
    if [ ${#users[@]} -eq 0 ]; then
        echo "Tidak ada akun untuk dihapus."
        pause; return
    fi

    for i in "${!users[@]}"; do
        echo "$((i+1)). ${users[$i]}"
    done
    echo "0. Back"
    echo "x. Back to Main Menu"
    echo "======================================"
    read -p "Pilih nomor akun untuk dihapus [1-${#users[@]} or 0/x]: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi
    if [[ "$choice" == "x" || "$choice" == "X" ]]; then exec menu; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        
        # Hapus user dari OS dan file TXT
        userdel -f "$user" 2>/dev/null
        sed -i "/^$user /d" /usr/local/etc/srpcom/ssh_expiry.txt
        sed -i "/^$user /d" /usr/local/etc/srpcom/ssh_limit.txt
        [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
        
        echo -e "\n\e[32m=> Akun SSH '$user' berhasil dihapus!\e[0m"
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; delete_ssh
    fi
}

renew_ssh() {
    clear
    echo "======================================"
    echo "          RENEW SSH ACCOUNT           "
    echo "======================================"
    if [ ! -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
        echo "Belum ada akun SSH yang dibuat."
        pause; return
    fi
    
    mapfile -t users < <(awk '{print $1}' /usr/local/etc/srpcom/ssh_expiry.txt)
    
    if [ ${#users[@]} -eq 0 ]; then
        echo "Tidak ada akun untuk diperpanjang."
        pause; return
    fi

    for i in "${!users[@]}"; do
        echo "$((i+1)). ${users[$i]}"
    done
    echo "0. Back"
    echo "x. Back to Main Menu"
    echo "======================================"
    read -p "Pilih nomor akun [1-${#users[@]} or 0/x]: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi
    if [[ "$choice" == "x" || "$choice" == "X" ]]; then exec menu; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        read -p "Tambah Masa Aktif (Hari): " masaaktif
        
        current_data=$(grep "^$user " /usr/local/etc/srpcom/ssh_expiry.txt)
        pw=$(echo "$current_data" | awk '{print $2}')
        current_date=$(echo "$current_data" | awk '{print $3}')
        current_time=$(echo "$current_data" | awk '{print $4}')
        
        if [ -z "$current_date" ] || [ "$current_date" == "Lifetime" ]; then current_date=$(date +"%Y-%m-%d"); fi
        if [ -z "$current_time" ]; then current_time=$(date +"%H:%M:%S"); fi
        
        now_sec=$(date +%s)
        current_sec=$(date -d "$current_date $current_time" +%s 2>/dev/null)
        if [ -z "$current_sec" ]; then current_sec=$now_sec; fi
        
        # Akumulasi: Jika sudah expired, mulai dari hari ini. Jika belum, tambah dari sisa hari.
        if [ "$now_sec" -gt "$current_sec" ]; then
            current_sec=$now_sec
        fi
        
        new_sec=$((current_sec + (masaaktif * 86400)))
        new_exp_date=$(date -d "@$new_sec" +"%Y-%m-%d")
        new_exp_time=$(date -d "@$new_sec" +"%H:%M:%S")
        
        # Update OS expiry parameter
        chage -E "$new_exp_date" "$user"
        
        # Update TXT database
        sed -i "/^$user /d" /usr/local/etc/srpcom/ssh_expiry.txt
        echo "$user $pw $new_exp_date $new_exp_time" >> /usr/local/etc/srpcom/ssh_expiry.txt
        [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
        
        echo -e "\n\e[32m=> Akun SSH '$user' diperpanjang $masaaktif Hari!\e[0m"
        echo "=> Expired Baru: $new_exp_date $new_exp_time WIB"
        
        # --- TELEGRAM NOTIF RENEW ---
        msg_tg=$(echo -e "🕑 Akun Diperpanjang\n\n💻 Server: ${DOMAIN}\nType : SSH & OVPN\n🔑 Akun: \`${user}\`\n⏳ Durasi: +${masaaktif} hari\n📅 Expired Baru: ${new_exp_date} ${new_exp_time} WIB")
        send_telegram "$msg_tg"
        # ----------------------------
        
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; renew_ssh
    fi
}

list_ssh() {
    clear
    echo "======================================"
    echo "          LIST SSH ACCOUNTS           "
    echo "======================================"
    if [ ! -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
        echo "Belum ada akun SSH."
    else
        awk '{print "- " $1 " (Exp: " $3 ")"}' /usr/local/etc/srpcom/ssh_expiry.txt
    fi
    echo "======================================"
    pause
}

detail_ssh() {
    clear
    echo "======================================"
    echo "         DETAIL SSH ACCOUNT           "
    echo "======================================"
    if [ ! -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
        echo "Belum ada akun SSH yang dibuat."
        pause; return
    fi
    
    mapfile -t users < <(awk '{print $1}' /usr/local/etc/srpcom/ssh_expiry.txt)
    
    if [ ${#users[@]} -eq 0 ]; then
        echo "Tidak ada akun."
        pause; return
    fi

    for i in "${!users[@]}"; do
        echo "$((i+1)). ${users[$i]}"
    done
    echo "0. Back"
    echo "x. Back to Main Menu"
    echo "======================================"
    read -p "Pilih nomor akun [1-${#users[@]} or 0/x]: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi
    if [[ "$choice" == "x" || "$choice" == "X" ]]; then exec menu; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        
        current_data=$(grep "^$user " /usr/local/etc/srpcom/ssh_expiry.txt)
        pw=$(echo "$current_data" | awk '{print $2}')
        dt_str=$(echo "$current_data" | awk '{print $3 " " $4}')
        
        limit_ip=$(grep "^$user " /usr/local/etc/srpcom/ssh_limit.txt | awk '{print $2}')
        lim_str="${limit_ip} IP"
        if [[ -z "$limit_ip" || "$limit_ip" -eq 0 ]]; then lim_str="Not Active (Unli)"; fi

        msg_cli=$(echo -e "━━━━━━━━━━━━━━━━━━━━\nINFORMASI PREMIUM\nSSH & OVPN ACCOUNT\n━━━━━━━━━━━━━━━━━━━━\nIP-Address: ${IP_ADD}\nHostname: ${DOMAIN}\nUsername: ${user}\nPassword: ${pw}\nLimit IP: ${lim_str}\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH: 22\nPort Dropbear: 109, 143\nPort SSH WS HTTPS (TLS): 443\nPort SSH WS HTTP (NTLS): 80\nPort BadVPN/UDPGW: 7100, 7200, 7300\n━━━━━━━━━━━━━━━━━━━━\nOPENVPN TCP (1194): http://${DOMAIN}/ovpn/tcp.ovpn\nOPENVPN UDP (2200): http://${DOMAIN}/ovpn/udp.ovpn\n━━━━━━━━━━━━━━━━━━━━\nPayload SSH WS: GET /sshws HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]\n━━━━━━━━━━━━━━━━━━━━\nPayload WS ENHANCED: GET /sshws HTTP/1.1[crlf]Host: ISI_BUG_DISINI[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]\n━━━━━━━━━━━━━━━━━━━━\nExpired on: ${dt_str} WIB")

        clear
        echo "$msg_cli"
        echo ""
        pause
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; detail_ssh
    fi
}

list_locked_ssh() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║       DAFTAR AKUN SSH TERKUNCI     ║"
    echo "╚════════════════════════════════════╝"
    tmp_file="/tmp/locked_ssh_list.txt"
    > "$tmp_file"
    
    if [ -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
        awk '{print $1}' /usr/local/etc/srpcom/ssh_expiry.txt | while read -r user; do
            if [ -n "$user" ]; then
                passwd_status=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
                if [[ "$passwd_status" == "L" || "$passwd_status" == "LK" ]]; then
                    echo "$user" >> "$tmp_file"
                fi
            fi
        done
    fi
    
    if [ ! -s "$tmp_file" ]; then
        echo -e " \e[32mTidak ada akun SSH yang sedang ter-lock.\e[0m"
    else
        echo " USERNAME    | STATUS "
        echo "----------------------"
        while read -r u; do
            printf " %-11s | \e[31mLOCKED\e[0m\n" "$u"
        done < "$tmp_file"
    fi
    rm -f "$tmp_file"
    echo "======================================"
    pause
}

unlock_ssh_user() {
    clear
    echo "╔════════════════════════════════════╗"
    echo "║         UNLOCK AKUN SSH (OPEN)     ║"
    echo "╚════════════════════════════════════╝"
    tmp_file="/tmp/locked_ssh_list.txt"
    > "$tmp_file"
    
    if [ -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
        awk '{print $1}' /usr/local/etc/srpcom/ssh_expiry.txt | while read -r user; do
            if [ -n "$user" ]; then
                passwd_status=$(passwd -S "$user" 2>/dev/null | awk '{print $2}')
                if [[ "$passwd_status" == "L" || "$passwd_status" == "LK" ]]; then
                    echo "$user" >> "$tmp_file"
                fi
            fi
        done
    fi
    
    if [ ! -s "$tmp_file" ]; then
        echo -e " \e[32mTidak ada akun SSH yang sedang ter-lock.\e[0m"
        rm -f "$tmp_file"; sleep 2; return
    fi
    
    mapfile -t locked_ssh_users < "$tmp_file"
    rm -f "$tmp_file"
    
    echo "Pilih Akun SSH yang ingin di-unlock:"
    no=1
    for u in "${locked_ssh_users[@]}"; do
        echo " $no) $u"
        ((no++))
    done
    echo " 0) Batal"
    echo "--------------------------------------"
    read -p " Pilih Opsi [1-${#locked_ssh_users[@]} or 0]: " sel
    if [[ "$sel" == "0" || -z "$sel" ]]; then return; fi
    
    idx=$((sel - 1))
    if [ $idx -ge 0 ] && [ $idx -lt ${#locked_ssh_users[@]} ]; then
        target_user="${locked_ssh_users[$idx]}"
        usermod -U "$target_user" 2>/dev/null
        [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null
        echo -e "\n\e[32m[SUCCESS]\e[0m Akun SSH \e[33m$target_user\e[0m berhasil di-unlock dan dapat login kembali!"
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1
    fi
    sleep 2
}

menu_ssh() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║            MENU SSH & OVPN         ║"
        echo "╚════════════════════════════════════╝"
        echo "1. Create SSH Account"
        echo "2. Create Trial Account (60M)"
        echo "3. Delete SSH Account"
        echo "4. Renew SSH Account"
        echo "5. List SSH Account"
        echo "6. Detail SSH Account"
        echo "7. List Locked SSH Accounts"
        echo "8. Unlock SSH Account"
        echo "0/x. Back to Main Menu"
        echo "======================================"
        read -p "Please select an option [0-8 or x]: " opt
        case $opt in
            1) add_ssh ;; 
            2) add_trial_ssh ;; 
            3) delete_ssh ;; 
            4) renew_ssh ;;
            5) list_ssh ;;
            6) detail_ssh ;;
            7) list_locked_ssh ;;
            8) unlock_ssh_user ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
