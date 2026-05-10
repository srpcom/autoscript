#!/bin/bash
# ==========================================
# utils.sh
# MODULE: UTILITIES
# Berisi fungsi pembantu, pewarnaan, dan informasi OS
# ==========================================

# Memuat Environment Global (Domain, IP & VPS_NAME)
source /usr/local/etc/srpcom/env.conf

# Warna Standar
GREEN='\e[32m'
RED='\e[31m'
YELLOW='\e[33m'
CYAN='\e[36m'
NC='\e[0m' # No Color

pause() {
    echo ""
    read -n 1 -s -r -p "Tekan tombol apapun untuk kembali..."
}

print_header() {
    OS_SYS=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
    BIT=$(uname -m)
    if [[ "$BIT" == "x86_64" ]]; then BIT="(64 Bit)"; else BIT="(32 Bit)"; fi
    KRNL=$(uname -r)
    CPUMDL=$(awk -F: '/model name/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
    CPUFREQ=$(awk -F: '/cpu MHz/ {print $2; exit}' /proc/cpuinfo | sed 's/^[ \t]*//')
    if [[ -z "$CPUFREQ" ]]; then CPUFREQ="Unknown"; fi
    CORE=$(nproc)
    T_RAM=$(free -m | awk '/Mem:/ {printf "%.1f GB", $2/1024}')
    U_RAM=$(free -m | awk '/Mem:/ {printf "%.1f MB", $3}')
    T_DISK=$(df -h / | awk 'NR==2 {print $2}')
    U_DISK=$(df -h / | awk 'NR==2 {print $3}')
    ISP_NAME=$(curl -sS --max-time 3 ipinfo.io/org 2>/dev/null | cut -d' ' -f2-)
    REG=$(curl -sS --max-time 3 ipinfo.io/city 2>/dev/null)
    TZ=$(cat /etc/timezone 2>/dev/null)

    # ==========================================
    # MEMBACA MASA AKTIF LISENSI LIVE DARI API (D1)
    # ==========================================
    # Fallback jika VPS_NAME kosong di env.conf (VPS versi lama)
    if [ -z "$VPS_NAME" ]; then 
        VPS_NAME="Unknown"
    fi
    
    FORMATTED_NAME=$(echo "$VPS_NAME" | sed 's/ /%20/g')
    API_CHECK_URL="https://tuban.store/api/license/check?ip=$IP_ADD&name=$FORMATTED_NAME"
    
    # Inisialisasi variabel kosong
    LIC_EXP=""
    
    # Hit API dengan timeout 3 detik agar menu tidak hang
    API_RES=$(curl -sS --max-time 3 "$API_CHECK_URL" 2>/dev/null)
    
    if [ -n "$API_RES" ]; then
        # Ekstrak status boolean JSON dengan aman menggunakan jq
        IS_SUCCESS=$(echo "$API_RES" | jq -r '.success' 2>/dev/null)
        
        if [ "$IS_SUCCESS" == "true" ]; then
            LIC_EXP=$(echo "$API_RES" | jq -r '.data.expires_at' 2>/dev/null)
            # Simpan backup lokal jika dapet data
            if [ -n "$LIC_EXP" ] && [ "$LIC_EXP" != "null" ]; then
                echo "$LIC_EXP" > /usr/local/etc/srpcom/license_exp.txt
            fi
        elif [ "$IS_SUCCESS" == "false" ]; then
            MSG=$(echo "$API_RES" | jq -r '.message' 2>/dev/null)
            if [ -n "$MSG" ] && [ "$MSG" != "null" ]; then
                LIC_EXP="$MSG"
            else
                LIC_EXP="Lisensi Ditolak API"
            fi
            echo "EXPIRED" > /usr/local/etc/srpcom/license_exp.txt
        fi
    fi

    # Fallback ke txt lokal jika API timeout / format rusak (HTML error dari Cloudflare)
    if [ -z "$LIC_EXP" ] || [ "$LIC_EXP" == "null" ]; then
        LIC_EXP=$(cat /usr/local/etc/srpcom/license_exp.txt 2>/dev/null)
    fi

    # Bersihkan dari spasi enter (newline/whitespace) yang memicu error output
    LIC_EXP=$(echo "$LIC_EXP" | xargs)

    # Fallback terakhir jika string benar-benar kosong
    if [ -z "$LIC_EXP" ]; then 
        LIC_EXP="Tidak Diketahui"
    fi

    # Mencegah kotak (box menu) jebol jika teks terlalu panjang (Maks 19 Karakter)
    LIC_EXP="${LIC_EXP:0:19}"
    # ==========================================

    # Menghitung Total Akun Berdasarkan Protokol
    XRAY_C=$(jq '[.inbounds[] | select(.protocol=="vmess" or .protocol=="vless" or .protocol=="trojan") | .settings.clients | length] | add' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    SSH_C=$(wc -l < /usr/local/etc/srpcom/ssh_expiry.txt 2>/dev/null || echo 0)
    L2TP_C=$(wc -l < /usr/local/etc/srpcom/l2tp_expiry.txt 2>/dev/null || echo 0)

    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    printf "${CYAN}║ %-36s ║\n${NC}" "         SRPCOM AUTO SCRIPT"
    printf "${CYAN}║ %-36s ║\n${NC}" "    ${SCRIPT_VERSION:-v.1}"
    printf "${CYAN}║ %-36s ║\n${NC}" " Lisensi Aktif : $LIC_EXP"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    
    # Menyusun string informasi dan membatasi maksimal 40 karakter agar tidak wrap di HP
    os_str=" OS SYSTEM     : ${OS_SYS} ${BIT}"
    krnl_str=" KERNEL TYPE   : ${KRNL}"
    cpu_str=" CPU MODEL     : ${CPUMDL} (${CORE} core)"
    ram_str=" RAM           : ${T_RAM} Total / ${U_RAM} Used"
    dom_str=" DOMAIN        : ${DOMAIN}"
    ip_str=" IP ADDRESS    : ${IP_ADD}"
    isp_str=" ISP           : ${ISP_NAME}"

    echo "${os_str:0:40}"
    echo "${krnl_str:0:40}"
    echo "${cpu_str:0:40}"
    echo "${ram_str:0:40}"
    echo "${dom_str:0:40}"
    echo "${ip_str:0:40}"
    echo "${isp_str:0:40}"
    
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    printf "${CYAN}║ XRAY: %-5s| SSH: %-5s| L2TP: %-6s║\n${NC}" "${XRAY_C:-0}" "${SSH_C:-0}" "${L2TP_C:-0}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
}
