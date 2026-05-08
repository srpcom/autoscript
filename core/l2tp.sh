#!/bin/bash
# ==========================================
# l2tp.sh
# MODULE: L2TP/IPsec LOGIC
# Berisi logika pembuatan, penghapusan, dan manajemen akun L2TP
# ==========================================

source /usr/local/etc/srpcom/env.conf

# File kredensial L2TP/IPsec
CHAP_SECRETS="/etc/ppp/chap-secrets"
L2TP_EXP="/usr/local/etc/srpcom/l2tp_expiry.txt"
IPSEC_PSK="srpcom_vpn" # Default Pre-Shared Key

add_l2tp() {
    clear
    echo "======================================"
    echo "       CREATE L2TP/IPsec ACCOUNT      "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    
    # Cek apakah user sudah ada
    if grep -qw "^\"$user\"" $CHAP_SECRETS; then
        echo -e "\n=> Error: Username sudah ada!"
        sleep 2; return
    fi
    
    read -p "Password             : " pass
    read -p "Expired (Days)       : " masaaktif
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    
    # Menulis kredensial ke chap-secrets
    echo "\"$user\" l2tpd \"$pass\" *" >> $CHAP_SECRETS
    echo "$user $pass $exp_date $exp_time" >> $L2TP_EXP
    
    # Restart layanan
    systemctl restart ipsec xl2tpd

    msg_cli=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nIPsec PSK : ${IPSEC_PSK}\nUsername : ${user}\nPassword : ${pass}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    msg_tg=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nIPsec PSK : \`${IPSEC_PSK}\`\nUsername : \`${user}\`\nPassword : \`${pass}\`\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

del_l2tp() {
    clear
    echo "======================================"
    echo "          DELETE L2TP ACCOUNT         "
    echo "======================================"
    if [ ! -s "$L2TP_EXP" ]; then
        echo "Tidak ada akun L2TP."
        pause; return
    fi

    mapfile -t users < <(awk '{print $1}' $L2TP_EXP)
    for i in "${!users[@]}"; do
        echo "$((i+1)). ${users[$i]}"
    done
    echo "0. Back"
    echo "======================================"
    read -p "Pilih nomor akun untuk dihapus [1-${#users[@]}]: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#users[@]}" ]]; then
        user="${users[$((choice-1))]}"
        
        # Hapus dari chap-secrets dan expiry list
        sed -i "/^\"$user\" l2tpd/d" $CHAP_SECRETS
        sed -i "/^$user /d" $L2TP_EXP
        
        systemctl restart ipsec xl2tpd
        echo -e "\n=> Akun L2TP '$user' berhasil dihapus!"
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; del_l2tp
    fi
}

renew_l2tp() {
    clear
    echo "======================================"
    echo "          RENEW L2TP ACCOUNT          "
    echo "======================================"
    if [ ! -s "$L2TP_EXP" ]; then
        echo "Tidak ada akun L2TP."
        pause; return
    fi

    mapfile -t users < <(awk '{print $1}' $L2TP_EXP)
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
        
        current_data=$(grep "^$user " $L2TP_EXP)
        pass=$(echo "$current_data" | awk '{print $2}')
        current_date=$(echo "$current_data" | awk '{print $3}')
        current_time=$(echo "$current_data" | awk '{print $4}')
        
        if [ -z "$current_date" ]; then current_date=$(date +"%Y-%m-%d"); fi
        if [ -z "$current_time" ]; then current_time=$(date +"%H:%M:%S"); fi
        
        new_exp_date=$(date -d "$current_date $current_time + $masaaktif days" +"%Y-%m-%d")
        new_exp_time=$(date -d "$current_date $current_time + $masaaktif days" +"%H:%M:%S")
        
        sed -i "/^$user /d" $L2TP_EXP
        echo "$user $pass $new_exp_date $new_exp_time" >> $L2TP_EXP
        
        echo -e "\n=> Akun '$user' diperpanjang $masaaktif Hari!"
        echo "=> Expired Baru: $new_exp_date $new_exp_time WIB"
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; renew_l2tp
    fi
}

list_l2tp() {
    clear
    echo "======================================"
    echo "          LIST L2TP ACCOUNTS          "
    echo "======================================"
    echo -e "\n\e[32m[ L2TP/IPsec ]\e[0m"
    echo "--------------------------------------"
    if [ ! -s "$L2TP_EXP" ]; then 
        echo "Tidak ada akun."
    else 
        awk '{print "- "$1" (Exp: "$3" "$4" WIB)"}' $L2TP_EXP
    fi
    echo -e "\n======================================"
    pause
}

menu_l2tp() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║              MENU L2TP             ║"
        echo "╚════════════════════════════════════╝"
        echo "1. Create L2TP Account"
        echo "2. Delete L2TP Account"
        echo "3. Renew L2TP Account"
        echo "4. List L2TP Account"
        echo "0. Back to Main Menu"
        echo "======================================"
        read -p "Please select an option [0-4]: " opt
        case $opt in
            1) add_l2tp ;; 
            2) del_l2tp ;; 
            3) renew_l2tp ;; 
            4) list_l2tp ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
