#!/usr/bin/env python3
# ==========================================
# bot-admin.py
# MODULE: TELEGRAM ADMIN INTERACTIVE BOT
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

# --- HANDLERS ---
@bot.message_handler(commands=['start', 'menu'])
def send_welcome(message):
    if not is_admin(message): return
    # markup logic here (as per current file)
    from telebot.types import InlineKeyboardMarkup, InlineKeyboardButton
    markup = InlineKeyboardMarkup(row_width=3)
    markup.add(InlineKeyboardButton("🚀 VMESS", callback_data="prot_vmess"), InlineKeyboardButton("🚀 VLESS", callback_data="prot_vless"), InlineKeyboardButton("🚀 TROJAN", callback_data="prot_trojan"))
    markup.add(InlineKeyboardButton("🔐 SSH / OVPN", callback_data="prot_ssh"), InlineKeyboardButton("🛡️ L2TP IPsec", callback_data="prot_l2tp"))
    markup.add(InlineKeyboardButton("📊 MONITORING", callback_data="menu_monitor"), InlineKeyboardButton("⚙️ STATUS & BACKUP", callback_data="menu_status"))
    bot.send_message(message.chat.id, "👋 *PANEL ADMIN VPS*", reply_markup=markup, parse_mode="Markdown")

@bot.callback_query_handler(func=lambda call: True)
def handle_query(call):
    if not is_admin(call.message): return
    data, chat_id, msg_id = call.data, call.message.chat.id, call.message.message_id
    try:
        if data == "menu_main": 
            # Re-send main menu (similar to send_welcome)
            from telebot.types import InlineKeyboardMarkup, InlineKeyboardButton
            markup = InlineKeyboardMarkup(row_width=3)
            markup.add(InlineKeyboardButton("🚀 VMESS", callback_data="prot_vmess"), InlineKeyboardButton("🚀 VLESS", callback_data="prot_vless"), InlineKeyboardButton("🚀 TROJAN", callback_data="prot_trojan"))
            markup.add(InlineKeyboardButton("🔐 SSH / OVPN", callback_data="prot_ssh"), InlineKeyboardButton("🛡️ L2TP IPsec", callback_data="prot_l2tp"))
            markup.add(InlineKeyboardButton("📊 MONITORING", callback_data="menu_monitor"), InlineKeyboardButton("⚙️ STATUS & BACKUP", callback_data="menu_status"))
            bot.edit_message_text("👋 *PANEL ADMIN VPS*", chat_id, msg_id, reply_markup=markup, parse_mode="Markdown")
        
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
                # (Logic from your current get_list_accounts function)
                bot.send_message(chat_id, "Feature List... (Update your python function here)", parse_mode="Markdown")
            elif act == "trial": 
                res = api_req(f"trial-{api_ep}", "POST", {"exp": 60})
                bot.send_message(chat_id, res, parse_mode="Markdown")
            else:
                t = f"✏️ Input data {act.upper()} {prot.upper()}\nContoh: `budi 30 2 50`"
                msg = bot.send_message(chat_id, t, parse_mode="Markdown", reply_markup=telebot.types.ForceReply())
                bot.register_next_step_handler(msg, process_action_input, act, prot, api_ep)
    except Exception as e: bot.send_message(chat_id, f"Error: {e}")

def process_action_input(message, action, prot, api_ep):
    if not message.text: return
    parts = message.text.split(); payload = {}; method = "POST"; endpoint = f"{action}-{api_ep}"
    try:
        payload = {'user': parts[0], 'exp': int(parts[1]) if len(parts)>1 else 30, 'limit_ip': int(parts[2]) if len(parts)>2 else 0, 'limit_quota': int(parts[3]) if len(parts)>3 else 0}
        if action == "del": method = "DELETE"
        # PENTING: parse_mode Markdown agar backtick berfungsi
        bot.send_message(message.chat.id, api_req(endpoint, method, payload), parse_mode="Markdown")
    except: bot.send_message(message.chat.id, "❌ Format salah!")

bot.infinity_polling()
