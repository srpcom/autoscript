#!/bin/bash
# ==========================================
# utils.sh
# MODULE: UTILITIES
# Berisi fungsi pembantu, pewarnaan, dan informasi OS
# ==========================================

# Memuat Environment Global (Domain & IP)
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
    ISP_NAME=$(curl -sS --max-time 3 ipinfo.io/org | cut -d' ' -f2-)
    REG=$(curl -sS --max-time 3 ipinfo.io/city)
    TZ=$(cat /etc/timezone)

    # Menghitung Total Akun Berdasarkan Protokol
    XRAY_C=$(jq '[.inbounds[] | select(.protocol=="vmess" or .protocol=="vless" or .protocol=="trojan") | .settings.clients | length] | add' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    SSH_C=$(wc -l < /usr/local/etc/srpcom/ssh_expiry.txt 2>/dev/null || echo 0)
    L2TP_C=$(wc -l < /usr/local/etc/srpcom/l2tp_expiry.txt 2>/dev/null || echo 0)

    clear
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    printf "${CYAN}║ %-36s ║\n${NC}" "         SRPCOM AUTO SCRIPT"
    printf "${CYAN}║ %-36s ║\n${NC}" "    ${SCRIPT_VERSION:-v.1}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
    echo " OS SYSTEM     : ${OS_SYS} ${BIT}"
    echo " KERNEL TYPE   : ${KRNL}"
    echo " CPU MODEL     : ${CPUMDL} (${CORE} core)"
    echo " RAM           : ${T_RAM} Total / ${U_RAM} Used"
    echo " DOMAIN        : ${DOMAIN}"
    echo " IP ADDRESS    : ${IP_ADD}"
    echo " ISP           : ${ISP_NAME}"
    echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
    printf "${CYAN}║ XRAY: %-5s| SSH: %-5s| L2TP: %-6s║\n${NC}" "${XRAY_C:-0}" "${SSH_C:-0}" "${L2TP_C:-0}"
    echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"
}
