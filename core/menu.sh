#!/bin/bash
# ==========================================
# menu.sh
# MODULE: MAIN MENU (ROUTER)
# Menampilkan antarmuka CLI utama dan perutean menu
# ==========================================

source /usr/local/etc/srpcom/env.conf
source /usr/local/bin/srpcom/utils.sh
source /usr/local/bin/srpcom/telegram.sh
source /usr/local/bin/srpcom/xray.sh
source /usr/local/bin/srpcom/l2tp.sh
source /usr/local/bin/srpcom/ssh.sh
source /usr/local/bin/srpcom/monitor.sh

GITHUB_RAW="https://raw.githubusercontent.com/syamsul18782/xray2026/main"

# ==========================================
# FUNGSI PEMBANGUNAN ULANG CADDYFILE
# ==========================================
rebuild_caddyfile() {
    local main_domain="$DOMAIN"
    local domains_string="http://$main_domain, https://$main_domain"
    
    # Menambahkan support default untuk support.zoom.us
    domains_string="$domains_string, http://support.zoom.us.$main_domain, https://support.zoom.us.$main_domain"
    
    # Membaca extra domains jika ada (Ditambahkan dari Menu 10 atau hasil Restore)
    if [ -f "/usr/local/etc/srpcom/extra_domains.txt" ]; then
        while read -r ext_dom; do
            if [ -n "$ext_dom" ]; then
                domains_string="$domains_string, http://$ext_dom, https://$ext_dom"
            fi
        done < /usr/local/etc/srpcom/extra_domains.txt
    fi

    cat > /etc/caddy/Caddyfile << EOF
$domains_string {
    handle /user_legend/* {
        reverse_proxy localhost:5000
    }
    handle /ovpn/* {
        root * /usr/local/etc/srpcom
        file_server
    }
    handle / {
        respond "Server is running normally." 200
    }
    handle /vmessws* {
        reverse_proxy localhost:10001
    }
    handle /vlessws* {
        reverse_proxy localhost:10002
    }
    handle /trojanws* {
        reverse_proxy localhost:10003
    }
    handle /sshws* {
        reverse_proxy localhost:10004
    }
}
EOF
    systemctl restart caddy
}

menu_update() {
    while true; do
        clear
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║               UPDATE SCRIPT (LIVE UPDATE)              ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo " [1]  Update Modul Utama (menu.sh)"
        echo " [2]  Update Modul Utilitas (utils.sh)"
        echo " [3]  Update Modul Xray (xray.sh)"
        echo " [4]  Update Modul SSH & OVPN (ssh.sh)"
        echo " [5]  Update Modul L2TP (l2tp.sh)"
        echo " [6]  Update Modul Monitoring (monitor.sh)"
        echo " [7]  Update Fitur Auto (autokill.sh & auto_expired.sh)"
        echo " [8]  Update API Backend & Bot Telegram (configs/*.py)"
        echo " [9]  Update SEMUA Modul (ALL IN ONE)"
        echo " [10] Update Daftar Extra Domain (Bug SNI) dari GitHub"
        echo "---------------------------------------------------------"
        echo " [0/x] Kembali ke Menu Utama"
        echo "========================================================="
        read -p " Pilih opsi [0-10 or x]: " opt
        
        case $opt in
            1) 
                echo -e "\n=> Mengunduh menu.sh..."
                wget -q -O /usr/local/bin/srpcom/menu.sh "$GITHUB_RAW/core/menu.sh"
                chmod +x /usr/local/bin/srpcom/menu.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul Utama diperbarui!"; sleep 1.5; exec menu ;;
            2) 
                echo -e "\n=> Mengunduh utils.sh..."
                wget -q -O /usr/local/bin/srpcom/utils.sh "$GITHUB_RAW/core/utils.sh"
                chmod +x /usr/local/bin/srpcom/utils.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul Utilitas diperbarui!"; sleep 1.5 ;;
            3) 
                echo -e "\n=> Mengunduh xray.sh..."
                wget -q -O /usr/local/bin/srpcom/xray.sh "$GITHUB_RAW/core/xray.sh"
                chmod +x /usr/local/bin/srpcom/xray.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul Xray diperbarui!"; sleep 1.5 ;;
            4) 
                echo -e "\n=> Mengunduh ssh.sh..."
                wget -q -O /usr/local/bin/srpcom/ssh.sh "$GITHUB_RAW/core/ssh.sh"
                chmod +x /usr/local/bin/srpcom/ssh.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul SSH diperbarui!"; sleep 1.5 ;;
            5) 
                echo -e "\n=> Mengunduh l2tp.sh..."
                wget -q -O /usr/local/bin/srpcom/l2tp.sh "$GITHUB_RAW/core/l2tp.sh"
                chmod +x /usr/local/bin/srpcom/l2tp.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul L2TP diperbarui!"; sleep 1.5 ;;
            6) 
                echo -e "\n=> Mengunduh monitor.sh..."
                wget -q -O /usr/local/bin/srpcom/monitor.sh "$GITHUB_RAW/core/monitor.sh"
                chmod +x /usr/local/bin/srpcom/monitor.sh
                echo -e "\e[32m[SUCCESS]\e[0m Modul Monitoring diperbarui!"; sleep 1.5 ;;
            7) 
                echo -e "\n=> Mengunduh autokill.sh & auto_expired.sh..."
                wget -q -O /usr/local/bin/srpcom/autokill.sh "$GITHUB_RAW/core/autokill.sh"
                wget -q -O /usr/local/bin/srpcom/auto_expired.sh "$GITHUB_RAW/core/auto_expired.sh"
                chmod +x /usr/local/bin/srpcom/autokill.sh /usr/local/bin/srpcom/auto_expired.sh
                echo -e "\e[32m[SUCCESS]\e[0m Fitur Auto diperbarui!"; sleep 1.5 ;;
            8) 
                echo -e "\n=> Mengunduh API Backend & Bot Telegram..."
                wget -q -O /usr/local/bin/xray-api.py "$GITHUB_RAW/configs/xray-api.py"
                wget -q -O /usr/local/bin/bot-admin.py "$GITHUB_RAW/configs/bot-admin.py"
                chmod +x /usr/local/bin/xray-api.py /usr/local/bin/bot-admin.py
                systemctl daemon-reload
                systemctl restart xray-api srpcom-bot
                echo -e "\e[32m[SUCCESS]\e[0m API & Bot diperbarui dan di-restart!"; sleep 1.5 ;;
            9) 
                echo -e "\n=> Mengunduh SEMUA modul sistem..."
                wget -q -O /usr/local/bin/srpcom/utils.sh "$GITHUB_RAW/core/utils.sh"
                wget -q -O /usr/local/bin/srpcom/telegram.sh "$GITHUB_RAW/core/telegram.sh"
                wget -q -O /usr/local/bin/srpcom/xray.sh "$GITHUB_RAW/core/xray.sh"
                wget -q -O /usr/local/bin/srpcom/l2tp.sh "$GITHUB_RAW/core/l2tp.sh"
                wget -q -O /usr/local/bin/srpcom/ssh.sh "$GITHUB_RAW/core/ssh.sh"
                wget -q -O /usr/local/bin/srpcom/monitor.sh "$GITHUB_RAW/core/monitor.sh"
                wget -q -O /usr/local/bin/srpcom/autokill.sh "$GITHUB_RAW/core/autokill.sh"
                wget -q -O /usr/local/bin/srpcom/auto_expired.sh "$GITHUB_RAW/core/auto_expired.sh"
                wget -q -O /usr/local/bin/xray-api.py "$GITHUB_RAW/configs/xray-api.py"
                wget -q -O /usr/local/bin/bot-admin.py "$GITHUB_RAW/configs/bot-admin.py"
                chmod +x /usr/local/bin/srpcom/*.sh /usr/local/bin/xray-api.py /usr/local/bin/bot-admin.py
                systemctl daemon-reload
                systemctl restart xray-api srpcom-bot
                
                # Merge Extra Domains
                wget -q -O /tmp/new_domains.txt "$GITHUB_RAW/core/extra_domains.txt"
                if [ -s /tmp/new_domains.txt ]; then
                    touch /usr/local/etc/srpcom/extra_domains.txt
                    cat /usr/local/etc/srpcom/extra_domains.txt /tmp/new_domains.txt | sort -u | grep -v '^$' > /tmp/merged_domains.txt
                    mv /tmp/merged_domains.txt /usr/local/etc/srpcom/extra_domains.txt
                    rm -f /tmp/new_domains.txt
                    rebuild_caddyfile
                fi
                
                # Update menu paling akhir agar tidak memutus proses, lalu exec ulang
                wget -q -O /usr/local/bin/srpcom/menu.sh "$GITHUB_RAW/core/menu.sh"
                chmod +x /usr/local/bin/srpcom/menu.sh
                echo -e "\e[32m[SUCCESS]\e[0m Seluruh sistem berhasil diperbarui dari GitHub!"; sleep 2; exec menu ;;
            10)
                import_github_domain
                ;;
            0|x|X) exec menu ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_bot_admin() {
    while true; do
        clear
        echo "======================================"
        echo "     SETTING TELEGRAM ADMIN BOT       "
        echo "======================================"
        bot_token=$(grep "^BOT_TOKEN=" /usr/local/etc/xray/bot_admin.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        admin_id=$(grep "^ADMIN_ID=" /usr/local/etc/xray/bot_admin.conf 2>/dev/null | cut -d'=' -f2 | tr -d '"')
        
        echo "Status Service :"
        if systemctl is-active --quiet srpcom-bot; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ OFF / STANDBY ]\e[0m"; fi
        echo "Current BOT_TOKEN : ${bot_token:-Belum disetting}"
        echo "Current ADMIN_ID  : ${admin_id:-Belum disetting}"
        echo "======================================"
        echo "1. Mulai / Restart Bot Admin"
        echo "2. Ubah Token & ID Bot"
        echo "3. Hentikan Bot (Disable)"
        echo "0/x. Kembali ke Settings"
        echo "======================================"
        read -p "Pilih opsi [0-3 or x]: " opt
        case $opt in
            1)
                if [[ -n "$bot_token" && -n "$admin_id" ]]; then
                    systemctl restart srpcom-bot
                    echo -e "\n\e[32m=> Bot Admin berhasil dijalankan!\e[0m"; sleep 2
                else
                    echo -e "\n\e[31m=> Token atau ID belum disetting! Pilih opsi 2.\e[0m"; sleep 2
                fi
                ;;
            2)
                read -p "Masukkan TOKEN BOT ADMIN : " new_token
                read -p "Masukkan CHAT ID ADMIN   : " new_id
                if [[ -n "$new_token" && -n "$new_id" ]]; then
                    cat > /usr/local/etc/xray/bot_admin.conf << EOF
BOT_TOKEN="$new_token"
ADMIN_ID="$new_id"
EOF
                    systemctl restart srpcom-bot
                    echo -e "\n\e[32m=> Bot Admin berhasil disetting dan dijalankan!\e[0m"; sleep 2
                else
                    echo -e "\n=> Token atau ID tidak boleh kosong!"; sleep 2
                fi
                ;;
            3)
                systemctl stop srpcom-bot
                echo -e "\n=> Bot Admin berhasil dihentikan!"; sleep 2
                ;;
            0) break ;;
            x|X) exec menu ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_autokill() {
    while true; do
        clear
        status_cron=$(grep "autokill.sh" /etc/cron.d/srpcom_autokill 2>/dev/null)
        if [ -n "$status_cron" ]; then st="\e[32m[ ON ]\e[0m"; else st="\e[31m[ OFF ]\e[0m"; fi
        
        echo "======================================"
        echo "    AUTO KILL & LIMIT SETTINGS        "
        echo "======================================"
        echo -e "Status Daemon (3 Menit) : $st"
        echo "======================================"
        echo "Fitur ini akan mengecek log Xray dan"
        echo "SSH secara otomatis di background."
        echo "Jika ada akun melebihi Limit IP atau"
        echo "Kuota, akun akan dikunci (Locked) dan"
        echo "Bot Telegram akan mengirim notifikasi."
        echo "======================================"
        echo "1. Turn ON Auto Kill Daemon"
        echo "2. Turn OFF Auto Kill Daemon"
        echo "0/x. Back to Settings"
        echo "======================================"
        read -p "Select Option [0-2 or x]: " opt
        case $opt in
            1) 
                echo "*/3 * * * * root /usr/local/bin/srpcom/autokill.sh run_kill >/dev/null 2>&1" > /etc/cron.d/srpcom_autokill
                systemctl restart cron
                echo -e "\n=> Auto Kill Daemon BERHASIL DIAKTIFKAN!"; sleep 2 ;;
            2) 
                rm -f /etc/cron.d/srpcom_autokill
                systemctl restart cron
                echo -e "\n=> Auto Kill Daemon DIMATIKAN!"; sleep 2 ;;
            0) break ;;
            x|X) exec menu ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_auto_expired() {
    while true; do
        clear
        status_cron=$(grep "auto_expired.sh" /etc/cron.d/auto_expired 2>/dev/null)
        if [ -n "$status_cron" ]; then st="\e[32m[ ON ]\e[0m"; else st="\e[31m[ OFF ]\e[0m"; fi
        
        echo "======================================"
        echo "      AUTO EXPIRED SETTINGS           "
        echo "======================================"
        echo -e "Status Daemon (Tiap 1 Jam) : $st"
        echo "======================================"
        echo "Fitur ini akan mengecek dan menghapus"
        echo "akun VPN yang masa aktifnya sudah habis"
        echo "secara otomatis setiap jam."
        echo "======================================"
        echo "1. Turn ON Auto Expired Daemon"
        echo "2. Turn OFF Auto Expired Daemon"
        echo "0/x. Back to Settings"
        echo "======================================"
        read -p "Select Option [0-2 or x]: " opt
        case $opt in
            1) 
                echo "0 * * * * root /usr/local/bin/srpcom/auto_expired.sh >/dev/null 2>&1" > /etc/cron.d/auto_expired
                systemctl restart cron
                echo -e "\n=> Auto Expired Daemon BERHASIL DIAKTIFKAN!"; sleep 2 ;;
            2) 
                rm -f /etc/cron.d/auto_expired
                systemctl restart cron
                echo -e "\n=> Auto Expired Daemon DIMATIKAN!"; sleep 2 ;;
            0) break ;;
            x|X) exec menu ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

