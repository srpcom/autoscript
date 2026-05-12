#!/bin/bash
# ==========================================
# ssh.sh
# MODULE: SSH & OVPN LOGIC
# SQLITE & API-DRIVEN VERSION
# ==========================================

source /usr/local/etc/srpcom/env.conf
DB_PATH="/usr/local/etc/srpcom/database.db"

# Ambil API Key untuk otentikasi eksekusi lokal
API_KEY=$(sqlite3 "$DB_PATH" "SELECT key_value FROM system_settings WHERE key_name='api_key';" 2>/dev/null)
if [ -z "$API_KEY" ]; then API_KEY="SANGATRAHASIA123"; fi

# ==========================================
# FUNGSI HELPER: REQUEST KE API
# ==========================================
call_api() {
    local endpoint=$1
    local method=$2
    local data=$3
    
    echo -e "\n=> Memproses ke Sistem Database & OS..."
    # Kirim request ke API lokal dan parsing field 'stdout' dari respon JSON
    result=$(curl -s -X $method -H "Content-Type: application/json" -H "x-api-key: $API_KEY" -d "$data" "http://127.0.0.1:5000/user_legend/$endpoint")
    
    clear
    # Ekstrak pesan menggunakan jq
    echo "$result" | jq -r '.stdout'
    pause
}

# ==========================================
# MENU CREATE ACCOUNT
# ==========================================
add_ssh() {
    clear
    echo "======================================"
    echo "       CREATE SSH & OVPN ACCOUNT      "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" || -z "$user" ]]; then return; fi
    read -p "Password       : " pwd
    read -p "Expired (Hari) : " masaaktif
    read -p "Limit IP       : " limit_ip

    if [ -z "$limit_ip" ]; then limit_ip=0; fi

    data="{\"user\":\"$user\", \"password\":\"$pwd\", \"exp\":$masaaktif, \"limit_ip\":$limit_ip}"
    call_api "add-ssh" "POST" "$data"
}

add_trial_ssh() {
    clear
    echo "======================================"
    echo "         CREATE TRIAL ACCOUNT         "
    echo "======================================"
    echo " Memproses akun trial SSH & OVPN (60 Menit)..."
    call_api "trial-ssh" "POST" "{}"
}

# ==========================================
# MANAJEMEN AKUN
# ==========================================
delete_ssh() {
    clear
    echo "======================================"
    echo "         DELETE SSH ACCOUNT           "
    echo "======================================"
    read -p "Username yang akan dihapus: " user
    if [ -z "$user" ]; then return; fi

    data="{\"user\":\"$user\"}"
    call_api "del-ssh" "DELETE" "$data"
}

renew_ssh() {
    clear
    echo "======================================"
    echo "         RENEW SSH ACCOUNT            "
    echo "======================================"
    read -p "Username yang akan diperpanjang: " user
    if [ -z "$user" ]; then return; fi
    
    read -p "Tambah Masa Aktif (Hari): " masaaktif
    data="{\"user\":\"$user\", \"exp\":$masaaktif}"
    call_api "renew-ssh" "POST" "$data"
}

detail_ssh() {
    clear
    echo "======================================"
    echo "         DETAIL SSH ACCOUNT           "
    echo "======================================"
    read -p "Username : " user
    if [ -z "$user" ]; then return; fi
    
    data="{\"user\":\"$user\"}"
    call_api "detail-ssh" "POST" "$data"
}

list_ssh() {
    clear
    echo "======================================================="
    echo "                 DAFTAR AKUN SSH AKTIF                 "
    echo "======================================================="
    printf " %-15s | %-10s | %-12s\n" "Username" "Status" "Expired Date"
    echo "-------------------------------------------------------"
    
    # Menampilkan data langsung dari SQLite agar sangat cepat
    sqlite3 "$DB_PATH" "SELECT username, status, expired_at FROM vpn_accounts WHERE protocol='ssh' ORDER BY username ASC;" | while read -r line; do
        u=$(echo "$line" | cut -d'|' -f1)
        s=$(echo "$line" | cut -d'|' -f2)
        e=$(echo "$line" | cut -d'|' -f3 | cut -d' ' -f1)
        
        # Pewarnaan untuk status
        if [[ "$s" == "locked" ]]; then status_color="\e[31m$s\e[0m"
        else status_color="\e[32m$s\e[0m"; fi
        
        printf " %-15s | %-19b | %-12s\n" "$u" "$status_color" "$e"
    done
    
    echo "======================================================="
    pause
}

# ==========================================
# MAIN ROUTER MENU SSH
# ==========================================
menu_ssh() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║      MENU SSH & OVPN (SQLITE)      ║"
        echo "╚════════════════════════════════════╝"
        echo " 1. Create SSH Account"
        echo " 2. Create Trial Account (60M)"
        echo "--------------------------------------"
        echo " 3. Delete SSH Account"
        echo " 4. Renew SSH Account"
        echo " 5. Detail SSH Account"
        echo " 6. List SSH Account"
        echo "--------------------------------------"
        echo " 0/x. Kembali ke Menu Utama"
        echo "======================================"
        read -p " Pilih opsi [0-6 or x]: " opt
        case $opt in
            1) add_ssh ;; 
            2) add_trial_ssh ;; 
            3) delete_ssh ;; 
            4) renew_ssh ;; 
            5) detail_ssh ;; 
            6) list_ssh ;; 
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
