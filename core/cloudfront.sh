#!/bin/bash
# ==============================================================================
# cloudfront.sh — Modul Manajemen CloudFront Terisolasi (Xray WS/gRPC & SSH WS)
# ==============================================================================

load_cf_env() {
    source /usr/local/etc/srpcom/env.conf 2>/dev/null
    CF_DOMAIN="${CF_DOMAIN:-}"
    CF_BUG="${CF_BUG:-static.wetvinfo.com}"
    CF_QUOTA_GB="${CF_QUOTA_GB:-100}"
}

save_cf_env() {
    grep -vE '^(CF_DOMAIN|CF_BUG|CF_QUOTA_GB)=' /usr/local/etc/srpcom/env.conf > /tmp/env_cf.tmp 2>/dev/null || true
    echo "CF_DOMAIN=\"${CF_DOMAIN}\"" >> /tmp/env_cf.tmp
    echo "CF_BUG=\"${CF_BUG}\"" >> /tmp/env_cf.tmp
    echo "CF_QUOTA_GB=\"${CF_QUOTA_GB:-100}\"" >> /tmp/env_cf.tmp
    mv /tmp/env_cf.tmp /usr/local/etc/srpcom/env.conf
    systemctl restart xray-api srpcom-bot 2>/dev/null
}

_cf_vmess_b64() {
    local ps="$1" add="$2" host="$3" net="$4" path="$5" uuid="$6"
    local j="{\"v\":\"2\",\"ps\":\"${ps}\",\"add\":\"${add}\",\"port\":\"443\",\"id\":\"${uuid}\",\"aid\":\"0\",\"scy\":\"auto\",\"net\":\"${net}\",\"type\":\"none\",\"host\":\"${host}\",\"path\":\"${path}\",\"tls\":\"tls\",\"sni\":\"${host}\"}"
    echo "vmess://$(echo -n "$j" | jq -c . | base64 -w 0)"
}

print_cf_links_for_xray() {
    local prot="$1" user="$2" uuid="$3"
    load_cf_env
    [ -z "$CF_DOMAIN" ] && { echo "(CF_DOMAIN belum diset)"; return 0; }

    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "--- CLOUDFRONT ISOLATED CONFIG (${CF_DOMAIN}) ---"
    if [[ "$prot" == "vmess" ]]; then
        echo "LINK WS CF (Direct) : $(_cf_vmess_b64 "${user}_cf_ws" "$CF_DOMAIN" "$CF_DOMAIN" "ws" "/cf-vmess" "$uuid")"
        echo "LINK WS CF (Bug ${CF_BUG}) : $(_cf_vmess_b64 "${user}_cf_bug" "$CF_BUG" "$CF_DOMAIN" "ws" "/cf-vmess" "$uuid")"
        echo "LINK GRPC CF (Direct) : $(_cf_vmess_b64 "${user}_cf_grpc" "$CF_DOMAIN" "$CF_DOMAIN" "grpc" "cf-vmessgrpc" "$uuid")"
        echo "LINK GRPC CF (Bug ${CF_BUG}) : $(_cf_vmess_b64 "${user}_cf_grpc_bug" "$CF_BUG" "$CF_DOMAIN" "grpc" "cf-vmessgrpc" "$uuid")"
    elif [[ "$prot" == "vless" ]]; then
        echo "LINK WS CF (Direct) : vless://${uuid}@${CF_DOMAIN}:443?path=/cf-vless&security=tls&encryption=none&host=${CF_DOMAIN}&type=ws&sni=${CF_DOMAIN}#${user}_cf_ws"
        echo "LINK WS CF (Bug ${CF_BUG}) : vless://${uuid}@${CF_BUG}:443?path=/cf-vless&security=tls&encryption=none&host=${CF_DOMAIN}&type=ws&sni=${CF_DOMAIN}#${user}_cf_bug"
        echo "LINK GRPC CF (Direct) : vless://${uuid}@${CF_DOMAIN}:443?mode=gun&security=tls&encryption=none&host=${CF_DOMAIN}&type=grpc&serviceName=cf-vlessgrpc&sni=${CF_DOMAIN}#${user}_cf_grpc"
        echo "LINK GRPC CF (Bug ${CF_BUG}) : vless://${uuid}@${CF_BUG}:443?mode=gun&security=tls&encryption=none&host=${CF_DOMAIN}&type=grpc&serviceName=cf-vlessgrpc&sni=${CF_DOMAIN}#${user}_cf_grpc_bug"
    elif [[ "$prot" == "trojan" ]]; then
        echo "LINK WS CF (Direct) : trojan://${uuid}@${CF_DOMAIN}:443?path=/cf-trojan&security=tls&host=${CF_DOMAIN}&type=ws&sni=${CF_DOMAIN}#${user}_cf_ws"
        echo "LINK WS CF (Bug ${CF_BUG}) : trojan://${uuid}@${CF_BUG}:443?path=/cf-trojan&security=tls&host=${CF_DOMAIN}&type=ws&sni=${CF_DOMAIN}#${user}_cf_bug"
        echo "LINK GRPC CF (Direct) : trojan://${uuid}@${CF_DOMAIN}:443?mode=gun&security=tls&host=${CF_DOMAIN}&type=grpc&serviceName=cf-trojangrpc&sni=${CF_DOMAIN}#${user}_cf_grpc"
        echo "LINK GRPC CF (Bug ${CF_BUG}) : trojan://${uuid}@${CF_BUG}:443?mode=gun&security=tls&host=${CF_DOMAIN}&type=grpc&serviceName=cf-trojangrpc&sni=${CF_DOMAIN}#${user}_cf_grpc_bug"
    fi
}