change_domain() {
    clear
    echo "======================================"
    echo "          GANTI DOMAIN VPS            "
    echo "======================================"
    echo "Domain saat ini : $DOMAIN"
    echo "IP VPS          : $IP_ADD"
    echo "======================================"
    echo "PENTING: Pastikan A Record DNS domain baru"
    echo "sudah mengarah ke IP VPS ini (DNS Only)!"
    echo "======================================"
    read -p "Masukkan Domain Baru (tekan 'x' untuk batal): " new_domain
    
    if [[ "$new_domain" == "x" || "$new_domain" == "X" || -z "$new_domain" ]]; then
        return
    fi

    echo -e "\nMemeriksa resolusi DNS untuk $new_domain..."
    domain_ip=$(getent ahostsv4 "$new_domain" | awk '{ print $1 }' | head -n 1)
    
    if [[ "$domain_ip" != "$IP_ADD" ]]; then
        echo -e "\n\e[31m[ERROR]\e[0m Domain $new_domain belum mengarah ke IP $IP_ADD!"
        echo "IP dari DNS saat ini: ${domain_ip:-Kosong/Tidak Ditemukan}"
        echo "Silakan update DNS Anda (Matikan Proxy/Cloudflare Orange Cloud)"
        echo "lalu tunggu 1-2 menit dan coba lagi."
        sleep 4
        return
    fi

    echo -e "\n=> Memperbarui konfigurasi domain..."
    sed -i "s/^DOMAIN=.*/DOMAIN=\"$new_domain\"/g" /usr/local/etc/srpcom/env.conf
    source /usr/local/etc/srpcom/env.conf

    # Membangun ulang Caddyfile berdasarkan domain baru dan domain tambahan
    rebuild_caddyfile

    # Regenerate OVPN Client Configs with new Domain
    CA_CERT=$(cat /etc/openvpn/server/keys/ca.crt 2>/dev/null)
    TA_CERT=$(cat /etc/openvpn/server/keys/ta.key 2>/dev/null)
    
    cat > /usr/local/etc/srpcom/ovpn/udp.ovpn << EOF
client
dev tun
proto udp
remote $DOMAIN 2200
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth-user-pass
key-direction 1
<ca>
$CA_CERT
</ca>
<tls-auth>
$TA_CERT
</tls-auth>
EOF

    cat > /usr/local/etc/srpcom/ovpn/tcp.ovpn << EOF
client
dev tun
proto tcp
remote $DOMAIN 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
auth-user-pass
key-direction 1
<ca>
$CA_CERT
</ca>
<tls-auth>
$TA_CERT
</tls-auth>
EOF

    echo "=> Restarting API..."
    systemctl restart xray-api
    
    echo -e "\n\e[32m[SUCCESS]\e[0m Domain berhasil diganti menjadi $DOMAIN!"
    sleep 2
}

