#!/usr/bin/env python3
# ==========================================
# bot-admin.py
# MODULE: TELEGRAM ADMIN INTERACTIVE BOT (REVISED)
# ==========================================

import os
import sys
import json
import time
import datetime
import subprocess
import requests
import telebot
import logging
from telebot.types import InlineKeyboardMarkup, InlineKeyboardButton, ForceReply

# --- KONFIGURASI PATH ---
CONF_FILE = '/usr/local/etc/xray/bot_admin.conf'
API_KEY_FILE = '/usr/local/etc/xray/api_key.conf'
API_BASE = 'http://127.0.0.1:5000/user_legend'
XRAY_CONF = '/usr/local/etc/xray/config.json'
XRAY_EXP = '/usr/local/etc/xray/expiry.txt'
SSH_EXP = '/usr/local/etc/srpcom/ssh_expiry.txt'
L2TP_EXP = '/usr/local/etc/srpcom/l2tp_expiry.txt'

# --- LOADING SETTINGS ---
def load_bot_config():
    bot_token, admin_id = "", ""
    try:
        if os.path.exists(CONF_FILE):
            with open(CONF_FILE, 'r') as f:
                lines = f.read().splitlines()
                for line in lines:
                    if line.startswith('BOT_TOKEN='):
                        bot_token = line.split('=')[1].strip().strip('"').strip("'")
                    elif line.startswith('ADMIN_ID='):
                        admin_id = line.split('=')[1].strip().strip('"').strip("'")
    except Exception:
        pass
    return bot_token, admin_id

BOT_TOKEN, ADMIN_ID = load_bot_config()

# Mencegah SystemD Crash Loop
if not BOT_TOKEN or not ADMIN_ID:
    print("WARNING: Token Bot atau Admin ID kosong di file /usr/local/etc/xray/bot_admin.conf.")
    print("Bot masuk ke mode siaga. Silakan setting melalui menu CLI.")
    while not BOT_TOKEN or not ADMIN_ID:
        time.sleep(30)
        BOT_TOKEN, ADMIN_ID = load_bot_config()
    print("Token ditemukan! Melanjutkan inisiasi bot...")

def get_api_key():
    try:
        if os.path.exists(API_KEY_FILE):
            with open(API_KEY_FILE, 'r') as f:
                return f.read().strip()
    except:
        pass
    return "DEFAULT_KEY"

def load_json(p):
    if not os.path.exists(p):
        return {}
    try:
        with open(p, 'r') as f:
            return json.load(f)
    except:
        return {}

# --- INISIALISASI BOT ---
bot = telebot.TeleBot(BOT_TOKEN)

# Mengaktifkan Log Level DEBUG untuk Telebot
telebot.logger.setLevel(logging.DEBUG)

PROT_MAP = {'vmess': 'vmessws', 'vless': 'vlessws', 'trojan': 'trojanws', 'ssh': 'ssh', 'l2tp': 'l2tp'}

def is_admin(message):
    return str(message.chat.id) == ADMIN_ID

def api_req(endpoint, method="POST", payload=None):
    headers = {"x-api-key": get_api_key(), "Content-Type": "application/json"}
    url = f"{API_BASE}/{endpoint}"
    try:
        if method == "GET":
            res = requests.get(url, headers=headers, json=payload, timeout=10)
        elif method == "DELETE":
            res = requests.delete(url, headers=headers, json=payload, timeout=10)
        else:
            res = requests.post(url, headers=headers, json=payload, timeout=10)
            
        # Pengecekan HTTP Status agar error 404/500 tidak tereksekusi sbg text biasa
        res.raise_for_status()
        
        # BARIS YANG DIUBAH (Mengutamakan format telegram stdout_tg)
        res_json = res.json()
        return res_json.get('stdout_tg', res_json.get('stdout', '✅ Command executed successfully but no output.'))

    except requests.exceptions.HTTPError as errh:
        try:
            return res.json().get('stdout', f"❌ API HTTP Error: {errh}")
        except:
            return f"❌ HTTP Error ({res.status_code}): Fungsi ini belum dikonfigurasi di server API."
    except requests.exceptions.ConnectionError as errc:
        return f"❌ Error Koneksi: API Server (Backend) sedang mati/down.\nDetail: {errc}"
    except Exception as e:
        return f"❌ Unexpected Error: {str(e)}"

