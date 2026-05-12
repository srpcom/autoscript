#!/bin/bash
# ==========================================
# xray.sh
# MODULE: XRAY LOGIC (SQLITE VERSION - FULL FEATURES)
# Mengelola akun Xray dengan integrasi murni ke API & Database
# ==========================================

source /usr/local/etc/srpcom/env.conf
DB_PATH="/usr/local/etc/srpcom/database.db"

# Ambil API Key untuk otentikasi
API_KEY=$(sqlite3 "$DB_PATH" "SELECT key_value FROM system_settings WHERE key_name='api_key';" 2>/dev/null)
if [ -z "$API_KEY" ]; then API_KEY="SANGATRAHASIA123"; fi

# ==========================================
# FUNGSI HELPER: REQUEST KE API
# ==========================================
call_api() {
    local endpoint=$1
    local method=$2
    local data=$3
    
    echo -e "\n=> Memproses ke Sistem Database & Core..."
    result=$(curl -s -X $method -H "Content-Type: application/json" -H "x-api-key: $API_KEY" -d "$data" "http://127.0.0.1:5000/user_legend/$endpoint")
    
    clear
    # Ekstrak pesan menggunakan jq agar output rapi
    echo "$result" | jq -r '.stdout'
    pause
}

# ==========================================
# FUNGSI HELPER: CETAK TABEL USER (Cepat via SQLite)
# ==========================================
print_user_table() {
    local filter_prot=$1
    clear
    echo "======================================================="
    echo "                 DAFTAR AKUN XRAY AKTIF                "
    echo "======================================================="
    printf " %-3s | %-14s | %-8s | %-12s\n" "No" "Username" "Protocol" "Sisa Hari"
    echo "-------------------------------------------------------"
    
    local query="SELECT username, protocol, expired_at FROM vpn_accounts WHERE protocol IN ('vmessws', 'vlessws', 'trojanws')"
    if [ -n "$filter_prot" ]; then
        query="$query AND protocol='${filter_prot}ws'"
    fi
    query="$query ORDER BY protocol ASC"
    
    local no=1
    sqlite3 "$DB_PATH" "$query" 2>/dev/null | while read -r line; do
        u=$(echo "$line" | cut -d'|' -f1)
        p=$(echo "$line" | cut -d'|' -f2)
        e=$(echo "$line" | cut -d'|' -f3)
        
        # Hitung sisa hari
        if [[ "$e" == "Lifetime" ]]; then
            sisa="\e[32mLifetime\e[0m"
        else
            exp_sec=$(date -d "$e" +%s 2>/dev/null)
            now_sec=$(date +%s)
            diff=$((exp_sec - now_sec))
            if [ "$diff" -lt 0 ]; then sisa="\e[31mExpired\e[0m"
            else sisa="$((diff / 86400)) Hari"; fi
        fi
        
        # Format protocol string (hapus 'ws' di belakang)
        prot_disp=${p%ws}
        
        printf " %-3s | %-14s | %-8s | %-19b\n" "$no" "$u" "${prot_disp^^}" "$sisa"
        no=$((no + 1))
    done
    echo "======================================================="
}

# ==========================================
# MENU CREATE ACCOUNT
# ==========================================
add_xray() {
    clear
    echo "======================================"
    echo "         CREATE XRAY ACCOUNT          "
    echo "======================================"
    echo " 1. VMess WebSocket"
    echo " 2. VLess WebSocket"
    echo " 3. Trojan WebSocket"
    echo "======================================"
    read -p " Pilih Protokol [1-3 or 0]: " prot_opt
    
    case $prot_opt in
        1) prot="vmessws" ;;
        2) prot="vlessws" ;;
        3) prot="trojanws" ;;
        0) return ;;
        *) echo "Pilihan tidak valid!"; sleep 1; return ;;
    esac

    echo "--------------------------------------"
    read -p "Username (x = Batal) : " user
    if [[ "$user" == "x" || "$user" == "X" || -z "$user" ]]; then return; fi
    
    local pwd=""
    if [[ "$prot" == "trojanws" ]]; then
        read -p "Custom Password (Kosong=Random): " pwd
    fi

    read -p "Limit IP (0=Unli)    : " limit_ip
    read -p "Limit Kuota GB (0=Unli): " limit_quota
    read -p "Expired (Hari)       : " masaaktif

    if [ -z "$limit_ip" ]; then limit_ip=0; fi
    if [ -z "$limit_quota" ]; then limit_quota=0; fi
    if [ -z "$masaaktif" ]; then masaaktif=30; fi

    data="{\"user\":\"$user\", \"password\":\"$pwd\", \"exp\":$masaaktif, \"limit_ip\":$limit_ip, \"limit_quota\":$limit_quota}"
    call_api "add-$prot" "POST" "$data"
}

add_trial_xray() {
    clear
    echo "======================================"
    echo "         CREATE TRIAL ACCOUNT         "
    echo "======================================"
    echo " Pilih Protokol Trial (60 Menit):"
    echo " 1. VMess WebSocket"
    echo " 2. VLess WebSocket"
    echo " 3. Trojan WebSocket"
    echo "======================================"
    read -p " Pilih [1-3 or x]: " prot_opt
    
    case $prot_opt in
        1) prot="vmessws" ;;
        2) prot="vlessws" ;;
        3) prot="trojanws" ;;
        *) return ;;
    esac

    call_api "trial-$prot" "POST" "{}"
}