# ==========================================
# MANAJEMEN EXTRA DOMAIN (BUG / SNI)
# ==========================================
add_extra_domain() {
    clear
    echo "======================================"
    echo "      TAMBAH SUBDOMAIN (BUG) BARU     "
    echo "======================================"
    echo "Domain Utama : $DOMAIN"
    echo "======================================"
    echo "Cukup masukkan subdomain depannya saja."
    echo "Contoh: jika Anda memasukkan 'bug.wa',"
    echo "maka akan menjadi: bug.wa.$DOMAIN"
    echo "======================================"
    read -p "Masukkan Subdomain (tekan 'x' untuk batal): " input_bug
    
    if [[ "$input_bug" == "x" || "$input_bug" == "X" || -z "$input_bug" ]]; then return; fi
    
    # Pencegahan jika user tidak sengaja memasukkan domain utama di belakang
    input_bug=${input_bug%.$DOMAIN}
    
    full_domain="${input_bug}.${DOMAIN}"
    
    echo -e "\nMemeriksa resolusi DNS untuk $full_domain..."
    domain_ip=$(getent ahostsv4 "$full_domain" | awk '{ print $1 }' | head -n 1)
    
    if [[ "$domain_ip" != "$IP_ADD" ]]; then
        echo -e "\n\e[31m[ERROR]\e[0m Domain $full_domain belum mengarah ke IP $IP_ADD!"
        echo "IP DNS saat ini: ${domain_ip:-Kosong}"
        echo "Pastikan A Record DNS sudah mengarah ke VPS (DNS Only)."
        sleep 4
        return
    fi
    
    # Cek duplikasi
    if grep -q "^$full_domain$" /usr/local/etc/srpcom/extra_domains.txt 2>/dev/null; then
        echo -e "\n\e[33m[INFO]\e[0m Domain $full_domain sudah ada dalam daftar."
        sleep 2
        return
    fi
    
    # Simpan ke daftar
    echo "$full_domain" >> /usr/local/etc/srpcom/extra_domains.txt
    
    echo -e "\n=> Mengonfigurasi ulang Caddy Server..."
    rebuild_caddyfile
    
    echo -e "\n\e[32m[SUCCESS]\e[0m Bug $full_domain berhasil ditambahkan dan diamankan!"
    sleep 2
}