build_cf_xray_block_tg() {
    local prot="$1" user="$2" uuid="$3"
    local base_prot="${prot%%_*}"
    load_cf_env
    [ -z "$CF_DOMAIN" ] && return 0

    local out="━━━━━━━━━━━━━━━━━━━━\n☁️ CLOUDFRONT : \`${CF_DOMAIN}\`\n🐞 Bug CF : \`${CF_BUG}\`\n"
    if [[ "$base_prot" == "vmess" ]]; then
        local l_ws_d=$(_cf_vmess_b64 "${user}_cf_ws" "$CF_DOMAIN" "$CF_DOMAIN" "ws" "/cf-vmess" "$uuid")
        local l_ws_b=$(_cf_vmess_b64 "${user}_cf_bug" "$CF_BUG" "$CF_DOMAIN" "ws" "/cf-vmess" "$uuid")
        local l_gr_d=$(_cf_vmess_b64 "${user}_cf_grpc" "$CF_DOMAIN" "$CF_DOMAIN" "grpc" "cf-vmessgrpc" "$uuid")
        local l_gr_b=$(_cf_vmess_b64 "${user}_cf_grpc_bug" "$CF_BUG" "$CF_DOMAIN" "grpc" "cf-vmessgrpc" "$uuid")
        out+="LINK WS CF : \`${l_ws_d}\`\nLINK WS CF BUG : \`${l_ws_b}\`\nLINK GRPC CF : \`${l_gr_d}\`\nLINK GRPC CF BUG : \`${l_gr_b}\`"
    elif [[ "$base_prot" == "vless" ]]; then
        out+="LINK WS CF : \`vless://${uuid}@${CF_DOMAIN}:443?path=/cf-vless&security=tls&encryption=none&host=${CF_DOMAIN}&type=ws&sni=${CF_DOMAIN}#${user}_cf_ws\`\n"
        out+="LINK WS CF BUG : \`vless://${uuid}@${CF_BUG}:443?path=/cf-vless&security=tls&encryption=none&host=${CF_DOMAIN}&type=ws&sni=${CF_DOMAIN}#${user}_cf_bug\`\n"
        out+="LINK GRPC CF : \`vless://${uuid}@${CF_DOMAIN}:443?mode=gun&security=tls&encryption=none&host=${CF_DOMAIN}&type=grpc&serviceName=cf-vlessgrpc&sni=${CF_DOMAIN}#${user}_cf_grpc\`\n"
        out+="LINK GRPC CF BUG : \`vless://${uuid}@${CF_BUG}:443?mode=gun&security=tls&encryption=none&host=${CF_DOMAIN}&type=grpc&serviceName=cf-vlessgrpc&sni=${CF_DOMAIN}#${user}_cf_grpc_bug\`"
    elif [[ "$base_prot" == "trojan" ]]; then
        out+="LINK WS CF : \`trojan://${uuid}@${CF_DOMAIN}:443?path=/cf-trojan&security=tls&host=${CF_DOMAIN}&type=ws&sni=${CF_DOMAIN}#${user}_cf_ws\`\n"
        out+="LINK WS CF BUG : \`trojan://${uuid}@${CF_BUG}:443?path=/cf-trojan&security=tls&host=${CF_DOMAIN}&type=ws&sni=${CF_DOMAIN}#${user}_cf_bug\`\n"
        out+="LINK GRPC CF : \`trojan://${uuid}@${CF_DOMAIN}:443?mode=gun&security=tls&host=${CF_DOMAIN}&type=grpc&serviceName=cf-trojangrpc&sni=${CF_DOMAIN}#${user}_cf_grpc\`\n"
        out+="LINK GRPC CF BUG : \`trojan://${uuid}@${CF_BUG}:443?mode=gun&security=tls&host=${CF_DOMAIN}&type=grpc&serviceName=cf-trojangrpc&sni=${CF_DOMAIN}#${user}_cf_grpc_bug\`"
    fi
    echo -e "$out"
}

