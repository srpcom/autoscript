#!/bin/bash
# ==========================================
# ssh.sh
# MODULE: SSH & OVPN LOGIC
# Manajemen User SSH menggunakan sistem akun Linux standar
# ==========================================

source /usr/local/etc/srpcom/env.conf

SSH_EXP="/usr/local/etc/srpcom/ssh_expiry.txt"

add_ssh() {
    clear
    echo "======================================"
    echo "       CREATE SSH & OVPN ACCOUNT      "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    
    # Cek apakah user sudah ada di sistem Linux
    if id "$user" &>/dev/null; then
        echo -e "\n=> Error: Username '$user' sudah ada di sistem!"
        sleep 2; return
    fi
    
    read -p "Password             : " pass
    read -p "Expired (Days)       : " masaaktif
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    
    # Membuat user Linux baru (tanpa akses shell interaktif)
    useradd -e "$exp_date" -s /bin/false -M "$user"
    echo -e "$pass\n$pass" | passwd "$user" &> /dev/null
    
    # Simpan ke database txt kita
    echo "$user $pass $exp_date $exp_time" >> $SSH_EXP

    msg_cli=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nUsername : ${user}\nPassword : ${pass}\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH : 22\nPort Dropbear : 109, 143\nPort SSH-WS TLS : 443 (Path: /sshws)\nPort SSH-WS NTLS : 80 (Path: /sshws)\nPort UDP Custom : 1-65535\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    msg_tg=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ SSH & OVPN ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nUsername : \`${user}\`\nPassword : \`${pass}\`\n━━━━━━━━━━━━━━━━━━━━\nPort OpenSSH : 22\nPort Dropbear : 109, 143\nPort SSH-WS TLS : 443 (Path: /sshws)\nPort SSH-WS NTLS : 80 (Path: /sshws)\nPort UDP Custom : 1-65535\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

trial_ssh() {
    clear
    echo "======================================"
    echo "      CREATE TRIAL SSH (60 Mins)      "
    echo "======================================"
    user="trial-$(date +%m%d%H%M)"
    pass="1"
    masaaktif="60 Menit"
    
    exp_date=$(date -d "+60 minutes" +"%Y-%m-%d")
    exp_time=$(date -d "+60 minutes" +"%H:%M:%S")
    
    useradd -e "$exp_date" -s /bin/false -M "$user"
    echo -e "$pass\n$pass" | passwd "$user" &> /dev/null
    
    echo "$user $pass $exp_date $exp_time" >> $SSH_EXP

    msg_cli=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ TRIAL SSH ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\nUsername : ${user}\nPassword : ${pass}\nDomain : ${DOMAIN}\nIP : ${IP_ADD}\n━━━━━━━━━━━━━━━━━━━━\nPort SSH/Dropbear : 22, 109, 143\nPort SSH-WS : 80, 443 (Path: /sshws)\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif})")
    
    msg_tg=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ TRIAL SSH ACCOUNT ❖\n━━━━━━━━━━━━━━━━━━━━\nUsername : \`${user}\`\nPassword : \`${pass}\`\nDomain : ${DOMAIN}\nIP : ${IP_ADD}\n━━━━━━━━━━━━━━━━━━━━\nPort SSH/Dropbear : 22, 109, 143\nPort SSH-WS : 80, 443 (Path: /sshws)\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif})")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

del_ssh() {
    clear
    echo "======================================"
    echo "          DELETE SSH ACCOUNT          "
    echo "======================================"
    if [ ! -s "$SSH_EXP" ]; then
        echo "Tidak ada akun SSH."
        pause; return
    fi

    mapfile -t users < <(awk '{print $1}' $SSH_EXP)
    for i in "${!users[@]}"; do
        echo "$((i+1)). ${users[$i]}"
    done
    echo "0. Back"
    echo "======================================"
    read -p "Pilih nomor akun untuk dihapus [1-${#users[@]}]: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        
        # Hapus user dari sistem Linux dan file txt
        userdel -f "$user" 2>/dev/null
        sed -i "/^$user /d" $SSH_EXP
        
        echo -e "\n=> Akun SSH '$user' berhasil dihapus!"
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; del_ssh
    fi
}

renew_ssh() {
    clear
    echo "======================================"
    echo "          RENEW SSH ACCOUNT           "
    echo "======================================"
    if [ ! -s "$SSH_EXP" ]; then echo "Tidak ada akun SSH."; pause; return; fi

    mapfile -t users < <(awk '{print $1}' $SSH_EXP)
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    echo "0. Back"
    echo "======================================"
    read -p "Pilih nomor akun [1-${#users[@]}]: " choice
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        read -p "Tambah Masa Aktif (Hari): " masaaktif
        
        current_data=$(grep "^$user " $SSH_EXP)
        pass=$(echo "$current_data" | awk '{print $2}')
        current_date=$(echo "$current_data" | awk '{print $3}')
        current_time=$(echo "$current_data" | awk '{print $4}')
        
        if [ -z "$current_date" ]; then current_date=$(date +"%Y-%m-%d"); fi
        if [ -z "$current_time" ]; then current_time=$(date +"%H:%M:%S"); fi
        
        new_exp_date=$(date -d "$current_date $current_time + $masaaktif days" +"%Y-%m-%d")
        new_exp_time=$(date -d "$current_date $current_time + $masaaktif days" +"%H:%M:%S")
        
        # Update expired date di sistem Linux
        chage -E "$new_exp_date" "$user"
        
        sed -i "/^$user /d" $SSH_EXP
        echo "$user $pass $new_exp_date $new_exp_time" >> $SSH_EXP
        
        echo -e "\n=> Akun '$user' diperpanjang $masaaktif Hari!"
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
    echo -e "\n\e[32m[ SSH / Dropbear / OVPN ]\e[0m"
    echo "--------------------------------------"
    if [ ! -s "$SSH_EXP" ]; then 
        echo "Tidak ada akun."
    else 
        awk '{print "- "$1" (Exp: "$3" "$4" WIB)"}' $SSH_EXP
    fi
    echo -e "\n======================================"
    pause
}

detail_ssh() {
    clear
    echo "======================================"
    echo "         DETAIL SSH ACCOUNT           "
    echo "======================================"
    if [ ! -s "$SSH_EXP" ]; then echo "Tidak ada akun SSH."; pause; return; fi

    mapfile -t users < <(awk '{print $1}' $SSH_EXP)
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    echo "0. Back"
    echo "======================================"
    read -p "Select Account [0-${#users[@]}]: " choice
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        current_data=$(grep "^$user " $SSH_EXP)
        pass=$(echo "$current_data" | awk '{print $2}')
        exp_date=$(echo "$current_data" | awk '{print $3}')
        exp_time=$(echo "$current_data" | awk '{print $4}')
        
        clear
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "❖ SSH & OVPN ACCOUNT ❖"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "Remarks : ${user}"
        echo "IP Address : ${IP_ADD}"
        echo "Domain : ${DOMAIN}"
        echo "Username : ${user}"
        echo "Password : ${pass}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "Port OpenSSH : 22"
        echo "Port Dropbear : 109, 143"
        echo "Port SSH-WS TLS : 443 (Path: /sshws)"
        echo "Port SSH-WS NTLS : 80 (Path: /sshws)"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "EXPIRED ON : ${exp_date} ${exp_time} WIB"
        echo ""
        pause
        detail_ssh
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; detail_ssh
    fi
}

lock_unlock_ssh() {
    action=$1
    clear
    echo "======================================"
    if [ "$action" == "lock" ]; then echo "          LOCK SSH ACCOUNT"; else echo "         UNLOCK SSH ACCOUNT"; fi
    echo "======================================"
    if [ ! -s "$SSH_EXP" ]; then echo "Tidak ada akun SSH."; pause; return; fi

    mapfile -t users < <(awk '{print $1}' $SSH_EXP)
    for i in "${!users[@]}"; do echo "$((i+1)). ${users[$i]}"; done
    echo "0. Back"
    echo "======================================"
    read -p "Pilih nomor akun [1-${#users[@]}]: " choice
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        if [ "$action" == "lock" ]; then
            usermod -L "$user"
            echo -e "\n=> Akun '$user' berhasil di-LOCK (Tidak bisa login)!"
        else
            usermod -U "$user"
            echo -e "\n=> Akun '$user' berhasil di-UNLOCK (Bisa login kembali)!"
        fi
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; lock_unlock_ssh "$action"
    fi
}

menu_ssh() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║              MENU SSH              ║"
        echo "╚════════════════════════════════════╝"
        echo "1. Create SSH Account"
        echo "2. Create Trial SSH"
        echo "3. Delete SSH Account"
        echo "4. Renew SSH Account"
        echo "5. List SSH Account"
        echo "6. Detail SSH Account"
        echo "7. Lock SSH Account"
        echo "8. Unlock SSH Account"
        echo "0. Back to Main Menu"
        echo "======================================"
        read -p "Please select an option [0-8]: " opt
        case $opt in
            1) add_ssh ;; 
            2) trial_ssh ;;
            3) del_ssh ;; 
            4) renew_ssh ;; 
            5) list_ssh ;;
            6) detail_ssh ;;
            7) lock_unlock_ssh "lock" ;;
            8) lock_unlock_ssh "unlock" ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