del_extra_domain() {
    clear
    echo "======================================"
    echo "         HAPUS EXTRA DOMAIN / SNI     "
    echo "======================================"
    if [ ! -s "/usr/local/etc/srpcom/extra_domains.txt" ]; then
        echo "Belum ada domain tambahan yang terdaftar."
        pause; return
    fi
    
    mapfile -t domains < /usr/local/etc/srpcom/extra_domains.txt
    
    if [ ${#domains[@]} -eq 0 ]; then
        echo "Belum ada domain tambahan yang terdaftar."
        pause; return
    fi

    for i in "${!domains[@]}"; do
        echo "$((i+1)). ${domains[$i]}"
    done
    echo "0. Kembali"
    echo "======================================"
    read -p "Pilih nomor domain yang dihapus [1-${#domains[@]} or 0]: " choice
    
    if [[ "$choice" == "0" ]]; then return; fi

    if [[ "$choice" -gt 0 && "$choice" -le "${#domains[@]}" ]]; then
        selected_domain="${domains[$((choice-1))]}"
        
        # Hapus domain dari file TXT
        sed -i "/^${selected_domain}$/d" /usr/local/etc/srpcom/extra_domains.txt
        
        echo -e "\n=> Mengonfigurasi ulang Caddy Server..."
        rebuild_caddyfile
        
        echo -e "\n\e[32m[SUCCESS]\e[0m Domain $selected_domain berhasil dihapus dari sistem!"
        sleep 2
    else
        echo -e "\n=> Pilihan tidak valid!"; sleep 1; del_extra_domain
    fi
}

list_extra_domain() {
    clear
    echo "======================================"
    echo "        DAFTAR EXTRA DOMAIN / SNI     "
    echo "======================================"
    if [ ! -s "/usr/local/etc/srpcom/extra_domains.txt" ]; then
        echo "Belum ada domain tambahan yang terdaftar."
    else
        awk '{print "- " $1}' /usr/local/etc/srpcom/extra_domains.txt
    fi
    echo "======================================"
    pause
}

import_github_domain() {
    clear
    echo "======================================"
    echo "     IMPORT EXTRA DOMAIN (GITHUB)     "
    echo "======================================"
    echo "Fitur ini akan mengunduh daftar Bug/SNI"
    echo "dari GitHub dan menggabungkannya dengan"
    echo "daftar yang sudah ada di VPS Anda."
    echo "======================================"
    read -p "Apakah Anda yakin ingin mengimpor data? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "=> Dibatalkan."; sleep 1; return
    fi

    echo -e "\n=> Mengunduh daftar Extra Domain dari GitHub..."
    wget -q -O /tmp/new_domains.txt "$GITHUB_RAW/core/extra_domains.txt"
    if [ -s /tmp/new_domains.txt ]; then
        touch /usr/local/etc/srpcom/extra_domains.txt
        cat /usr/local/etc/srpcom/extra_domains.txt /tmp/new_domains.txt | sort -u | grep -v '^$' > /tmp/merged_domains.txt
        mv /tmp/merged_domains.txt /usr/local/etc/srpcom/extra_domains.txt
        rm -f /tmp/new_domains.txt
        echo -e "\e[32m[SUCCESS]\e[0m Daftar domain berhasil diperbarui dan digabungkan!"
        echo -e "=> Mengonfigurasi ulang Caddy Server..."
        rebuild_caddyfile
        sleep 2
    else
        echo -e "\e[31m[ERROR]\e[0m Gagal mengunduh atau file extra_domains.txt di GitHub kosong!"
        rm -f /tmp/new_domains.txt
        sleep 2
    fi
}

menu_extra_domain() {
    while true; do
        clear
        echo "======================================"
        echo "     MANAJEMEN EXTRA DOMAIN / SNI     "
        echo "======================================"
        echo "Domain Utama : $DOMAIN"
        echo "Default SSL  : support.zoom.us.$DOMAIN"
        echo "======================================"
        echo "1. Tambah Subdomain (Bug) Baru"
        echo "2. Hapus Subdomain (Bug)"
        echo "3. Lihat Daftar Subdomain"
        echo "4. Import Daftar Subdomain dari GitHub"
        echo "0/x. Kembali ke Settings"
        echo "======================================"
        read -p "Pilih opsi [0-4 or x]: " opt
        case $opt in
            1) add_extra_domain ;;
            2) del_extra_domain ;;
            3) list_extra_domain ;;
            4) import_github_domain ;;
            0|x|X) break ;;
            *) echo -e "\n=> Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

