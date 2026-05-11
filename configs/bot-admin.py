#!/usr/bin/env python3
# ==========================================
# bot-admin.py
# MODULE: TELEGRAM MASTER-NODE PANEL
# Mengendalikan puluhan VPS dari 1 Bot Telegram
# ==========================================

import os
import sys
import json
import time
import datetime
import base64
import requests
import telebot
import logging
from telebot.types import InlineKeyboardMarkup, InlineKeyboardButton, ForceReply

# --- KONFIGURASI PATH ---
CONF_FILE = '/usr/local/etc/xray/bot_admin.conf'
API_KEY_FILE = '/usr/local/etc/xray/api_key.conf'
SERVERS_FILE = '/usr/local/etc/xray/servers.json'

# --- STATE MANAGEMENT ---
# Menyimpan sesi aktif (Server yang sedang dikelola oleh Admin/Chat ID tersebut)
active_server = {}

def get_api_key():
    try:
        with open(API_KEY_FILE, 'r') as f: return f.read().strip()
    except: pass
    return "DEFAULT_KEY"

def load_bot_config():
    bot_token, admin_id = "", ""
    try:
        if os.path.exists(CONF_FILE):
            with open(CONF_FILE, 'r') as f:
                for line in f.read().splitlines():
                    if line.startswith('BOT_TOKEN='): bot_token = line.split('=')[1].strip().strip('"').strip("'")
                    elif line.startswith('ADMIN_ID='): admin_id = line.split('=')[1].strip().strip('"').strip("'")
    except: pass
    return bot_token, admin_id

BOT_TOKEN, ADMIN_ID = load_bot_config()

if not BOT_TOKEN or not ADMIN_ID:
    print("WARNING: Bot Token atau Admin ID kosong. Menunggu konfigurasi...")
    while not BOT_TOKEN or not ADMIN_ID:
        time.sleep(30)
        BOT_TOKEN, ADMIN_ID = load_bot_config()
    print("Token ditemukan! Bot dijalankan...")

bot = telebot.TeleBot(BOT_TOKEN)
telebot.logger.setLevel(logging.DEBUG)

PROT_MAP = {'vmess': 'vmessws', 'vless': 'vlessws', 'trojan': 'trojanws', 'ssh': 'ssh', 'l2tp': 'l2tp'}

def is_admin(message):
    return str(message.chat.id) == ADMIN_ID

def get_default_server():
    return {"name": "💻 Local Server", "domain": "127.0.0.1:5000", "api_key": get_api_key()}

# --- CORE API ROUTER ---
def api_req(endpoint, method="POST", payload=None, chat_id=None):
    srv = active_server.get(str(chat_id), get_default_server())
    domain = srv['domain']
    
    if "127.0.0.1" in domain or "localhost" in domain:
        url = f"http://{domain}/user_legend/{endpoint}"
    else:
        url = f"https://{domain}/user_legend/{endpoint}"
        
    headers = {"x-api-key": srv['api_key'], "Content-Type": "application/json"}
    
    try:
        if method == "GET":
            res = requests.get(url, headers=headers, json=payload, timeout=15)
        elif method == "DELETE":
            res = requests.delete(url, headers=headers, json=payload, timeout=15)
        else:
            res = requests.post(url, headers=headers, json=payload, timeout=15)
            
        res.raise_for_status()
        res_json = res.json()
        return res_json.get('stdout_tg', res_json.get('stdout', '✅ Eksekusi berhasil.'))

    except requests.exceptions.HTTPError as errh:
        try: return res.json().get('stdout', f"❌ API HTTP Error: {errh}")
        except: return f"❌ HTTP Error ({res.status_code}): Periksa keabsahan API Key atau Domain Node!"
    except requests.exceptions.ConnectionError as errc:
        return f"❌ Error Koneksi: Node Server ({srv['name']}) sedang mati/down.\nPastikan port 443 terbuka."
    except Exception as e:
        return f"❌ Unexpected Error: {str(e)}"

