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
    
    # Cek apakah user sudah ada di OS
    if id "$user" &>/dev/null; then
        echo -e "\n\e[31m[ERROR]\e[0m Username '$user' sudah digunakan!"
        sleep 2; return
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
    
    lim_str="${limit_ip} IP"
    if [ "$limit_ip" -eq 0 ]; then lim_str="Unlimited"; fi

    msg_cli=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nUsername : ${user}\nPassword : ${password}\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH : 22\nPort Dropbear : 109, 143\nPort SSH-WS TLS : 443 (Path: /sshws)\nPort SSH-WS NTLS : 80 (Path: /sshws)\nPort UDP Custom : 7100, 7200, 7300\nPort OVPN UDP : 2200\nPort OVPN TCP : 1194\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${lim_str}\n━━━━━━━━━━━━━━━━━━━━\nLINK OVPN UDP : http://${DOMAIN}/ovpn/udp.ovpn\nLINK OVPN TCP : http://${DOMAIN}/ovpn/tcp.ovpn\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    msg_tg=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nUsername : \`${user}\`\nPassword : \`${password}\`\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH : 22\nPort Dropbear : 109, 143\nPort SSH-WS TLS : 443 (Path: /sshws)\nPort SSH-WS NTLS : 80 (Path: /sshws)\nPort UDP Custom : 7100, 7200, 7300\nPort OVPN UDP : 2200\nPort OVPN TCP : 1194\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${lim_str}\n━━━━━━━━━━━━━━━━━━━━\nLINK OVPN UDP : \`http://${DOMAIN}/ovpn/udp.ovpn\`\nLINK OVPN TCP : \`http://${DOMAIN}/ovpn/tcp.ovpn\`\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

add_trial_ssh() {
    clear
    echo "======================================"
    echo "     CREATE TRIAL SSH ACCOUNT (60M)   "
    echo "======================================"
    
    # PERBAIKAN: Format Jam-Menit-Detik + 1 Karakter Random
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
    
    msg_cli=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ TRIAL SSH & OVPN ❖\n━━━━━━━━━━━━━━━━━━━━\nUsername : ${user}\nPassword : ${password}\nDomain : ${DOMAIN}\nIP : ${IP_ADD}\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif})")
    
    msg_tg=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ TRIAL SSH & OVPN ❖\n━━━━━━━━━━━━━━━━━━━━\nUsername : \`${user}\`\nPassword : \`${password}\`\nDomain : ${DOMAIN}\nIP : ${IP_ADD}\n━━━━━━━━━━━━━━━━━━━━\nLimit IP : ${limit_ip} IP\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif})")
    
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
        
        current_sec=$(date -d "$current_date $current_time" +%s 2>/dev/null)
        if [ -z "$current_sec" ]; then current_sec=$(date +%s); fi
        
        new_sec=$((current_sec + (masaaktif * 86400)))
        new_exp_date=$(date -d "@$new_sec" +"%Y-%m-%d")
        new_exp_time=$(date -d "@$new_sec" +"%H:%M:%S")
        
        # Update OS expiry parameter
        chage -E "$new_exp_date" "$user"
        
        # Update TXT database
        sed -i "/^$user /d" /usr/local/etc/srpcom/ssh_expiry.txt
        echo "$user $pw $new_exp_date $new_exp_time" >> /usr/local/etc/srpcom/ssh_expiry.txt
        
        echo -e "\n\e[32m=> Akun SSH '$user' diperpanjang $masaaktif Hari!\e[0m"
        echo "=> Expired Baru: $new_exp_date $new_exp_time WIB"
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
        if [[ -z "$limit_ip" || "$limit_ip" -eq 0 ]]; then lim_str="Unlimited"; fi

        clear
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "❖ SSH & OVPN ACCOUNT ❖"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "Remarks : ${user}"
        echo "IP Address : ${IP_ADD}"
        echo "Domain : ${DOMAIN}"
        echo "Username : ${user}"
        echo "Password : ${pw}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "Limit IP : ${lim_str}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "LINK OVPN UDP : http://${DOMAIN}/ovpn/udp.ovpn"
        echo "LINK OVPN TCP : http://${DOMAIN}/ovpn/tcp.ovpn"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "EXPIRED ON : ${dt_str} WIB"
        echo ""
        pause
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; detail_ssh
    fi
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
        echo "0/x. Back to Main Menu"
        echo "======================================"
        read -p "Please select an option [0-6 or x]: " opt
        case $opt in
            1) add_ssh ;; 
            2) add_trial_ssh ;; 
            3) delete_ssh ;; 
            4) renew_ssh ;;
            5) list_ssh ;;
            6) detail_ssh ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