menu_api_key() {
    clear
    echo "======================================"
    echo "       SETTING API KEY WEBSITE        "
    echo "======================================"
    current_key=$(cat /usr/local/etc/xray/api_key.conf 2>/dev/null)
    echo "Current API Key: ${current_key}"
    echo "======================================"
    read -p "Input New API Key (tekan 'x' untuk batal): " new_key
    if [[ "$new_key" != "x" && "$new_key" != "X" && -n "$new_key" ]]; then
        echo "$new_key" > /usr/local/etc/xray/api_key.conf
        systemctl restart xray-api
        echo -e "\n\e[32m[SUCCESS]\e[0m API Key berhasil diubah dan sistem direstart!"
        sleep 2
    fi
}

restore_data() {
    clear
    echo "======================================"
    echo "     RESTORE DATA (MULTI-PROTOCOL)    "
    echo "======================================"
    read -p "Nama file backup (misal: srpcom-backup.tar.gz) atau 'x' untuk batal : " backup_name
    
    if [ -z "$backup_name" ]; then return; fi
    if [[ "$backup_name" == "x" || "$backup_name" == "X" ]]; then return; fi
    if [ ! -f "/root/$backup_name" ]; then
        echo -e "\n\e[31m[ERROR]\e[0m File /root/$backup_name tidak ditemukan!"
        sleep 2; return
    fi

    echo -e "\nMetode Restore:"
    echo "1. Replace (Hapus user saat ini, ganti total dengan backup)"
    echo "2. Merge   (Tambahkan user dari backup ke data saat ini)"
    read -p "Pilih Metode [1-2]: " restore_mode

    case $restore_mode in
        1)
            tar -xzf "/root/$backup_name" -C / 2>/dev/null
            if [ -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
                echo "=> Membangun ulang akun SSH..."
                while read -r user pass exp_date exp_time; do
                    if ! id "$user" &>/dev/null; then
                        useradd -e "$exp_date" -s /bin/false -M "$user"
                        echo -e "$pass\n$pass" | passwd "$user" &> /dev/null
                    fi
                done < /usr/local/etc/srpcom/ssh_expiry.txt
            fi
            echo -e "\n\e[32m[SUCCESS]\e[0m Restore Replace Berhasil!"
            ;;
        2)
            echo -e "\nMenggabungkan data (Merging)..."
            mkdir -p /tmp/restore_temp
            tar -xzf "/root/$backup_name" -C /tmp/restore_temp 2>/dev/null
            
            jq -s '.[0].inbounds[0].settings.clients = (.[0].inbounds[0].settings.clients + .[1].inbounds[0].settings.clients | unique_by(.email)) | .[0]' \
               /usr/local/etc/xray/config.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v1.json
            jq -s '.[0].inbounds[1].settings.clients = (.[0].inbounds[1].settings.clients + .[1].inbounds[1].settings.clients | unique_by(.email)) | .[0]' \
               /tmp/merged_v1.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v2.json
            jq -s '.[0].inbounds[2].settings.clients = (.[0].inbounds[2].settings.clients + .[1].inbounds[2].settings.clients | unique_by(.email)) | .[0]' \
               /tmp/merged_v2.json /tmp/restore_temp/usr/local/etc/xray/config.json > /tmp/merged_v3.json
            mv /tmp/merged_v3.json /usr/local/etc/xray/config.json
            
            for txt_file in usr/local/etc/xray/expiry.txt usr/local/etc/xray/limit.txt usr/local/etc/srpcom/l2tp_expiry.txt usr/local/etc/srpcom/ssh_expiry.txt usr/local/etc/srpcom/ssh_limit.txt usr/local/etc/srpcom/extra_domains.txt etc/ppp/chap-secrets; do
                if [ -f "/tmp/restore_temp/$txt_file" ]; then
                    touch "/$txt_file" 2>/dev/null
                    cat "/$txt_file" "/tmp/restore_temp/$txt_file" | sort -k1,1 -u > "/tmp/merged_$(basename $txt_file)"
                    mv "/tmp/merged_$(basename $txt_file)" "/$txt_file"
                fi
            done
            
            if [ -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
                echo "=> Membangun ulang akun SSH..."
                while read -r user pass exp_date exp_time; do
                    if ! id "$user" &>/dev/null; then
                        useradd -e "$exp_date" -s /bin/false -M "$user"
                        echo -e "$pass\n$pass" | passwd "$user" &> /dev/null
                    fi
                done < /usr/local/etc/srpcom/ssh_expiry.txt
            fi

            rm -rf /tmp/restore_temp
            echo -e "\n\e[32m[SUCCESS]\e[0m Restore Merge Berhasil!"
            ;;
        *) echo "Batal."; sleep 1; return ;;
    esac

    # Rebuild Caddyfile agar domain hasil restore langsung didaftarkan ke SSL
    rebuild_caddyfile

    systemctl restart xray caddy xray-api ipsec xl2tpd dropbear ssh-ws srpcom-bot
    pause
}