# --- FUNGSI LOGIKA LIST & BACKUP ---
def get_list_accounts(prot):
    result = []
    if prot in ['vmess', 'vless', 'trojan']:
        cfg = load_json(XRAY_CONF)
        target_users = []
        for ib in cfg.get('inbounds', []):
            if ib.get('protocol') == prot:
                for c in ib['settings'].get('clients', []):
                    email = c.get('email')
                    if email: target_users.append(email)
        exp_data = {}
        if os.path.exists(XRAY_EXP):
            with open(XRAY_EXP, 'r') as f:
                for line in f:
                    p = line.strip().split()
                    if len(p) >= 2:
                        exp_data[p[0]] = p[1]
        for u in target_users:
            exp = exp_data.get(u, "Lifetime")
            result.append(f"• `{u}` (Exp: {exp})")
    elif prot == 'ssh' and os.path.exists(SSH_EXP):
        with open(SSH_EXP, 'r') as f:
            for line in f:
                p = line.strip().split()
                if len(p) >= 3:
                    result.append(f"• `{p[0]}` (Exp: {p[2]})")
    elif prot == 'l2tp' and os.path.exists(L2TP_EXP):
        with open(L2TP_EXP, 'r') as f:
            for line in f:
                p = line.strip().split()
                if len(p) >= 3:
                    result.append(f"• `{p[0]}` (Exp: {p[2]})")

    if not result:
        return f"Belum ada akun aktif untuk protokol {prot.upper()}."
    return f"📋 *LIST ACCOUNT {prot.upper()}*\n━━━━━━━━━━━━━━━━━━━━\n" + "\n".join(result)

def handle_backup_bot(chat_id):
    now_str = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = f"/tmp/srpcom-backup-{now_str}.tar.gz"
    files = [
        "/usr/local/etc/xray/config.json", "/usr/local/etc/xray/expiry.txt", 
        "/usr/local/etc/xray/limit.txt", "/usr/local/etc/srpcom/env.conf", 
        "/usr/local/etc/srpcom/l2tp_expiry.txt", "/usr/local/etc/srpcom/ssh_expiry.txt", 
        "/etc/ppp/chap-secrets"
    ]
    valid = [f for f in files if os.path.exists(f)]
    if valid:
        try:
            subprocess.run(['tar', '-czf', backup_file, '-C', '/'] + [f.lstrip('/') for f in valid], check=True)
            with open(backup_file, 'rb') as doc:
                bot.send_document(chat_id, doc, caption=f"📦 *BACKUP VPS VPN*\nTanggal: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", parse_mode="Markdown")
            os.remove(backup_file)
        except Exception as e:
            bot.send_message(chat_id, f"Gagal Backup: {e}")
    else:
        bot.send_message(chat_id, "Tidak ada data untuk dibackup.")

# --- KEYBOARDS ---
def main_menu_keyboard():
    markup = InlineKeyboardMarkup(row_width=3)
    markup.add(
        InlineKeyboardButton("🚀 VMESS", callback_data="prot_vmess"),
        InlineKeyboardButton("🚀 VLESS", callback_data="prot_vless"),
        InlineKeyboardButton("🚀 TROJAN", callback_data="prot_trojan")
    )
    markup.add(
        InlineKeyboardButton("🔐 SSH / OVPN", callback_data="prot_ssh"),
        InlineKeyboardButton("🛡️ L2TP IPsec", callback_data="prot_l2tp")
    )
    markup.add(
        InlineKeyboardButton("📊 MONITORING", callback_data="menu_monitor"),
        InlineKeyboardButton("⚙️ STATUS & BACKUP", callback_data="menu_status")
    )
    return markup

