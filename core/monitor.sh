#!/bin/bash
# ==========================================
# monitor.sh
# MODULE: LIVE MONITORING
# Memantau aktivitas login user SSH dan Log Xray
# ==========================================

source /usr/local/etc/srpcom/env.conf

monitor_xray() {
    clear
    echo "======================================"
    echo "       LIVE XRAY USAGE MONITOR        "
    echo "======================================"
    printf " %-2s | %-12s | %-3s | %-8s\n" "No" "User" "IP" "Usage"
    echo "--------------------------------------"
    
    mapfile -t xray_users < <(jq -r '.inbounds[] | select(.protocol=="vmess" or .protocol=="vless" or .protocol=="trojan") | .protocol as $prot | .settings.clients[].email | "\($prot):\(.)"' /usr/local/etc/xray/config.json 2>/dev/null)
    
    if [ ${#xray_users[@]} -eq 0 ] || [ -z "${xray_users[0]}" ]; then
        echo " Belum ada akun Xray yang dibuat."
    else
        stats_json=$(/usr/local/bin/xray api statsquery --server=127.0.0.1:10085 2>/dev/null)
        
        no=1
        for item in "${xray_users[@]}"; do
            prot=$(echo "$item" | cut -d':' -f1)
            user=$(echo "$item" | cut -d':' -f2)
            
            ip_count=$(grep "email: $user$" /var/log/xray/access.log 2>/dev/null | awk '{print $3}' | cut -d: -f1 | sort -u | wc -l)
            
            dl=$(echo "$stats_json" | jq -r '.stat[] | select(.name == "user>>>'${user}'>>>traffic>>>downlink") | .value' 2>/dev/null)
            ul=$(echo "$stats_json" | jq -r '.stat[] | select(.name == "user>>>'${user}'>>>traffic>>>uplink") | .value' 2>/dev/null)
            
            dl=${dl:-0}
            ul=${ul:-0}
            total_bytes=$((dl + ul))
            
            # Format Data lebih ringkas untuk HP
            if [ "$total_bytes" -ge 1073741824 ]; then
                total_gb=$(awk "BEGIN {printf \"%.2fGB\", $total_bytes/1073741824}")
            elif [ "$total_bytes" -ge 1048576 ]; then
                total_gb=$(awk "BEGIN {printf \"%.0fMB\", $total_bytes/1048576}")
            else
                total_gb="0MB"
            fi
            
            local display_user="${user:0:12}"
            printf " %-2s | %-12s | %-3s | %-8s\n" "$no." "$display_user" "$ip_count" "$total_gb"
            ((no++))
        done
    fi
    
    echo "======================================"
    pause
}

monitor_ssh() {
    clear
    echo "======================================"
    echo "      MONITORING USER SSH AKTIF       "
    echo "======================================"
    echo " USERNAME   |  PID  |   IP ADDRESS    "
    echo "--------------------------------------"
    
    tmp_log="/tmp/active_ssh_monitor.log"
    > "$tmp_log"
    
    netstat -tnpa 2>/dev/null | grep 'ESTABLISHED' | grep -E 'sshd|dropbear' | while read -r line; do
        ip_port=$(echo "$line" | awk '{print $5}')
        client_ip=$(echo "$ip_port" | cut -d':' -f1)
        
        if [[ "$client_ip" == "127.0.0.1" || "$client_ip" == "::1" ]]; then continue; fi
        
        pid_prog=$(echo "$line" | awk '{print $7}')
        pid=$(echo "$pid_prog" | cut -d'/' -f1)
        
        user=$(ps -o user= -p "$pid" 2>/dev/null | awk '{print $1}')
        
        if [[ -n "$user" && "$user" != "root" && "$user" != "sshd" && "$user" != "messagebus" ]]; then
            local display_user="${user:0:10}"
            printf " %-10s | %-5s | %-15s \n" "$display_user" "$pid" "$client_ip" >> "$tmp_log"
        fi
    done
    
    if [ -s "$tmp_log" ]; then
        cat "$tmp_log" | sort -u
        total=$(cat "$tmp_log" | sort -u | wc -l)
        echo "--------------------------------------"
        echo " Total Aktif: $total User Login"
    else
        echo " Belum ada user aktif saat ini."
    fi
    
    rm -f "$tmp_log"
    echo "======================================"
    pause
}

menu_monitor() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║          MONITORING PANEL          ║"
        echo "╚════════════════════════════════════╝"
        echo " 1. Monitor SSH & Dropbear (Live)"
        echo " 2. Monitor Xray & Kuota (Tabel)"
        echo " 3. Xray Access Log (Live Tail)"
        echo " 4. Xray Error Log (Live Tail)"
        echo "--------------------------------------"
        echo " 0/x. Kembali ke Menu Utama"
        echo "======================================"
        read -p " Pilih Opsi [0-4 or x]: " opt
        case $opt in
            1) monitor_ssh ;;
            2) monitor_xray ;;
            3) 
                echo -e "\n\e[33m[INFO]\e[0m Membuka log akses Xray..."
                echo -e "\e[31m=> Tekan Ctrl+C untuk keluar.\e[0m\n"
                sleep 2; tail -f /var/log/xray/access.log ;;
            4) 
                echo -e "\n\e[33m[INFO]\e[0m Membuka log error Xray..."
                echo -e "\e[31m=> Tekan Ctrl+C untuk keluar.\e[0m\n"
                sleep 2; tail -f /var/log/xray/error.log ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