def handle_backup_bot(chat_id):
    bot.send_message(chat_id, "⏳ Menyusun data backup dari Node...")
    srv = active_server.get(str(chat_id), get_default_server())
    domain = srv['domain']
    
    if "127.0.0.1" in domain or "localhost" in domain:
        url = f"http://{domain}/user_legend/sys-backup"
    else:
        url = f"https://{domain}/user_legend/sys-backup"
        
    try:
        res = requests.get(url, headers={"x-api-key": srv['api_key']}, timeout=25)
        res_json = res.json()
        if 'data' in res_json:
            file_bytes = base64.b64decode(res_json['data'])
            bot.send_document(chat_id, file_bytes, visible_file_name=res_json.get('filename', 'backup.tar.gz'),
                caption=f"📦 *BACKUP VPS VPN*\nServer: {srv['name']}\nTanggal: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", parse_mode="Markdown")
        else:
            bot.send_message(chat_id, res_json.get('stdout', 'Tidak ada file backup.'))
    except Exception as e:
        bot.send_message(chat_id, f"❌ Request Backup Gagal: {e}")

# --- KEYBOARDS & UI ---
def server_selection_keyboard():
    markup = InlineKeyboardMarkup(row_width=1)
    markup.add(InlineKeyboardButton("💻 Local Server (This VPS)", callback_data="sel_srv_local"))
    
    if os.path.exists(SERVERS_FILE):
        try:
            with open(SERVERS_FILE, 'r') as f:
                data = json.load(f)
                for idx, node in enumerate(data.get("nodes", [])):
                    markup.add(InlineKeyboardButton(f"🌐 Node: {node['name']}", callback_data=f"sel_srv_{idx}"))
        except: pass
    return markup

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
    markup.add(InlineKeyboardButton("🔄 Ganti Node Server", callback_data="menu_server_selection"))
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

# --- HANDLERS ---
@bot.message_handler(commands=['start', 'menu'])
def send_welcome(message):
    if not is_admin(message):
        bot.reply_to(message, "⛔ Akses Ditolak!")
        return
    bot.send_message(message.chat.id, "👋 *PILIH NODE SERVER UNTUK DIKELOLA*\nSilakan daftarkan node tambahan melalui terminal VPS Anda.", reply_markup=server_selection_keyboard(), parse_mode="Markdown")

