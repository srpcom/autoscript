#!/bin/bash
# ==========================================
# l2tp.sh
# MODULE: L2TP & IPsec LOGIC
# Mengelola akun L2TP VPN
# ==========================================

source /usr/local/etc/srpcom/env.conf

add_l2tp() {
    clear
    echo "======================================"
    echo "         CREATE L2TP ACCOUNT          "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" ]]; then return; fi
    
    # Cek apakah user sudah ada
    if grep -q "^\"$user\" l2tpd" /etc/ppp/chap-secrets 2>/dev/null; then
        echo -e "\n\e[31m[ERROR]\e[0m Username '$user' sudah digunakan!"
        sleep 2; return
    fi
    
    read -p "Password       : " password
    read -p "Expired (Days) : " masaaktif
    
    exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
    exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
    
    # Menambahkan ke konfigurasi sistem (chap-secrets)
    echo "\"$user\" l2tpd \"$password\" *" >> /etc/ppp/chap-secrets
    
    # Menyimpan database kustom
    echo "$user $password $exp_date $exp_time" >> /usr/local/etc/srpcom/l2tp_expiry.txt
    
    # Restart layanan agar membaca config baru
    systemctl restart ipsec xl2tpd
    
    msg_cli=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : ${user}\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nIPsec PSK : srpcom_vpn\nUsername : ${user}\nPassword : ${password}\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    msg_tg=$(echo -e "━━━━━━━━━━━━━━━━━━━━\n❖ L2TP / IPsec VPN ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nIP Address : ${IP_ADD}\nDomain : ${DOMAIN}\nIPsec PSK : \`srpcom_vpn\`\nUsername : \`${user}\`\nPassword : \`${password}\`\n━━━━━━━━━━━━━━━━━━━━\nEXPIRED ON : ${exp_date} ${exp_time} WIB (${masaaktif} days)")
    
    clear; echo "$msg_cli"
    send_telegram "$msg_tg"
    pause
}

delete_l2tp() {
    clear
    echo "======================================"
    echo "         DELETE L2TP ACCOUNT          "
    echo "======================================"
    if [ ! -f "/usr/local/etc/srpcom/l2tp_expiry.txt" ]; then
        echo "Belum ada akun L2TP yang dibuat."
        pause; return
    fi
    
    mapfile -t users < <(awk '{print $1}' /usr/local/etc/srpcom/l2tp_expiry.txt)
    
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
        sed -i "/^\"$user\" l2tpd/d" /etc/ppp/chap-secrets
        sed -i "/^$user /d" /usr/local/etc/srpcom/l2tp_expiry.txt
        systemctl restart ipsec xl2tpd
        
        echo -e "\n\e[32m=> Akun L2TP '$user' berhasil dihapus!\e[0m"
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; delete_l2tp
    fi
}

renew_l2tp() {
    clear
    echo "======================================"
    echo "          RENEW L2TP ACCOUNT          "
    echo "======================================"
    if [ ! -f "/usr/local/etc/srpcom/l2tp_expiry.txt" ]; then
        echo "Belum ada akun L2TP yang dibuat."
        pause; return
    fi
    
    mapfile -t users < <(awk '{print $1}' /usr/local/etc/srpcom/l2tp_expiry.txt)
    
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
        
        current_data=$(grep "^$user " /usr/local/etc/srpcom/l2tp_expiry.txt)
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
        
        # Update TXT database
        sed -i "/^$user /d" /usr/local/etc/srpcom/l2tp_expiry.txt
        echo "$user $pw $new_exp_date $new_exp_time" >> /usr/local/etc/srpcom/l2tp_expiry.txt
        
        echo -e "\n\e[32m=> Akun L2TP '$user' diperpanjang $masaaktif Hari!\e[0m"
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
    if [ ! -f "/usr/local/etc/srpcom/l2tp_expiry.txt" ]; then
        echo "Belum ada akun L2TP."
    else
        awk '{print "- " $1 " (Exp: " $3 ")"}' /usr/local/etc/srpcom/l2tp_expiry.txt
    fi
    echo "======================================"
    pause
}

detail_l2tp() {
    clear
    echo "======================================"
    echo "         DETAIL L2TP ACCOUNT          "
    echo "======================================"
    if [ ! -f "/usr/local/etc/srpcom/l2tp_expiry.txt" ]; then
        echo "Belum ada akun L2TP yang dibuat."
        pause; return
    fi
    
    mapfile -t users < <(awk '{print $1}' /usr/local/etc/srpcom/l2tp_expiry.txt)
    
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
        
        current_data=$(grep "^$user " /usr/local/etc/srpcom/l2tp_expiry.txt)
        pw=$(echo "$current_data" | awk '{print $2}')
        dt_str=$(echo "$current_data" | awk '{print $3 " " $4}')

        clear
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "❖ L2TP / IPsec VPN ❖"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "Remarks : ${user}"
        echo "IP Address : ${IP_ADD}"
        echo "Domain : ${DOMAIN}"
        echo "IPsec PSK : srpcom_vpn"
        echo "Username : ${user}"
        echo "Password : ${pw}"
        echo "━━━━━━━━━━━━━━━━━━━━"
        echo "EXPIRED ON : ${dt_str} WIB"
        echo ""
        pause
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; detail_l2tp
    fi
}

menu_l2tp() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║             MENU L2TP              ║"
        echo "╚════════════════════════════════════╝"
        echo "1. Create L2TP Account"
        echo "2. Delete L2TP Account"
        echo "3. Renew L2TP Account"
        echo "4. List L2TP Account"
        echo "5. Detail L2TP Account"
        echo "0/x. Back to Main Menu"
        echo "======================================"
        read -p "Please select an option [0-5 or x]: " opt
        case $opt in
            1) add_l2tp ;; 
            2) delete_l2tp ;; 
            3) renew_l2tp ;;
            4) list_l2tp ;;
            5) detail_l2tp ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
