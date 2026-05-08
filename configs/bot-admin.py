#!/usr/bin/env python3
# ==========================================
# bot-admin.py
# MODULE: TELEGRAM ADMIN INTERACTIVE BOT
# Mengontrol seluruh fungsi VPS via Inline Keyboard Telegram
# ==========================================

import os, sys, json, time
try:
    import telebot
    from telebot.types import InlineKeyboardMarkup, InlineKeyboardButton
    import requests
except ImportError:
    print("Modul 'telebot' atau 'requests' belum terinstal.")
    sys.exit(1)

# Konfigurasi Path
CONF_FILE = '/usr/local/etc/xray/bot_admin.conf'
API_KEY_FILE = '/usr/local/etc/xray/api_key.conf'
API_BASE = 'http://127.0.0.1:5000/user_legend'

# Membaca Konfigurasi Bot Admin
BOT_TOKEN = ""
ADMIN_ID = ""
try:
    if os.path.exists(CONF_FILE):
        with open(CONF_FILE, 'r') as f:
            lines = f.read().splitlines()
            if len(lines) >= 2:
                BOT_TOKEN = lines[0].split('=')[1].strip().strip('"').strip("'")
                ADMIN_ID = lines[1].split('=')[1].strip().strip('"').strip("'")
except Exception as e:
    pass

# Pencegah Error jika Token belum diisi via Menu VPS
if not BOT_TOKEN or not ADMIN_ID:
    print("Token Bot atau Admin ID belum disetting.")
    print("Silakan setting melalui menu VPS [ Settings -> Setting Telegram Admin Bot ]")
    time.sleep(60) # Tidur 60 detik agar tidak terjadi restart loop agresif dari systemd
    sys.exit(1)

def get_api_key():
    try:
        with open(API_KEY_FILE, 'r') as f: return f.read().strip()
    except: return "DEFAULT_KEY"

# Inisialisasi Bot (Perbaikan Typo TeleBot)
bot = telebot.TeleBot(BOT_TOKEN)

# Mapping Protokol ke Endpoint API
PROT_MAP = {
    'vmess': 'vmessws',
    'vless': 'vlessws',
    'trojan': 'trojanws',
    'ssh': 'ssh',
    'l2tp': 'l2tp'
}

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
        
        return res.json().get('stdout', 'Terjadi kesalahan pada server.')
    except Exception as e:
        return f"Error koneksi ke API Lokal: {str(e)}"

# ==========================================
# MENU KEYBOARDS
# ==========================================
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
        InlineKeyboardButton("⚙️ CEK STATUS VPS", callback_data="menu_status")
    )
    return markup

def protocol_menu_keyboard(prot):
    markup = InlineKeyboardMarkup(row_width=2)
    markup.add(
        InlineKeyboardButton("➕ Create Account", callback_data=f"act_add_{prot}"),
        InlineKeyboardButton("⏱️ Create Trial", callback_data=f"act_trial_{prot}")
    )
    markup.add(
        InlineKeyboardButton("🔄 Renew Account", callback_data=f"act_renew_{prot}"),
        InlineKeyboardButton("🗑️ Delete Account", callback_data=f"act_del_{prot}")
    )
    markup.add(
        InlineKeyboardButton("📄 Detail Account", callback_data=f"act_detail_{prot}")
    )
    markup.add(InlineKeyboardButton("🔙 KEMBALI", callback_data="menu_main"))
    return markup

def monitor_menu_keyboard():
    markup = InlineKeyboardMarkup(row_width=1)
    markup.add(
        InlineKeyboardButton("🔍 Cek Xray (Status)", callback_data="mon_cekxray"),
        InlineKeyboardButton("🔍 Cek SSH (IP Aktif)", callback_data="mon_cekssh"),
        InlineKeyboardButton("🔙 KEMBALI", callback_data="menu_main")
    )
    return markup

# ==========================================
# COMMAND HANDLERS
# ==========================================
@bot.message_handler(commands=['start', 'menu'])
def send_welcome(message):
    if not is_admin(message):
        bot.reply_to(message, "⛔ Akses Ditolak! Anda bukan Admin server ini.")
        return
    
    text = "👋 *SELAMAT DATANG DI PANEL ADMIN VPS*\nSilakan pilih protokol yang ingin Anda kelola:"
    bot.send_message(message.chat.id, text, reply_markup=main_menu_keyboard(), parse_mode="Markdown")