def protocol_menu_keyboard(prot):
    markup = InlineKeyboardMarkup(row_width=2)
    markup.add(
        InlineKeyboardButton("➕ Add", callback_data=f"act_add_{prot}"),
        InlineKeyboardButton("⏱️ Trial", callback_data=f"act_trial_{prot}")
    )
    markup.add(
        InlineKeyboardButton("📄 Detail", callback_data=f"act_detail_{prot}"),
        InlineKeyboardButton("📋 List", callback_data=f"act_list_{prot}")
    )
    markup.add(
        InlineKeyboardButton("🗑️ Del", callback_data=f"act_del_{prot}"),
        InlineKeyboardButton("🔄 Renew", callback_data=f"act_renew_{prot}")
    )
    markup.add(InlineKeyboardButton("🔙 Back", callback_data="menu_main"))
    return markup

def status_menu_keyboard():
    markup = InlineKeyboardMarkup(row_width=1)
    markup.add(
        InlineKeyboardButton("💻 CEK STATUS SERVICES", callback_data="sys_cek_status"),
        InlineKeyboardButton("📦 REQUEST BACKUP DATA", callback_data="sys_backup"),
        InlineKeyboardButton("🔙 KEMBALI", callback_data="menu_main")
    )
    return markup

def monitor_menu_keyboard():
    markup = InlineKeyboardMarkup(row_width=1)
    markup.add(
        InlineKeyboardButton("📈 MONITOR XRAY (IP & KUOTA)", callback_data="mon_xray"),
        InlineKeyboardButton("💻 MONITOR SSH (USER AKTIF)", callback_data="mon_ssh"),
        InlineKeyboardButton("🔙 KEMBALI", callback_data="menu_main")
    )
    return markup

# --- FUNGSI MONITORING ---
def get_monitor_xray():
    try:
        ip_data = {}
        if os.path.exists('/var/log/xray/access.log'):
            try:
                out = subprocess.run(['tail', '-n', '3000', '/var/log/xray/access.log'], capture_output=True, text=True)
                for line in out.stdout.splitlines():
                    if 'accepted' in line and '127.0.0.1' not in line:
                        parts = line.split()
                        if len(parts) >= 7:
                            user = parts[6]
                            ip = parts[2].replace('tcp:', '').replace('udp:', '').split(':')[0]
                            if user not in ip_data:
                                ip_data[user] = set()
                            ip_data[user].add(ip)
            except: pass

        stats = {}
        try:
            out = subprocess.run(['/usr/local/bin/xray', 'api', 'statsquery', '--server=127.0.0.1:10085'], capture_output=True, text=True)
            data = json.loads(out.stdout)
            for item in data.get('stat', []):
                name_parts = item['name'].split('>>>')
                if len(name_parts) >= 4 and name_parts[0] == 'user':
                    user = name_parts[1]
                    t_type = name_parts[3]
                    if user not in stats:
                        stats[user] = {'downlink': 0, 'uplink': 0}
                    stats[user][t_type] = item.get('value', 0)
        except: pass

        limits = {}
        if os.path.exists('/usr/local/etc/xray/limit.txt'):
            with open('/usr/local/etc/xray/limit.txt', 'r') as f:
                for line in f:
                    p = line.strip().split()
                    if len(p) >= 3:
                        limits[p[0]] = {'ip': int(p[1]), 'quota': int(p[2])}

        all_users = set(list(stats.keys()) + list(ip_data.keys()))
        if not all_users:
            return "Belum ada data pemakaian atau user aktif di Xray."

        res = "📈 *XRAY MONITORING*\n━━━━━━━━━━━━━━━━━━━━\n"
        for u in sorted(all_users):
            active_ips = len(ip_data.get(u, set()))
            lim_ip = limits.get(u, {}).get('ip', 0)
            lim_ip_str = str(lim_ip) if lim_ip > 0 else 'Unli'
            
            dl = stats.get(u, {}).get('downlink', 0) / 1048576
            ul = stats.get(u, {}).get('uplink', 0) / 1048576
            tot_gb = (dl + ul) / 1024
            
            lim_q = limits.get(u, {}).get('quota', 0)
            lim_q_str = f"{lim_q} GB" if lim_q > 0 else 'Unli'
            
            res += f"👤 *{u}*\n├ IP Aktif : {active_ips} / {lim_ip_str}\n└ Kuota : {tot_gb:.2f} GB / {lim_q_str}\n\n"
        return res
    except Exception as e:
        return f"Gagal mengambil data monitoring Xray: {e}"