_add_xray_cf_account() {
    local prot="$1"
    local is_trial="${2:-0}"
    load_cf_env

    clear
    echo "======================================"
    if [[ "$is_trial" == "1" ]]; then
        echo "   CREATE TRIAL CLOUDFRONT (${prot^^}) "
    else
        echo "  CREATE CLOUDFRONT XRAY/${prot^^}      "
    fi
    echo "======================================"

    local user="" masaaktif="" exp_date="" exp_time="" title_tag=""
    if [[ "$is_trial" == "1" ]]; then
        local rand_char=$(tr -dc 'a-z' < /dev/urandom | head -c 1)
        user="trialsrpcf-$(date +%H%M%S)${rand_char}"
        masaaktif="60 Minutes"
        exp_date=$(date -d "+60 minutes" +"%Y-%m-%d")
        exp_time=$(date -d "+60 minutes" +"%H:%M:%S")
        title_tag="TRIAL "
    else
        read -p "Username (x = Batal) : " user
        if [[ "$user" == "x" || "$user" == "X" || -z "$user" ]]; then return; fi
        local orig="$user" counter=2
        while grep -q "\"email\": \"$user\"" /usr/local/etc/xray/config.json; do
            user="${orig}${counter}"
            ((counter++))
        done
        if [[ "$orig" != "$user" ]]; then
            echo -e "\n\e[33m[INFO]\e[0m Username '$orig' sudah digunakan. Akun akan dibuat dengan nama: $user"
        fi
        read -p "Expired (Days) : " masaaktif
        if [[ "$masaaktif" == "0" || -z "$masaaktif" ]]; then
            exp_date="Lifetime"
            exp_time="-"
        else
            exp_date=$(date -d "$masaaktif days" +"%Y-%m-%d")
            exp_time=$(date -d "$masaaktif days" +"%H:%M:%S")
        fi
    fi

    local lim_ip=0 quota_gb="${CF_QUOTA_GB:-100}"
    local lim_ip_str="Unlimited" quota_lbl=""
    if [[ "$is_trial" == "1" ]]; then
        lim_ip=1
        quota_gb=1
        lim_ip_str="1 IP"
        quota_lbl="1 GB (Trial)"
    else
        if [[ "$quota_gb" =~ ^[0-9]+$ && "$quota_gb" -gt 0 ]]; then
            quota_lbl="${quota_gb} GB (Fixed CF)"
        else
            quota_gb=0
            quota_lbl="Unlimited"
        fi
    fi

    local uuid=$(uuidgen)
    echo "$user $exp_date $exp_time" >> /usr/local/etc/xray/expiry.txt
    mkdir -p /usr/local/etc/xray
    touch /usr/local/etc/xray/limit.txt
    sed -i "/^${user} /d" /usr/local/etc/xray/limit.txt 2>/dev/null || true
    echo "$user $lim_ip $quota_gb" >> /usr/local/etc/xray/limit.txt

    if [[ "$prot" == "vmess" ]]; then
        jq '(.inbounds[] | select(.protocol=="vmess" and .port >= 10010) | .settings.clients) += [{"id": "'"$uuid"'", "alterId": 0, "email": "'"$user"'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    elif [[ "$prot" == "vless" ]]; then
        jq '(.inbounds[] | select(.protocol=="vless" and .port >= 10010) | .settings.clients) += [{"id": "'"$uuid"'", "email": "'"$user"'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    elif [[ "$prot" == "trojan" ]]; then
        jq '(.inbounds[] | select(.protocol=="trojan" and .port >= 10010) | .settings.clients) += [{"password": "'"$uuid"'", "email": "'"$user"'"}]' /usr/local/etc/xray/config.json > /tmp/config.json
    fi

    if [ -s /tmp/config.json ]; then
        mv /tmp/config.json /usr/local/etc/xray/config.json
    fi
    systemctl restart xray
    [ -f "/usr/local/bin/srpcom/db_helper.sh" ] && /usr/local/bin/srpcom/db_helper.sh db_import_from_txt 2>/dev/null

    clear
    echo "Pembuatan akun CloudFront berhasil"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "❖ CLOUDFRONT XRAY/${prot^^} ${title_tag}❖"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Remarks   : ${user}"
    echo "UUID/Pass : ${uuid}"
    echo "CF Domain : ${CF_DOMAIN}"
    echo "Bug CF    : ${CF_BUG}"
    echo "Path WS   : /cf-${prot}"
    echo "gRPC Svc  : cf-${prot}grpc"
    echo "Limit IP  : ${lim_ip_str}"
    echo "LimitKuota: ${quota_lbl}"
    print_cf_links_for_xray "$prot" "$user" "$uuid"
    echo "━━━━━━━━━━━━━━━━━━━━"
    echo "Expired On : ${exp_date} ${exp_time} WIB"

    if declare -F send_telegram >/dev/null; then
        local cf_tg_block=$(build_cf_xray_block_tg "$prot" "$user" "$uuid")
        local msg_tg=$(echo -e "Pembuatan akun CloudFront berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ CLOUDFRONT XRAY/${prot^^} ${title_tag}❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nUUID/Pass : \`${uuid}\`\nPath WS : \`/cf-${prot}\`\ngRPC Svc : \`cf-${prot}grpc\`\nLimit IP : ${lim_ip_str}\nLimit Kuota : ${quota_lbl}\nExpired On : ${exp_date} ${exp_time} WIB\n${cf_tg_block}")
        send_telegram "$msg_tg"
        echo -e "\e[32m=> Detail akun CloudFront juga telah dikirim ke Telegram Admin.\e[0m"
    fi
    pause
}

