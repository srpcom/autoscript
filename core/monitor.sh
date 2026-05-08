#!/bin/bash
# ==========================================
# monitor.sh
# MODULE: MONITORING IP & DATA USAGE
# Menampilkan detail IP aktif dan Kuota secara bersamaan
# ==========================================

source /usr/local/etc/srpcom/env.conf

monitor_xray() {
    clear
    echo "======================================================================================="
    echo "                   XRAY MONITORING (ACTIVE IP & DATA USAGE)                            "
    echo "======================================================================================="
    
    # Menarik data statistik langsung dari mesin Xray via port API 10085
    /usr/local/bin/xray api statsquery --server=127.0.0.1:10085 > /tmp/xray_stats.json 2>/dev/null
    
    # Mem-parsing log IP dan JSON statistik menggunakan Python agar rapi dan digabung
    python3 -c "
import json, os

# 1. Mengambil IP Aktif dari access.log
ip_data = {}
try:
    log_lines = os.popen('tail -n 3000 /var/log/xray/access.log').read().splitlines()
    for line in log_lines:
        if 'accepted' in line and '127.0.0.1' not in line:
            parts = line.split()
            if len(parts) >= 7:
                user = parts[6] # email
                ip_port = parts[2] # IP:Port
                ip = ip_port.replace('tcp:', '').replace('udp:', '').split(':')[0]
                if user not in ip_data:
                    ip_data[user] = set()
                ip_data[user].add(ip)
except Exception:
    pass

# 2. Mengambil Data Kuota dari xray_stats.json
stats = {}
try:
    with open('/tmp/xray_stats.json', 'r') as f:
        data = json.load(f)
        for item in data.get('stat', []):
            name_parts = item['name'].split('>>>')
            if len(name_parts) >= 4 and name_parts[0] == 'user':
                user = name_parts[1]
                t_type = name_parts[3]
                if user not in stats:
                    stats[user] = {'downlink': 0, 'uplink': 0}
                stats[user][t_type] = item.get('value', 0)
except Exception:
    pass

# 3. Mengambil Info Limit (IP & Kuota)
limits = {}
try:
    if os.path.exists('/usr/local/etc/xray/limit.txt'):
        with open('/usr/local/etc/xray/limit.txt', 'r') as f:
            for line in f:
                p = line.strip().split()
                if len(p) >= 3:
                    limits[p[0]] = {'ip': int(p[1]), 'quota': int(p[2])}
except:
    pass

# Menggabungkan semua user yang terdeteksi
all_users = set(list(stats.keys()) + list(ip_data.keys()))

print(f'{\"Username\":<15} | {\"IP Aktif/Limit\":<15} | {\"Download\":<10} | {\"Upload\":<10} | {\"Total Data\":<10} | {\"Limit Kuota\"}')
print('-'*87)

if not all_users:
    print('Belum ada data pemakaian atau user aktif.')
else:
    for u in sorted(all_users):
        # Info IP
        active_ips = len(ip_data.get(u, set()))
        limit_ip = limits.get(u, {}).get('ip', 0)
        lim_ip_str = str(limit_ip) if limit_ip > 0 else 'Unli'
        ip_col = f'{active_ips} / {lim_ip_str}'

        # Info Data
        dl = stats.get(u, {}).get('downlink', 0) / 1048576  # MB
        ul = stats.get(u, {}).get('uplink', 0) / 1048576    # MB
        tot = dl + ul
        tot_gb = tot / 1024                                 # GB
        
        limit_q = limits.get(u, {}).get('quota', 0)
        lim_q_str = f'{limit_q} GB' if limit_q > 0 else 'Unli'

        print(f'{u:<15} | {ip_col:<15} | {dl:<7.1f} MB | {ul:<7.1f} MB | {tot_gb:<7.2f} GB | {lim_q_str}')
"
    echo "======================================================================================="
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
        echo "1. Cek Aktifitas Xray (IP & Kuota)"
        echo "2. Cek User Aktif (SSH/Dropbear)"
        echo "0. Back to Main Menu"
        echo "======================================"
        read -p "Pilih opsi [0-2]: " opt
        case $opt in
            1) monitor_xray ;;
            2) monitor_ssh ;;
            0) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