# ==========================================
# CALLBACK HANDLERS (TOMBOL)
# ==========================================
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
            bot.edit_message_text("👋 *PANEL ADMIN VPS*\nSilakan pilih menu:", chat_id, msg_id, reply_markup=main_menu_keyboard(), parse_mode="Markdown")
        
        elif data == "menu_monitor":
            bot.edit_message_text("📊 *MENU MONITORING*", chat_id, msg_id, reply_markup=monitor_menu_keyboard(), parse_mode="Markdown")
            
        elif data == "menu_status":
            bot.answer_callback_query(call.id, "Mengecek status VPS...")
            res = api_req("cek-xray", "GET")
            bot.send_message(chat_id, f"💻 *STATUS SERVER:*\n{res}", parse_mode="Markdown")
            
        elif data == "mon_cekxray":
            res = api_req("cek-xray", "GET")
            bot.send_message(chat_id, f"📊 *STATUS XRAY:*\n{res}", parse_mode="Markdown")
            
        elif data == "mon_cekssh":
            res = api_req("cek-ssh", "GET")
            bot.send_message(chat_id, f"📊 *STATUS SSH:*\n{res}", parse_mode="Markdown")

        elif data.startswith("prot_"):
            prot = data.split("_")[1]
            bot.edit_message_text(f"🔧 *MANAGE PROTOKOL {prot.upper()}*", chat_id, msg_id, reply_markup=protocol_menu_keyboard(prot), parse_mode="Markdown")

        elif data.startswith("act_"):
            parts = data.split("_")
            action = parts[1]
            prot = parts[2]
            api_ep = PROT_MAP.get(prot)
            
            if action == "trial":
                bot.answer_callback_query(call.id, "Membuat akun trial...")
                if prot == "ssh":
                    payload = {"exp": 60, "limit_ip": 1}
                else:
                    payload = {"exp": 60, "limit_ip": 1, "limit_quota": 1}
                res = api_req(f"trial-{api_ep}", "POST", payload)
                bot.send_message(chat_id, res)
                
            else:
                if action == "add":
                    if prot in ['vmess', 'vless', 'trojan']:
                        txt = "✏️ *CREATE ACCOUNT*\nBalas pesan ini dengan format:\n`Username, Expired(Hari), Limit IP, Limit Quota(GB)`\n\n_Contoh:_ `budi, 30, 2, 50`"
                    elif prot == "ssh":
                        txt = "✏️ *CREATE SSH*\nBalas pesan ini dengan format:\n`Username, Password, Expired(Hari), Limit IP`\n\n_Contoh:_ `budi, 1234, 30, 2`"
                    else:
                        txt = "✏️ *CREATE L2TP*\nBalas pesan ini dengan format:\n`Username, Password, Expired(Hari)`\n\n_Contoh:_ `budi, 1234, 30`"
                elif action == "renew":
                    txt = "🔄 *RENEW ACCOUNT*\nBalas pesan ini dengan format:\n`Username, Tambah(Hari)`\n\n_Contoh:_ `budi, 30`"
                elif action in ["del", "detail"]:
                    txt = f"🗑️/📄 *{action.upper()} ACCOUNT*\nBalas pesan ini dengan format:\n`Username`\n\n_Contoh:_ `budi`"

                msg = bot.send_message(chat_id, txt, parse_mode="Markdown", reply_markup=telebot.types.ForceReply())
                bot.register_next_step_handler(msg, process_action_input, action, prot, api_ep)
                
    except Exception as e:
        bot.send_message(chat_id, f"Error: {e}")

# ==========================================
# PROSES INPUT DARI ADMIN
# ==========================================
def process_action_input(message, action, prot, api_ep):
    if not message.text: return
    chat_id = message.chat.id
    bot.send_message(chat_id, "⏳ Sedang memproses ke server...")
    
    parts = [p.strip() for p in message.text.split(',')]
    payload = {}
    method = "POST"
    endpoint = f"{action}-{api_ep}"
    
    try:
        if action == "add":
            if prot in ['vmess', 'vless', 'trojan']:
                payload['user'] = parts[0]
                payload['exp'] = parts[1] if len(parts) > 1 else 30
                payload['limit_ip'] = parts[2] if len(parts) > 2 else 0
                payload['limit_quota'] = parts[3] if len(parts) > 3 else 0
            elif prot == "ssh":
                payload['user'] = parts[0]
                payload['password'] = parts[1] if len(parts) > 1 else "12345"
                payload['exp'] = parts[2] if len(parts) > 2 else 30
                payload['limit_ip'] = parts[3] if len(parts) > 3 else 0
            elif prot == "l2tp":
                payload['user'] = parts[0]
                payload['password'] = parts[1] if len(parts) > 1 else "12345"
                payload['exp'] = parts[2] if len(parts) > 2 else 30
                
        elif action == "renew":
            payload['user'] = parts[0]
            payload['exp'] = parts[1] if len(parts) > 1 else 30
            
        elif action == "del":
            payload['user'] = parts[0]
            method = "DELETE"
            
        elif action == "detail":
            payload['user'] = parts[0]
            method = "POST"

        res = api_req(endpoint, method, payload)
        bot.send_message(chat_id, res)
        
    except Exception as e:
        bot.send_message(chat_id, f"Format input salah atau error: {str(e)}")

# ==========================================
# JALANKAN BOT
# ==========================================
print("Bot Admin sedang berjalan...")
bot.infinity_polling()