create_xray_cloudfront() {
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║     CREATE XRAY CLOUDFRONT         ║"
        echo "╚════════════════════════════════════╝"
        echo " 1. VMESS CloudFront (WS + gRPC)"
        echo " 2. VLESS CloudFront (WS + gRPC)"
        echo " 3. TROJAN CloudFront (WS + gRPC)"
        echo " 4. TRIAL CloudFront (60 Minutes)"
        echo "--------------------------------------"
        echo " 0. Kembali"
        echo "======================================"
        read -p " Pilih opsi [0-4]: " opt
        case "$opt" in
            1) _add_xray_cf_account "vmess" 0 ;;
            2) _add_xray_cf_account "vless" 0 ;;
            3) _add_xray_cf_account "trojan" 0 ;;
            4)
                echo " Pilih Protokol Trial CF: 1) VMESS  2) VLESS  3) TROJAN"
                read -p " Pilihan [1-3]: " tp
                case "$tp" in
                    1) _add_xray_cf_account "vmess" 1 ;;
                    2) _add_xray_cf_account "vless" 1 ;;
                    3) _add_xray_cf_account "trojan" 1 ;;
                    *) echo "Pilihan tidak valid!"; sleep 1 ;;
                esac
                ;;
            0|x|X) break ;;
            *) echo "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