def get_monitor_ssh():
    try:
        res = "💻 *SSH MONITORING*\n━━━━━━━━━━━━━━━━━━━━\n"
        out = subprocess.run('netstat -tnpa', shell=True, capture_output=True, text=True)
        active_users = []
        for line in out.stdout.splitlines():
            if 'ESTABLISHED' in line and ('dropbear' in line or 'sshd' in line):
                parts = line.split()
                if len(parts) >= 7:
                    pid_prog = parts[6]
                    pid = pid_prog.split('/')[0]
                    ip = parts[4].split(':')[0]
                    try:
                        u_out = subprocess.run(['ps', '-o', 'user=', '-p', pid], capture_output=True, text=True)
                        user = u_out.stdout.strip()
                        if user and user != 'root':
                            active_users.append(f"👤 `{user}` | 🌐 {ip}")
                    except: pass
        
        if not active_users:
            return res + "Belum ada user SSH/Dropbear yang aktif."
        return res + "\n".join(active_users)
    except Exception as e:
        return f"Gagal mengambil data monitoring SSH: {e}"

# --- HANDLERS ---
@bot.message_handler(commands=['start', 'menu'])
def send_welcome(message):
    if not is_admin(message):
        bot.reply_to(message, "⛔ Akses Ditolak!")
        return
    bot.send_message(message.chat.id, "👋 *PANEL ADMIN VPS*", reply_markup=main_menu_keyboard(), parse_mode="Markdown")

