#!/bin/bash
# ==========================================
# monitor.sh
# MODULE: LIVE MONITORING & DEBUGGING
# Memantau aktivitas login user dan System Logs
# SQLITE VERSION
# ==========================================

source /usr/local/etc/srpcom/env.conf
DB_PATH="/usr/local/etc/srpcom/database.db"

monitor_xray() {
    clear
    echo "======================================"
    echo "       LIVE XRAY USAGE MONITOR        "
    echo "======================================"
    printf " %-2s | %-12s | %-3s | %-8s\n" "No" "User" "IP" "Usage"
    echo "--------------------------------------"
    
    # Ambil user dari SQLite
    xray_users=$(sqlite3 "$DB_PATH" "SELECT username FROM vpn_accounts WHERE protocol IN ('vmessws', 'vlessws', 'trojanws') AND status='active';" 2>/dev/null)
    
    if [ -z "$xray_users" ]; then
        echo " Belum ada akun Xray yang dibuat."
    else
        # Tarik data penggunaan Xray langsung dari API lokal
        stats_json=$(/usr/local/bin/xray api statsquery --server=127.0.0.1:10085 2>/dev/null)
        
        # Salin log Xray sementara
        cp /var/log/xray/access.log /tmp/xray_access_mon.log 2>/dev/null
        
        no=1
        for user in $xray_users; do
            # Hitung IP Unik Aktif dari log
            ip_count=$(grep "email: $user$" /tmp/xray_access_mon.log 2>/dev/null | awk '{print $3}' | cut -d: -f1 | sort -u | wc -l)
            
            # Ekstrak data kuota menggunakan jq
            dl=$(echo "$stats_json" | jq -r '.stat[] | select(.name == "user>>>'${user}'>>>traffic>>>downlink") | .value' 2>/dev/null)
            ul=$(echo "$stats_json" | jq -r '.stat[] | select(.name == "user>>>'${user}'>>>traffic>>>uplink") | .value' 2>/dev/null)
            
            dl=${dl:-0}
            ul=${ul:-0}
            total_bytes=$((dl + ul))
            
            # Format Output Usage (MB/GB)
            if [ "$total_bytes" -ge 1073741824 ]; then
                usage=$(awk "BEGIN {printf \"%.2f GB\", $total_bytes / 1073741824}")
            elif [ "$total_bytes" -ge 1048576 ]; then
                usage=$(awk "BEGIN {printf \"%.2f MB\", $total_bytes / 1048576}")
            elif [ "$total_bytes" -gt 0 ]; then
                usage=$(awk "BEGIN {printf \"%.2f KB\", $total_bytes / 1024}")
            else
                usage="0 MB"
            fi
            
            if [ "$ip_count" -gt 0 ] || [ "$total_bytes" -gt 0 ]; then
               printf " %-2s | %-12s | %-3s | %-8s\n" "$no" "$user" "$ip_count" "$usage"
               no=$((no + 1))
            fi
        done
        rm -f /tmp/xray_access_mon.log
        if [ "$no" -eq 1 ]; then
             echo " Belum ada aktivitas penggunaan."
        fi
    fi
    echo "======================================"
    pause
}

monitor_ssh() {
    clear
    echo "======================================"
    echo "      LIVE SSH & OVPN MONITOR         "
    echo "======================================"
    printf " %-2s | %-12s | %-6s\n" "No" "User" "Login"
    echo "--------------------------------------"
    
    ssh_users=$(sqlite3 "$DB_PATH" "SELECT username FROM vpn_accounts WHERE protocol='ssh' AND status='active';" 2>/dev/null)
    
    if [ -z "$ssh_users" ]; then
        echo " Belum ada akun SSH yang dibuat."
    else
        no=1
        for user in $ssh_users; do
             total_login=$(ps -u "$user" 2>/dev/null | grep -E -c "sshd|dropbear")
             if [ "$total_login" -gt 0 ]; then
                 printf " %-2s | %-12s | %-6s\n" "$no" "$user" "$total_login"
                 no=$((no + 1))
             fi
        done
        if [ "$no" -eq 1 ]; then
             echo " Belum ada user SSH yang online."
        fi
    fi
    echo "======================================"
    pause
}

menu_monitor() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║            LIVE MONITOR            ║"
        echo "╚════════════════════════════════════╝"
        echo " 1. Monitor XRAY (Usage & IP)"
        echo " 2. Monitor SSH (Multi-Login)"
        echo "--------------------------------------"
        echo " 3. Live Log Xray Access"
        echo " 4. Live Log Xray Error"
        echo " 5. Live Log L2TP/IPsec"
        echo " 6. Live Log OpenVPN"
        echo "--------------------------------------"
        echo " 0. Kembali ke Menu Utama"
        echo "======================================"
        read -p " Pilih Opsi [0-6]: " opt
        case $opt in
            1) monitor_xray ;;
            2) monitor_ssh ;;
            3) 
                echo -e "\n\e[33m[INFO]\e[0m Membuka log akses Xray..."
                echo -e "\e[31m=> Tekan Ctrl+C untuk keluar.\e[0m\n"
                sleep 2; tail -f /var/log/xray/access.log ;;
            4) 
                echo -e "\n\e[33m[INFO]\e[0m Membuka log error Xray..."
                echo -e "\e[31m=> Tekan Ctrl+C untuk keluar.\e[0m\n"
                sleep 2; tail -f /var/log/xray/error.log ;;
            5)
                echo -e "\n\e[33m[INFO]\e[0m Membuka live log L2TP & IPsec..."
                echo -e "\e[31m=> Tekan Ctrl+C untuk keluar.\e[0m\n"
                sleep 2; journalctl -u xl2tpd -u ipsec -f ;;
            6)
                echo -e "\n\e[33m[INFO]\e[0m Membuka live log OpenVPN TCP & UDP..."
                echo -e "\e[31m=> Tekan Ctrl+C untuk keluar.\e[0m\n"
                sleep 2; journalctl -u openvpn-server@server-udp -u openvpn-server@server-tcp -f ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