# ==========================================
# MANAJEMEN AKUN
# ==========================================
delete_xray() {
    print_user_table ""
    echo " Pilih Protokol Akun yang Dihapus:"
    echo " 1. VMess  2. VLess  3. Trojan"
    read -p " Pilih [1-3]: " prot_opt
    case $prot_opt in
        1) prot="vmessws" ;; 2) prot="vlessws" ;; 3) prot="trojanws" ;; *) return ;;
    esac
    
    read -p "Username yang akan dihapus: " user
    if [ -z "$user" ]; then return; fi

    data="{\"user\":\"$user\"}"
    call_api "del-$prot" "DELETE" "$data"
}

renew_xray() {
    print_user_table ""
    echo " Pilih Protokol Akun yang Diperpanjang:"
    echo " 1. VMess  2. VLess  3. Trojan"
    read -p " Pilih [1-3]: " prot_opt
    case $prot_opt in
        1) prot="vmessws" ;; 2) prot="vlessws" ;; 3) prot="trojanws" ;; *) return ;;
    esac
    
    read -p "Username yang akan diperpanjang: " user
    if [ -z "$user" ]; then return; fi
    
    read -p "Tambah Masa Aktif (Hari): " masaaktif
    if [ -z "$masaaktif" ]; then return; fi

    data="{\"user\":\"$user\", \"exp\":$masaaktif}"
    call_api "renew-$prot" "POST" "$data"
}

detail_xray() {
    print_user_table ""
    echo " Pilih Protokol Akun untuk Cek Detail:"
    echo " 1. VMess  2. VLess  3. Trojan"
    read -p " Pilih [1-3]: " prot_opt
    case $prot_opt in
        1) prot="vmessws" ;; 2) prot="vlessws" ;; 3) prot="trojanws" ;; *) return ;;
    esac
    
    read -p "Username : " user
    if [ -z "$user" ]; then return; fi
    
    data="{\"user\":\"$user\"}"
    call_api "detail-$prot" "POST" "$data"
}

# ==========================================
# GANTI UUID / PASSWORD
# ==========================================
change_protocol_uuid() {
    local prot=$1
    local db_prot="${prot}ws"
    
    print_user_table "$prot"
    read -p "Username yang akan diganti UUID/Pass: " user
    if [ -z "$user" ]; then return; fi
    
    # Ambil UUID lama dari Database
    old_uuid=$(sqlite3 "$DB_PATH" "SELECT uuid_pass FROM vpn_accounts WHERE username='$user' AND protocol='$db_prot';" 2>/dev/null)
    
    if [ -z "$old_uuid" ]; then
        echo -e "\n\e[31m[ERROR]\e[0m Username '$user' tidak ditemukan di database!"
        sleep 2; return
    fi

    if [[ "$prot" == "trojan" ]]; then
        read -p "Masukkan Password Baru (Kosong=Random): " new_uuid
        if [ -z "$new_uuid" ]; then new_uuid=$(cat /proc/sys/kernel/random/uuid | cut -d- -f1); fi
    else
        read -p "Masukkan UUID Baru (Kosong=Random): " new_uuid
        if [ -z "$new_uuid" ]; then new_uuid=$(cat /proc/sys/kernel/random/uuid); fi
    fi

    data="{\"uuidold\":\"$old_uuid\", \"uuidnew\":\"$new_uuid\"}"
    call_api "change-uuid" "POST" "$data"
}

menu_change_uuid() {
    clear
    echo "======================================"
    echo "      CHANGE UUID / PASSWORD XRAY     "
    echo "======================================"
    echo " 1. VMess"
    echo " 2. VLess"
    echo " 3. Trojan"
    echo "======================================"
    read -p " Pilih Protokol [1-3 or 0] : " opt
    case $opt in
        1) change_protocol_uuid "vmess" ;;
        2) change_protocol_uuid "vless" ;;
        3) change_protocol_uuid "trojan" ;;
        0) return ;;
        *) echo -e "\n=> Pilihan tidak valid!"; sleep 1; menu_change_uuid ;;
    esac
}

# ==========================================
# MAIN ROUTER MENU XRAY
# ==========================================
menu_xray() {
    XRAY_VER=$(/usr/local/bin/xray version 2>/dev/null | head -n 1 | awk '{print $1" "$2}')
    if [[ -z "$XRAY_VER" ]]; then XRAY_VER="Xray 24.11.11"; fi
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║         MENU XRAY (SQLITE)         ║"
        echo "╚════════════════════════════════════╝"
        echo " Versi: ${XRAY_VER}"
        echo "======================================"
        echo " 1. Create XRAY Account"
        echo " 2. Create Trial Account (60M)"
        echo "--------------------------------------"
        echo " 3. Delete XRAY Account"
        echo " 4. Renew XRAY Account"
        echo " 5. List XRAY Account"
        echo " 6. Detail XRAY Account"
        echo " 7. Change UUID / Password"
        echo "--------------------------------------"
        echo " 0. Kembali ke Menu Utama"
        echo "======================================"
        read -p " Pilih opsi [0-7]: " opt
        case $opt in
            1) add_xray ;;
            2) add_trial_xray ;;
            3) delete_xray ;;
            4) renew_xray ;;
            5) print_user_table ""; pause ;;
            6) detail_xray ;;
            7) menu_change_uuid ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