menu_settings() {
    while true; do
        clear
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║               BACKUP & RESTORE / SETTINGS              ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo " [1] AUTOBACKUP VIA BOT TELEGRAM"
        echo " [2] AUTOSEND CREATED VPN VIA BOT"
        echo " [3] BACKUP VIA BOT TELEGRAM (MANUAL)"
        echo " [4] RESTORE DATA via VPS"
        echo " [5] SETTING API KEY FOR WEBSITE"
        echo " [6] GANTI DOMAIN VPS"
        echo " [7] SETTING AUTO-KILL MULTI LOGIN"
        echo " [8] SETTING AUTO-DELETE EXPIRED"
        echo " [9] SETTING TELEGRAM ADMIN BOT"
        echo " [10] MANAJEMEN DOMAIN BUG / SNI"
        echo "---------------------------------------------------------"
        echo " [0/x] Back to Main Menu"
        echo "========================================================="
        read -p " Select option [0-10 or x]: " opt
        case $opt in
            1) menu_autobackup ;;
            2) menu_autosend ;;
            3) manual_backup_telegram ;;
            4) restore_data ;;
            5) menu_api_key ;;
            6) change_domain ;;
            7) menu_autokill ;;
            8) menu_auto_expired ;;
            9) menu_bot_admin ;;
            10) menu_extra_domain ;;
            0|x|X) exec menu ;;
            *) echo "Pilihan tidak valid!"; sleep 1 ;;
        esac
    done
}

