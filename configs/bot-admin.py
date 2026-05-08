#!/usr/bin/env python3
# ==========================================
# bot-admin.py
# MODULE: TELEGRAM ADMIN INTERACTIVE BOT
# Mengontrol seluruh fungsi VPS via Inline Keyboard Telegram
# ==========================================

import os, sys, json, time, datetime, subprocess
try:
    import telebot
    from telebot.types import InlineKeyboardMarkup, InlineKeyboardButton
    import requests
except ImportError:
    print("Modul 'telebot' atau 'requests' belum terinstal.")
    sys.exit(1)

CONF_FILE = '/usr/local/etc/xray/bot_admin.conf'
API_KEY_FILE = '/usr/local/etc/xray/api_key.conf'
API_BASE = 'http://127.0.0.1:5000/user_legend'

# Path Database Lokal untuk fitur List
XRAY_CONF = '/usr/local/etc/xray/config.json'
XRAY_EXP = '/usr/local/etc/xray/expiry.txt'
SSH_EXP = '/usr/local/etc/srpcom/ssh_expiry.txt'
L2TP_EXP = '/usr/local/etc/srpcom/l2tp_expiry.txt'

# Membaca Konfigurasi Bot Admin
BOT_TOKEN, ADMIN_ID = "", ""
try:
    if os.path.exists(CONF_FILE):
        with open(CONF_FILE, 'r') as f:
            lines = f.read().splitlines()
            if len(lines) >= 2:
                BOT_TOKEN = lines[0].split('=')[1].strip().strip('"').strip("'")
                ADMIN_ID = lines[1].split('=')[1].strip().strip('"').strip("'")
except Exception: pass

if not BOT_TOKEN or not ADMIN_ID:
    time.sleep(60); sys.exit(1)

def get_api_key():
    try:
        with open(API_KEY_FILE, 'r') as f: return f.read().strip()
    except: return "DEFAULT_KEY"

def load_json(p):
    if not os.path.exists(p): return {}
    with open(p, 'r') as f:
        try: return json.load(f)
        except: return {}

bot = telebot.TeleBot(BOT_TOKEN)
PROT_MAP = {'vmess': 'vmessws', 'vless': 'vlessws', 'trojan': 'trojanws', 'ssh': 'ssh', 'l2tp': 'l2tp'}

def is_admin(message): return str(message.chat.id) == ADMIN_ID

def api_req(endpoint, method="POST", payload=None):
    headers = {"x-api-key": get_api_key(), "Content-Type": "application/json"}
    url = f"{API_BASE}/{endpoint}"
    try:
        if method == "GET": res = requests.get(url, headers=headers, json=payload, timeout=10)
        elif method == "DELETE": res = requests.delete(url, headers=headers, json=payload, timeout=10)
        else: res = requests.post(url, headers=headers, json=payload, timeout=10)
        return res.json().get('stdout', 'Server error.')
    except Exception as e: return f"API Error: {str(e)}"

# --- FUNGSI LOGIKA LIST ACCOUNT ---
def get_list_accounts(prot):
    result = []
    if prot in ['vmess', 'vless', 'trojan']:
        cfg = load_json(XRAY_CONF)
        target_users = []
        # Ambil user yang terdaftar di config.json berdasarkan protokol
        for ib in cfg.get('inbounds', []):
            if ib.get('protocol') == prot:
                for c in ib['settings'].get('clients', []):
                    email = c.get('email')
                    if email: target_users.append(email)
        
        # Ambil data expiry
        exp_data = {}
        if os.path.exists(XRAY_EXP):
            with open(XRAY_EXP, 'r') as f:
                for line in f:
                    p = line.strip().split()
                    if len(p) >= 2: exp_data[p[0]] = p[1]
        
        for u in target_users:
            exp = exp_data.get(u, "Lifetime")
            result.append(f"• `{u}` (Exp: {exp})")
                
    elif prot == 'ssh' and os.path.exists(SSH_EXP):
        with open(SSH_EXP, 'r') as f:
            for line in f:
                p = line.strip().split()
                if len(p) >= 3: result.append(f"• `{p[0]}` (Exp: {p[2]})")
                        
    elif prot == 'l2tp' and os.path.exists(L2TP_EXP):
        with open(L2TP_EXP, 'r') as f:
            for line in f:
                p = line.strip().split()
                if len(p) >= 3: result.append(f"• `{p[0]}` (Exp: {p[2]})")

    if not result: return f"Belum ada akun aktif untuk protokol {prot.upper()}."
    return f"📋 *LIST ACCOUNT {prot.upper()}*\n━━━━━━━━━━━━━━━━━━━━\n" + "\n".join(result)

