# ... existing code ...
    # Menghitung Total Akun Berdasarkan Protokol
    XRAY_C=$(jq '[.inbounds[] | select(.protocol=="vmess" or .protocol=="vless" or .protocol=="trojan") | .settings.clients | length] | add' /usr/local/etc/xray/config.json 2>/dev/null || echo 0)
    SSH_C=$(wc -l < /usr/local/etc/srpcom/ssh_expiry.txt 2>/dev/null || echo 0)
    L2TP_C=$(wc -l < /usr/local/etc/srpcom/l2tp_expiry.txt 2>/dev/null || echo 0)

    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║ %-52s ║\n${NC}" "SRPCOM AUTO SCRIPT ${SCRIPT_VERSION:-v.1}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo " OS SYSTEM     : ${OS_SYS} ${BIT}"
    echo " KERNEL TYPE   : ${KRNL}"
    echo " CPU MODEL     : ${CPUMDL} (${CORE} core)"
    echo " RAM           : ${T_RAM} Total / ${U_RAM} Used"
    echo " DOMAIN        : ${DOMAIN}"
    echo " IP ADDRESS    : ${IP_ADD}"
    echo " ISP           : ${ISP_NAME}"
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║ XRAY : %-10s| SSH : %-10s| L2TP : %-9s║\n${NC}" "${XRAY_C:-0}" "${SSH_C:-0}" "${L2TP_C:-0}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
}