@bot.callback_query_handler(func=lambda call: True)
def handle_query(call):
    if not is_admin(call.message):
        bot.answer_callback_query(call.id, "Akses Ditolak!")
        return
    
    data = call.data
    chat_id = call.message.chat.id
    msg_id = call.message.message_id
    
    try:
        if data == "menu_main":
            bot.edit_message_text("👋 *PANEL ADMIN VPS*", chat_id, msg_id, reply_markup=main_menu_keyboard(), parse_mode="Markdown")
        
        elif data == "menu_status":
            bot.edit_message_text("⚙️ *MENU STATUS & BACKUP*", chat_id, msg_id, reply_markup=status_menu_keyboard(), parse_mode="Markdown")

        elif data == "menu_monitor":
            bot.edit_message_text("📊 *MENU MONITORING*\nSilakan pilih layanan yang ingin dimonitor:", chat_id, msg_id, reply_markup=monitor_menu_keyboard(), parse_mode="Markdown")

        elif data == "mon_xray":
            bot.answer_callback_query(call.id, "Mengambil data Xray...")
            bot.send_message(chat_id, get_monitor_xray(), parse_mode="Markdown")

        elif data == "mon_ssh":
            bot.answer_callback_query(call.id, "Mengambil data SSH...")
            bot.send_message(chat_id, get_monitor_ssh(), parse_mode="Markdown")
        
        elif data == "sys_cek_status":
            bot.answer_callback_query(call.id, "Mengecek...")
            bot.send_message(chat_id, f"💻 *STATUS SERVER:*\n{api_req('cek-xray', 'GET')}", parse_mode="Markdown")
        
        elif data == "sys_backup":
            bot.answer_callback_query(call.id, "Memproses...")
            handle_backup_bot(chat_id)
            
        elif data.startswith("prot_"):
            prot = data.split("_")[1]
            bot.edit_message_text(f"🔧 *MANAGE {prot.upper()}*", chat_id, msg_id, reply_markup=protocol_menu_keyboard(prot), parse_mode="Markdown")
            
        elif data.startswith("act_"):
            p = data.split("_")
            act = p[1]
            prot = p[2]
            api_ep = PROT_MAP.get(prot)
            
            if act == "list":
                bot.answer_callback_query(call.id, "Mengambil data...")
                bot.send_message(chat_id, get_list_accounts(prot), parse_mode="Markdown")
                
            elif act == "trial":
                bot.answer_callback_query(call.id, "Membuat trial...")
                payload = {"exp": 60, "limit_ip": 1} if prot == "ssh" else {"exp": 60, "limit_ip": 1, "limit_quota": 1}
                bot.send_message(chat_id, api_req(f"trial-{api_ep}", "POST", payload), parse_mode="Markdown")
                
            else:
                if act == "add":
                    if prot in ['vmess', 'vless', 'trojan']:
                        t = "✏️ Data: `User Expired(Hari) Limit_IP Limit_Quota`"
                    elif prot == "ssh":
                        t = "✏️ Data: `User Pass Expired(Hari) Limit_IP`"
                    else:
                        t = "✏️ Data: `User Pass Expired(Hari)`"
                    t += "\nContoh: `budi 30 2 50`"
                elif act == "renew":
                    t = "🔄 Masukkan: `User Tambah(Hari)`"
                else:
                    t = f"🗑️/📄 Masukkan `User` untuk *{act.upper()}*"
                
                msg = bot.send_message(chat_id, t, parse_mode="Markdown", reply_markup=ForceReply())
                bot.register_next_step_handler(msg, process_action_input, act, prot, api_ep)
                
    except Exception as e:
        bot.send_message(chat_id, f"Error: {e}")

def process_action_input(message, action, prot, api_ep):
    if not message.text:
        return
    parts = message.text.split()
    payload = {}
    method = "POST"
    endpoint = f"{action}-{api_ep}"
    
    try:
        if action == "add":
            if prot in ['vmess', 'vless', 'trojan']:
                payload = {
                    'user': parts[0],
                    'exp': int(parts[1]) if len(parts) > 1 else 30,
                    'limit_ip': int(parts[2]) if len(parts) > 2 else 0,
                    'limit_quota': int(parts[3]) if len(parts) > 3 else 0
                }
            elif prot == "ssh":
                payload = {
                    'user': parts[0],
                    'password': parts[1] if len(parts) > 1 else "123",
                    'exp': int(parts[2]) if len(parts) > 2 else 30,
                    'limit_ip': int(parts[3]) if len(parts) > 3 else 0
                }
            elif prot == "l2tp":
                payload = {
                    'user': parts[0],
                    'password': parts[1] if len(parts) > 1 else "123",
                    'exp': int(parts[2]) if len(parts) > 2 else 30
                }
        elif action == "renew":
            payload = {'user': parts[0], 'exp': int(parts[1]) if len(parts) > 1 else 30}
        elif action == "del":
            payload = {'user': parts[0]}
            method = "POST" # <--- Diperbaiki agar menggunakan format yang didukung backend
        elif action == "detail":
            payload = {'user': parts[0]}
        
        bot.send_message(message.chat.id, api_req(endpoint, method, payload), parse_mode="Markdown")
    except Exception as e:
        bot.send_message(message.chat.id, f"❌ Format input salah! Detail: {e}")

if __name__ == '__main__':
    print("Bot Admin Panel sedang berjalan...")
    while True:
        try:
            bot.infinity_polling()
        except Exception as e:
            print(f"Bot Polling Error: {e}")
            time.sleep(5)