# --- KEYBOARDS ---
def main_menu_keyboard():
    markup = InlineKeyboardMarkup(row_width=3)
    markup.add(InlineKeyboardButton("🚀 VMESS", callback_data="prot_vmess"), InlineKeyboardButton("🚀 VLESS", callback_data="prot_vless"), InlineKeyboardButton("🚀 TROJAN", callback_data="prot_trojan"))
    markup.add(InlineKeyboardButton("🔐 SSH / OVPN", callback_data="prot_ssh"), InlineKeyboardButton("🛡️ L2TP IPsec", callback_data="prot_l2tp"))
    markup.add(InlineKeyboardButton("📊 MONITORING", callback_data="menu_monitor"), InlineKeyboardButton("⚙️ STATUS & BACKUP", callback_data="menu_status"))
    return markup

# --- HANDLERS ---
@bot.message_handler(commands=['start', 'menu'])
def send_welcome(message):
    if not is_admin(message): return
    bot.send_message(message.chat.id, "👋 *PANEL ADMIN VPS*", reply_markup=main_menu_keyboard(), parse_mode="Markdown")

@bot.callback_query_handler(func=lambda call: True)
def handle_query(call):
    if not is_admin(call.message): return
    data, chat_id, msg_id = call.data, call.message.chat.id, call.message.message_id
    try:
        if data == "menu_main": 
            bot.edit_message_text("👋 *PANEL ADMIN VPS*", chat_id, msg_id, reply_markup=main_menu_keyboard(), parse_mode="Markdown")
        
        elif data.startswith("prot_"):
            prot = data.split("_")[1]
            markup = InlineKeyboardMarkup(row_width=2)
            markup.add(InlineKeyboardButton("➕ Add", callback_data=f"act_add_{prot}"), InlineKeyboardButton("⏱️ Trial", callback_data=f"act_trial_{prot}"))
            markup.add(InlineKeyboardButton("📄 Detail", callback_data=f"act_detail_{prot}"), InlineKeyboardButton("📋 List", callback_data=f"act_list_{prot}"))
            markup.add(InlineKeyboardButton("🗑️ Del", callback_data=f"act_del_{prot}"), InlineKeyboardButton("🔄 Renew", callback_data=f"act_renew_{prot}"))
            markup.add(InlineKeyboardButton("🔙 Back", callback_data="menu_main"))
            bot.edit_message_text(f"🔧 *MANAGE {prot.upper()}*", chat_id, msg_id, reply_markup=markup, parse_mode="Markdown")
            
        elif data.startswith("act_"):
            p = data.split("_"); act, prot, api_ep = p[1], p[2], PROT_MAP.get(p[2])
            
            if act == "list":
                bot.answer_callback_query(call.id, "Sedang mengambil data...")
                bot.send_message(chat_id, get_list_accounts(prot), parse_mode="Markdown")
                
            elif act == "trial": 
                res = api_req(f"trial-{api_ep}", "POST", {"exp": 60})
                bot.send_message(chat_id, res, parse_mode="Markdown")
            else:
                if act == "add":
                    if prot in ['vmess', 'vless', 'trojan']: t = "✏️ Data: `User Expired(Hari) Limit_IP Limit_Quota`"
                    elif prot == "ssh": t = "✏️ Data: `User Pass Expired Limit_IP`"
                    else: t = "✏️ Data: `User Pass Expired`"
                    t += "\nContoh: `budi 30 2 50`"
                elif act == "renew": t = "🔄 `User Tambah(Hari)`"
                else: t = f"🗑️/📄 *{act.upper()}* `User`"
                
                msg = bot.send_message(chat_id, t, parse_mode="Markdown", reply_markup=telebot.types.ForceReply())
                bot.register_next_step_handler(msg, process_action_input, act, prot, api_ep)
    except Exception as e: bot.send_message(chat_id, f"Error: {e}")

def process_action_input(message, action, prot, api_ep):
    if not message.text: return
    parts = message.text.split(); payload = {}; method = "POST"; endpoint = f"{action}-{api_ep}"
    try:
        if action == "add":
            if prot in ['vmess', 'vless', 'trojan']:
                payload = {'user': parts[0], 'exp': int(parts[1]) if len(parts)>1 else 30, 'limit_ip': int(parts[2]) if len(parts)>2 else 0, 'limit_quota': int(parts[3]) if len(parts)>3 else 0}
            elif prot == "ssh":
                payload = {'user': parts[0], 'password': parts[1] if len(parts)>1 else "123", 'exp': int(parts[2]) if len(parts)>2 else 30, 'limit_ip': int(parts[3]) if len(parts)>3 else 0}
            elif prot == "l2tp":
                payload = {'user': parts[0], 'password': parts[1] if len(parts)>1 else "123", 'exp': int(parts[2]) if len(parts)>2 else 30}
        elif action == "renew": payload = {'user': parts[0], 'exp': int(parts[1]) if len(parts)>1 else 30}
        elif action == "del": payload = {'user': parts[0]}; method = "DELETE"
        elif action == "detail": payload = {'user': parts[0]}
        
        bot.send_message(message.chat.id, api_req(endpoint, method, payload), parse_mode="Markdown")
    except: bot.send_message(message.chat.id, "❌ Format salah!")

bot.infinity_polling()