cf_status_info() {
    load_cf_env
    clear
    echo "======================================"
    echo "      STATUS & INFO CLOUDFRONT        "
    echo "======================================"
    local q_disp="Unlimited"
    if [[ "$CF_QUOTA_GB" =~ ^[0-9]+$ && "$CF_QUOTA_GB" -gt 0 ]]; then q_disp="${CF_QUOTA_GB} GB (Fixed)"; fi
    echo " Origin Domain   : ${DOMAIN}"
    echo " CloudFront Host : ${CF_DOMAIN:-Belum diset}"
    echo " Bug CF Default  : ${CF_BUG}"
    echo " Kuota Fixed CF  : ${q_disp}"
    echo "--------------------------------------"
    echo " Service Caddy   : $(systemctl is-active caddy 2>/dev/null)"
    echo " Service Xray    : $(systemctl is-active xray 2>/dev/null)"
    echo " Service SSH-WS  : $(systemctl is-active ssh-ws 2>/dev/null)"
    echo "--------------------------------------"
    echo " Endpoint CloudFront TERISOLASI:"
    echo "  • VMess WS   : /cf-vmess     (10011)"
    echo "  • VLESS WS   : /cf-vless     (10012)"
    echo "  • Trojan WS  : /cf-trojan    (10013)"
    echo "  • VMess gRPC : cf-vmessgrpc  (10014)"
    echo "  • VLESS gRPC : cf-vlessgrpc  (10015)"
    echo "  • Trojan gRPC: cf-trojangrpc (10016)"
    echo "  • SSH WS     : /sshws        (10004)"
    echo " Jalur Standar (/vmessws,/vlessws,/trojanws) diblokir 403 dari CloudFront."
    echo "======================================"
    pause
}

cf_change_domain() {
    load_cf_env
    clear
    echo "======================================"
    echo "    UBAH DOMAIN & BUG CLOUDFRONT      "
    echo "======================================"
    echo " CF Domain Saat Ini : ${CF_DOMAIN:-Kosong}"
    echo " Bug CF Saat Ini    : ${CF_BUG}"
    echo "--------------------------------------"
    read -p " Domain CloudFront Baru (Enter = tetap): " new_cf
    read -p " Bug CloudFront Baru    (Enter = tetap): " new_bug

    [ -n "$new_cf" ] && CF_DOMAIN="$new_cf"
    [ -n "$new_bug" ] && CF_BUG="$new_bug"

    save_cf_env
    echo -e "\n\e[32m=> Pengaturan CloudFront berhasil disimpan!\e[0m"
    echo " CF_DOMAIN   : ${CF_DOMAIN}"
    echo " CF_BUG      : ${CF_BUG}"
    echo " CF_QUOTA_GB : ${CF_QUOTA_GB}"
    sleep 2
}