@bot.callback_query_handler(func=lambda call: True)
def handle_query(call):
    if not is_admin(call.message):
        bot.answer_callback_query(call.id, "Akses Ditolak!")
        return
    
    data = call.data
    chat_id = call.message.chat.id
    msg_id = call.message.message_id
    
    try:
        if data == "menu_server_selection":
            bot.edit_message_text("👋 *PILIH NODE SERVER UNTUK DIKELOLA*", chat_id, msg_id, reply_markup=server_selection_keyboard(), parse_mode="Markdown")
            
        elif data.startswith("sel_srv_"):
            srv_id = data.split("sel_srv_")[1]
            srv_info = get_default_server()
            if srv_id != "local":
                try:
                    with open(SERVERS_FILE, 'r') as f:
                        nodes = json.load(f).get("nodes", [])
                        idx = int(srv_id)
                        if idx < len(nodes):
                            srv_info = {"name": nodes[idx]["name"], "domain": nodes[idx]["domain"], "api_key": nodes[idx]["api_key"]}
                except: pass
            
            active_server[str(chat_id)] = srv_info
            bot.edit_message_text(f"👋 *PANEL ADMIN VPS*\nConnected Node: 🟢 *{srv_info['name']}*", chat_id, msg_id, reply_markup=main_menu_keyboard(), parse_mode="Markdown")
            
        elif data == "menu_main":
            srv = active_server.get(str(chat_id), get_default_server())
            bot.edit_message_text(f"👋 *PANEL ADMIN VPS*\nConnected Node: 🟢 *{srv['name']}*", chat_id, msg_id, reply_markup=main_menu_keyboard(), parse_mode="Markdown")
        
        elif data == "menu_status":
            bot.edit_message_text("⚙️ *MENU STATUS & BACKUP*", chat_id, msg_id, reply_markup=status_menu_keyboard(), parse_mode="Markdown")

        elif data == "menu_monitor":
            bot.edit_message_text("📊 *MENU MONITORING*\nSilakan pilih layanan yang ingin dimonitor:", chat_id, msg_id, reply_markup=monitor_menu_keyboard(), parse_mode="Markdown")

        elif data == "mon_xray":
            bot.answer_callback_query(call.id, "Mengambil data Xray...")
            bot.send_message(chat_id, api_req("monitor-xray", "GET", chat_id=chat_id), parse_mode="Markdown")

        elif data == "mon_ssh":
            bot.answer_callback_query(call.id, "Mengambil data SSH...")
            bot.send_message(chat_id, api_req("monitor-ssh", "GET", chat_id=chat_id), parse_mode="Markdown")
        
        elif data == "sys_cek_status":
            bot.answer_callback_query(call.id, "Mengecek...")
            bot.send_message(chat_id, f"💻 *STATUS SERVER:*\n{api_req('cek-xray', 'GET', chat_id=chat_id)}", parse_mode="Markdown")
        
        elif data == "sys_backup":
            bot.answer_callback_query(call.id, "Memproses Data Backup...")
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
                bot.answer_callback_query(call.id, "Mengambil daftar akun...")
                bot.send_message(chat_id, api_req(f"list-accounts/{prot}", "GET", chat_id=chat_id), parse_mode="Markdown")
                
            elif act == "trial":
                bot.answer_callback_query(call.id, "Membuat trial...")
                payload = {"exp": 60, "limit_ip": 1} if prot == "ssh" else {"exp": 60, "limit_ip": 1, "limit_quota": 1}
                bot.send_message(chat_id, api_req(f"trial-{api_ep}", "POST", payload, chat_id), parse_mode="Markdown")
                
            else:
                if act == "add":
                    if prot in ['vmess', 'vless', 'trojan']: t = "✏️ Data: `User Expired(Hari) Limit_IP Limit_Quota`"
                    elif prot == "ssh": t = "✏️ Data: `User Pass Expired(Hari) Limit_IP`"
                    else: t = "✏️ Data: `User Pass Expired(Hari)`"
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
    if not message.text: return
    parts = message.text.split()
    payload = {}
    method = "POST"
    endpoint = f"{action}-{api_ep}"
    
    try:
        if action == "add":
            if prot in ['vmess', 'vless', 'trojan']:
                payload = {'user': parts[0], 'exp': int(parts[1]) if len(parts) > 1 else 30, 'limit_ip': int(parts[2]) if len(parts) > 2 else 0, 'limit_quota': int(parts[3]) if len(parts) > 3 else 0}
            elif prot == "ssh":
                payload = {'user': parts[0], 'password': parts[1] if len(parts) > 1 else "123", 'exp': int(parts[2]) if len(parts) > 2 else 30, 'limit_ip': int(parts[3]) if len(parts) > 3 else 0}
            elif prot == "l2tp":
                payload = {'user': parts[0], 'password': parts[1] if len(parts) > 1 else "123", 'exp': int(parts[2]) if len(parts) > 2 else 30}
        elif action == "renew":
            payload = {'user': parts[0], 'exp': int(parts[1]) if len(parts) > 1 else 30}
        elif action == "del":
            payload = {'user': parts[0]}
            method = "POST"
        elif action == "detail":
            payload = {'user': parts[0]}
        
        bot.send_message(message.chat.id, api_req(endpoint, method, payload, chat_id=message.chat.id), parse_mode="Markdown")
    except Exception as e:
        bot.send_message(message.chat.id, f"❌ Format input salah! Detail: {e}")

if __name__ == '__main__':
    print("Bot Master Node Panel sedang berjalan...")
    while True:
        try: bot.infinity_polling()
        except Exception as e:
            print(f"Bot Polling Error: {e}")
            time.sleep(5)