main_menu() {
    while true; do
        print_header
        
        echo "1. MENU XRAY (Vmess, Vless, Trojan)"
        echo "2. MENU SSH & OVPN"
        echo "3. MENU L2TP"
        echo "4. MONITORING PANEL"
        echo "5. SETTINGS (Backup/Autokill/Bot)"
        echo "6. RESTART SERVICES (All)"
        echo "7. CEK STATUS SERVICES"
        echo "8. UPDATE SCRIPT DARI GITHUB"
        echo "0/x. Exit CLI"
        echo ""
        read -p "Pilih opsi [0-8 or x]: " opt
        case $opt in
            1) menu_xray ;;
            2) menu_ssh ;;
            3) menu_l2tp ;;
            4) menu_monitor ;;
            5) menu_settings ;;
            6) 
                echo -e "\n=> Restarting Services..."
                systemctl restart xray caddy cron xray-api ipsec xl2tpd dropbear ssh-ws srpcom-bot 2>/dev/null
                echo -e "=> Done!"
                sleep 1.5 ;;
            7)
                clear
                echo "======================================"
                echo "          STATUS SERVICES             "
                echo "======================================"
                echo -n "XRAY CORE     : "
                if systemctl is-active --quiet xray; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "CADDY PROXY   : "
                if systemctl is-active --quiet caddy; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "API SERVER    : "
                if systemctl is-active --quiet xray-api; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "ADMIN BOT     : "
                if systemctl is-active --quiet srpcom-bot; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ OFF / STANDBY ]\e[0m"; fi
                echo -n "L2TP (IPsec)  : "
                if systemctl is-active --quiet ipsec; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "L2TP (xl2tpd) : "
                if systemctl is-active --quiet xl2tpd; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "DROPBEAR (SSH): "
                if systemctl is-active --quiet dropbear; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "SSH-WS PROXY  : "
                if systemctl is-active --quiet ssh-ws; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "OPENVPN SERVER: "
                if systemctl is-active --quiet openvpn-server@server-udp; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo -n "BADVPN (UDPGW): "
                if systemctl is-active --quiet badvpn-7100; then echo -e "\e[32m[ RUNNING ]\e[0m"; else echo -e "\e[31m[ ERROR ]\e[0m"; fi
                echo "======================================"
                pause ;;
            8) menu_update ;;
            0|x|X) clear; exit 0 ;;
            *) echo "Tidak valid!"; sleep 1 ;;
        esac
    done
}

# Eksekusi fungsi utama
main_menu
