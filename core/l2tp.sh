#!/bin/bash
# ==========================================
# l2tp.sh
# MODULE: L2TP & IPsec LOGIC
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
add_l2tp() {
    clear
    echo "======================================"
    echo "         CREATE L2TP ACCOUNT          "
    echo "======================================"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" || -z "$user" ]]; then return; fi
    read -p "Password       : " pwd
    read -p "Expired (Hari) : " masaaktif

    # L2TP tidak menggunakan limit IP/Quota pada V5 ini, tapi kita set 0 secara default untuk DB
    data="{\"user\":\"$user\", \"password\":\"$pwd\", \"exp\":$masaaktif, \"limit_ip\":0, \"limit_quota\":0}"
    call_api "add-l2tp" "POST" "$data"
}

add_trial_l2tp() {
    clear
    echo "======================================"
    echo "         CREATE TRIAL ACCOUNT         "
    echo "======================================"
    echo " Memproses akun trial L2TP VPN (60 Menit)..."
    call_api "trial-l2tp" "POST" "{}"
}

# ==========================================
# MANAJEMEN AKUN
# ==========================================
delete_l2tp() {
    clear
    echo "======================================"
    echo "         DELETE L2TP ACCOUNT          "
    echo "======================================"
    read -p "Username yang akan dihapus: " user
    if [ -z "$user" ]; then return; fi

    data="{\"user\":\"$user\"}"
    call_api "del-l2tp" "DELETE" "$data"
}

renew_l2tp() {
    clear
    echo "======================================"
    echo "         RENEW L2TP ACCOUNT           "
    echo "======================================"
    read -p "Username yang akan diperpanjang: " user
    if [ -z "$user" ]; then return; fi
    
    read -p "Tambah Masa Aktif (Hari): " masaaktif
    data="{\"user\":\"$user\", \"exp\":$masaaktif}"
    call_api "renew-l2tp" "POST" "$data"
}

detail_l2tp() {
    clear
    echo "======================================"
    echo "         DETAIL L2TP ACCOUNT          "
    echo "======================================"
    read -p "Username : " user
    if [ -z "$user" ]; then return; fi
    
    data="{\"user\":\"$user\"}"
    call_api "detail-l2tp" "POST" "$data"
}

list_l2tp() {
    clear
    echo "======================================================="
    echo "                 DAFTAR AKUN L2TP AKTIF                "
    echo "======================================================="
    printf " %-15s | %-10s | %-12s\n" "Username" "Status" "Expired Date"
    echo "-------------------------------------------------------"
    
    # Menampilkan data langsung dari SQLite agar sangat cepat
    sqlite3 "$DB_PATH" "SELECT username, status, expired_at FROM vpn_accounts WHERE protocol='l2tp' ORDER BY username ASC;" | while read -r line; do
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
# MAIN ROUTER MENU L2TP
# ==========================================
menu_l2tp() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║             MENU L2TP              ║"
        echo "╚════════════════════════════════════╝"
        echo " 1. Create L2TP Account"
        echo " 2. Create Trial L2TP (60M)"
        echo "--------------------------------------"
        echo " 3. Delete L2TP Account"
        echo " 4. Renew L2TP Account"
        echo " 5. Detail L2TP Account"
        echo " 6. List L2TP Account"
        echo "--------------------------------------"
        echo " 0/x. Kembali ke Menu Utama"
        echo "======================================"
        read -p " Pilih opsi [0-6 or x]: " opt
        case $opt in
            1) add_l2tp ;; 
            2) add_trial_l2tp ;; 
            3) delete_l2tp ;; 
            4) renew_l2tp ;; 
            5) detail_l2tp ;; 
            6) list_l2tp ;; 
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