cf_set_quota() {
    load_cf_env
    clear
    local curr_disp="Unlimited (0)"
    if [[ "$CF_QUOTA_GB" =~ ^[0-9]+$ && "$CF_QUOTA_GB" -gt 0 ]]; then
        curr_disp="${CF_QUOTA_GB} GB (Fixed)"
    fi
    local autolock_st="\e[31m[ OFF ]\e[0m"
    if grep -q "autokill.sh" /etc/cron.d/srpcom_autokill 2>/dev/null; then
        autolock_st="\e[32m[ ON ]\e[0m"
    fi
    echo "======================================"
    echo "   SETTING KUOTA FIXED CLOUDFRONT     "
    echo "======================================"
    echo " Kuota Fixed Saat Ini : ${curr_disp}"
    echo -e " Status Auto-Lock     : ${autolock_st}"
    echo "--------------------------------------"
    echo " Catatan: Setiap pembuatan akun CloudFront baru"
    echo " akan otomatis memakai batas kuota ini (tanpa tanya input)."
    if ! grep -q "autokill.sh" /etc/cron.d/srpcom_autokill 2>/dev/null; then
        echo -e " \e[33m[!] Auto-Lock masih OFF. Aktifkan di Menu Auto-Lock agar limit kuota dijalankan otomatis.\e[0m"
    fi
    echo "======================================"
    read -p " Kuota Fixed per Akun CloudFront (GB, 0=Unlimited, x=Batal) : " new_q
    if [[ "$new_q" == "x" || "$new_q" == "X" || -z "$new_q" ]]; then return; fi
    if ! [[ "$new_q" =~ ^[0-9]+$ ]]; then
        echo -e "\n\e[31m[ERROR]\e[0m Input harus berupa angka bulat >= 0!"
        sleep 2
        return
    fi
    CF_QUOTA_GB="$new_q"
    save_cf_env
    if [ "$CF_QUOTA_GB" -gt 0 ]; then
        echo -e "\n\e[32m=> Berhasil! Kuota akun CloudFront dikunci tetap ${CF_QUOTA_GB} GB.\e[0m"
    else
        echo -e "\n\e[32m=> Berhasil! Kuota akun CloudFront diset Unlimited (0).\e[0m"
    fi
    sleep 2
}

menu_cf_settings() {
    while true; do
        load_cf_env
        clear
        local q_disp="Unlimited (0)"
        if [[ "$CF_QUOTA_GB" =~ ^[0-9]+$ && "$CF_QUOTA_GB" -gt 0 ]]; then q_disp="${CF_QUOTA_GB} GB (Fixed)"; fi
        local autolock_st="\e[31m[ OFF ]\e[0m"
        if grep -q "autokill.sh" /etc/cron.d/srpcom_autokill 2>/dev/null; then autolock_st="\e[32m[ ON ]\e[0m"; fi
        echo "╔════════════════════════════════════╗"
        echo "║        CLOUDFRONT SETTINGS         ║"
        echo "╚════════════════════════════════════╝"
        echo " CF Domain : ${CF_DOMAIN:-Belum diset}"
        echo " Bug CF    : ${CF_BUG}"
        echo " Kuota CF  : ${q_disp}"
        echo -e " Auto-Lock : ${autolock_st}"
        echo "======================================"
        echo " 1. Atur Batas Kuota Fixed CloudFront (GB)"
        echo " 2. Ubah Domain & Bug CloudFront"
        echo " 3. Info & Status CloudFront"
        echo " 4. Setting Auto-Lock / Auto-Kill"
        echo "--------------------------------------"
        echo " 0/x. Kembali"
        echo "======================================"
        read -p " Pilih opsi [0-4 or x]: " opt
        case "$opt" in
            1) cf_set_quota ;;
            2) cf_change_domain ;;
            3) cf_status_info ;;
            4) if declare -F menu_autokill >/dev/null; then menu_autokill; else echo "menu_autokill tidak tersedia."; sleep 1; fi ;;
            0|x|X) break ;;
            *) echo "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

