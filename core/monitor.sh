#!/bin/bash
# ==========================================
# monitor.sh
# MODULE: MONITORING IP & DATA USAGE
# ==========================================

source /usr/local/etc/srpcom/env.conf

monitor_xray_ip() {
    clear
    echo "================================================="
    echo "           XRAY ACTIVE IP MONITOR                "
    echo "================================================="
    echo -e "Username\t| Jml IP\t| Daftar IP Address"
    echo "-------------------------------------------------"
    if [ ! -f "/var/log/xray/access.log" ]; then
        echo "Log file belum tersedia atau Xray belum berjalan."
        pause; return
    fi
    
    # Membaca log 2000 baris terakhir, mencari status "accepted", dan mengekstrak IP unik per akun
    tail -n 2000 /var/log/xray/access.log | grep "accepted" | grep -v "127.0.0.1" | awk '{print $7, $3}' | sed 's/tcp://g' | sed 's/udp://g' | cut -d: -f1 | sort | uniq | awk '{
        ip_count[$1]++
        ips[$1] = ips[$1] " " $2
    } END {
        for (user in ip_count) {
            printf "%-15s | %-7s | %s\n", user, ip_count[user], ips[user]
        }
    }'
    echo "================================================="
    pause
}

monitor_xray_data() {
    clear
    echo "==============================================================="
    echo "                  XRAY DATA USAGE MONITOR                      "
    echo "==============================================================="
    
    # Menarik data statistik langsung dari mesin Xray via port API 10085
    /usr/local/bin/xray api statsquery --server=127.0.0.1:10085 > /tmp/xray_stats.json 2>/dev/null
    
    # Mem-parsing JSON statistik menggunakan Python agar rapi dan akurat
    python3 -c "
import json, os
try:
    with open('/tmp/xray_stats.json', 'r') as f: data = json.load(f)
    stats = {}
    for item in data.get('stat', []):
        name_parts = item['name'].split('>>>')
        if len(name_parts) >= 4 and name_parts[0] == 'user':
            user = name_parts[1]
            t_type = name_parts[3]
            if user not in stats: stats[user] = {'downlink': 0, 'uplink': 0}
            stats[user][t_type] = item.get('value', 0)
    
    print(f'{\"Username\":<15} | {\"Download\":<10} | {\"Upload\":<10} | {\"Total\":<10} | {\"Limit Kuota\"}')
    print('-'*70)
    for u, s in stats.items():
        dl = s['downlink'] / 1048576  # Convert Byte to MB
        ul = s['uplink'] / 1048576
        tot = dl + ul
        tot_gb = tot / 1024           # Convert MB to GB
        
        limit_gb = 'Unli'
        if os.path.exists('/usr/local/etc/xray/limit.txt'):
            with open('/usr/local/etc/xray/limit.txt', 'r') as lf:
                for line in lf:
                    parts = line.strip().split()
                    if len(parts) >= 3 and parts[0] == u:
                        l_quota = int(parts[2])
                        limit_gb = f'{l_quota} GB' if l_quota > 0 else 'Unli'
                        break

        print(f'{u:<15} | {dl:<7.1f} MB | {ul:<7.1f} MB | {tot_gb:<7.2f} GB | {limit_gb}')
except Exception as e:
    print('Gagal membaca data API Xray. Pastikan API Xray sudah diaktifkan.')
"
    echo "==============================================================="
    pause
}

monitor_ssh() {
    clear
    echo "========================================="
    echo "       SSH / DROPBEAR ACTIVE USER        "
    echo "========================================="
    echo -e "PID\t| Username\t| IP Address"
    echo "-----------------------------------------"
    # Mencari koneksi TCP yang ESTABLISHED untuk dropbear dan sshd
    netstat -tnpa | grep ESTABLISHED | grep -E "dropbear|sshd" > /tmp/ssh_con.txt
    while read line; do
        pid=$(echo $line | awk '{print $7}' | cut -d'/' -f1)
        ip=$(echo $line | awk '{print $5}' | cut -d':' -f1)
        user=$(ps -o user= -p $pid 2>/dev/null | tr -d ' ')
        if [ -n "$user" ] && [ "$user" != "root" ]; then
            printf "%-7s | %-13s | %s\n" "$pid" "$user" "$ip"
        fi
    done < /tmp/ssh_con.txt
    echo "========================================="
    pause
}

menu_monitor() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║          MONITORING PANEL          ║"
        echo "╚════════════════════════════════════╝"
        echo "1. Cek User Aktif (Xray IP)"
        echo "2. Cek Pemakaian Data (Xray Kuota)"
        echo "3. Cek User Aktif (SSH/Dropbear)"
        echo "0. Back to Main Menu"
        echo "======================================"
        read -p "Pilih opsi [0-3]: " opt
        case $opt in
            1) monitor_xray_ip ;;
            2) monitor_xray_data ;;
            3) monitor_ssh ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