cf_generate_xray() {
    load_cf_env
    clear
    echo "======================================"
    echo "   GENERATE LINK AKUN CLOUDFRONT      "
    echo "======================================"
    echo " 1. VMESS CloudFront"
    echo " 2. VLESS CloudFront"
    echo " 3. TROJAN CloudFront"
    echo " 0. Kembali"
    echo "======================================"
    read -p " Pilih protokol [0-3]: " p_opt
    local prot=""
    case "$p_opt" in
        1) prot="vmess" ;;
        2) prot="vless" ;;
        3) prot="trojan" ;;
        0|x|X) return ;;
        *) echo "Pilihan tidak valid!"; sleep 1; return ;;
    esac

    mapfile -t users < <(jq -r '.inbounds[] | select(.protocol=="'"$prot"'" and .port >= 10010) | .settings.clients[]?.email' /usr/local/etc/xray/config.json 2>/dev/null | sort -u)
    if [ ${#users[@]} -eq 0 ] || [ -z "${users[0]}" ]; then
        echo -e "\nBelum ada akun CloudFront pada protokol ${prot^^}."
        echo "Buat akun lewat Menu 1 (XRAY) -> 2. Create XRAY WS CloudFront Account."
        pause; return
    fi

    echo "--------------------------------------"
    for i in "${!users[@]}"; do
        echo " $((i+1)). ${users[$i]}"
    done
    echo " 0. Kembali"
    echo "======================================"
    read -p " Pilih nomor akun [1-${#users[@]} or 0]: " u_opt
    [[ "$u_opt" == "0" || -z "$u_opt" ]] && return

    if [[ "$u_opt" -gt 0 && "$u_opt" -le "${#users[@]}" ]]; then
        local user="${users[$((u_opt-1))]}"
        local uuid=""
        if [[ "$prot" == "trojan" ]]; then
            uuid=$(jq -r '.inbounds[] | select(.protocol=="trojan" and .port >= 10010) | .settings.clients[] | select(.email=="'"$user"'") | .password' /usr/local/etc/xray/config.json | head -n1)
        else
            uuid=$(jq -r '.inbounds[] | select(.protocol=="'"$prot"'" and .port >= 10010) | .settings.clients[] | select(.email=="'"$user"'") | .id' /usr/local/etc/xray/config.json | head -n1)
        fi
        local exp_date=$(grep "^${user} " /usr/local/etc/xray/expiry.txt 2>/dev/null | cut -d' ' -f2-)
        [ -z "$exp_date" ] && exp_date="Lifetime"

        clear
        echo "======================================"
        echo "  CLOUDFRONT XRAY/${prot^^} - ${user}"
        echo "======================================"
        echo " Remarks   : ${user}"
        echo " UUID/Pass : ${uuid}"
        echo " CF Domain : ${CF_DOMAIN}"
        echo " Bug CF    : ${CF_BUG}"
        echo " Expired   : ${exp_date}"
        print_cf_links_for_xray "$prot" "$user" "$uuid"
        echo "======================================"
        if declare -F send_telegram >/dev/null; then
            local cf_tg_block=$(build_cf_xray_block_tg "$prot" "$user" "$uuid")
            local msg_tg=$(echo -e "Generate Akun CloudFront Berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ CLOUDFRONT XRAY/${prot^^} ❖\n━━━━━━━━━━━━━━━━━━━━\nRemarks : \`${user}\`\nUUID/Pass : \`${uuid}\`\nExpired On : ${exp_date} WIB\n${cf_tg_block}")
            send_telegram "$msg_tg"
            echo -e "\e[32m=> Hasil link CloudFront juga dikirim ke Telegram Admin.\e[0m"
        fi
        pause
    else
        echo "Pilihan tidak valid!"; sleep 1
    fi
}

cf_generate_ssh() {
    load_cf_env
    clear
    echo "======================================"
    echo "   GENERATE CONFIG SSH WS CLOUDFRONT  "
    echo "======================================"
    if [ ! -f "/usr/local/etc/srpcom/ssh_expiry.txt" ] || [ ! -s "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
        echo "Belum ada akun SSH terdaftar."
        pause; return
    fi
    mapfile -t users < <(awk '{print $1}' /usr/local/etc/srpcom/ssh_expiry.txt)
    for i in "${!users[@]}"; do
        echo " $((i+1)). ${users[$i]}"
    done
    echo " 0. Kembali"
    echo "======================================"
    read -p " Pilih nomor akun [1-${#users[@]} or 0]: " u_opt
    [[ "$u_opt" == "0" || -z "$u_opt" ]] && return

    if [[ "$u_opt" -gt 0 && "$u_opt" -le "${#users[@]}" ]]; then
        local user="${users[$((u_opt-1))]}"
        local row=$(grep "^${user} " /usr/local/etc/srpcom/ssh_expiry.txt | head -n1)
        local pw=$(echo "$row" | awk '{print $2}')
        local dt=$(echo "$row" | awk '{print $3" "$4}')

        clear
        echo "======================================"
        echo "     SSH WS CLOUDFRONT ACCOUNT        "
        echo "======================================"
        echo " Server/Bug   : ${CF_BUG}"
        echo " Host / SNI   : ${CF_DOMAIN}"
        echo " Port TLS     : 443"
        echo " Port NTLS    : 80"
        echo " Path WS      : /sshws"
        echo " Username     : ${user}"
        echo " Password     : ${pw}"
        echo " Expired      : ${dt} WIB"
        echo "--------------------------------------"
        echo " Payload SSH WS CloudFront:"
        echo " GET /sshws HTTP/1.1[crlf]Host: ${CF_DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]"
        echo "======================================"
        if declare -F send_telegram >/dev/null; then
            local payload_cf="GET /sshws HTTP/1.1[crlf]Host: ${CF_DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf][crlf]"
            local msg_tg=$(echo -e "Generate Config SSH CloudFront Berhasil\n\n━━━━━━━━━━━━━━━━━━━━\n❖ SSH WS CLOUDFRONT ❖\n━━━━━━━━━━━━━━━━━━━━\nServer/Bug : \`${CF_BUG}\`\nHost / SNI : \`${CF_DOMAIN}\`\nPort TLS : 443\nPort NTLS : 80\nPath WS : \`/sshws\`\nUsername : \`${user}\`\nPassword : \`${pw}\`\nExpired : ${dt} WIB\n━━━━━━━━━━━━━━━━━━━━\nPayload SSH WS CloudFront:\n\`${payload_cf}\`")
            send_telegram "$msg_tg"
            echo -e "\e[32m=> Config SSH CloudFront juga dikirim ke Telegram Admin.\e[0m"
        fi
        pause
    else
        echo "Pilihan tidak valid!"; sleep 1
    fi
}

menu_cloudfront() {
    load_cf_env
    while true; do
        clear
        echo "╔════════════════════════════════════╗"
        echo "║     MENU CLOUDFRONT (VPN & SSH)    ║"
        echo "╚════════════════════════════════════╝"
        local q_disp="Unlimited"
        if [[ "$CF_QUOTA_GB" =~ ^[0-9]+$ && "$CF_QUOTA_GB" -gt 0 ]]; then q_disp="${CF_QUOTA_GB} GB (Fixed)"; fi
        echo " CF Domain : ${CF_DOMAIN:-Belum diset}"
        echo " Bug CF    : ${CF_BUG}"
        echo " Kuota CF  : ${q_disp}"
        echo " Origin    : ${DOMAIN}"
        echo "======================================"
        echo " 1. Info & Status CloudFront"
        echo " 2. Set / Ubah Domain CloudFront & Bug"
        echo " 3. Generate Link CF Akun Xray (CF)"
        echo " 4. Generate Config CF Akun SSH (Ada)"
        echo " 5. Buat Akun Xray CloudFront Baru"
        echo " 6. CloudFront Settings (Kuota/Domain/Bug)"
        echo "--------------------------------------"
        echo " 0/x. Kembali ke Menu Utama"
        echo "======================================"
        read -p " Pilih opsi [0-6 or x]: " opt
        case "$opt" in
            1) cf_status_info ;;
            2) cf_change_domain ;;
            3) cf_generate_xray ;;
            4) cf_generate_ssh ;;
            5) create_xray_cloudfront ;;
            6) menu_cf_settings ;;
            0|x|X) break ;;
            *) echo "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}
