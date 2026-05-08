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

# Konfigurasi Path
CONF_FILE = '/usr/local/etc/xray/bot_admin.conf'
API_KEY_FILE = '/usr/local/etc/xray/api_key.conf'
API_BASE = 'http://127.0.0.1:5000/user_legend'

# Path Data Lokal
XRAY_CONF = '/usr/local/etc/xray/config.json'
EXP_FILE = '/usr/local/etc/xray/expiry.txt'
SSH_EXP = '/usr/local/etc/srpcom/ssh_expiry.txt'
L2TP_EXP = '/usr/local/etc/srpcom/l2tp_expiry.txt'

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

if not BOT_TOKEN or not ADMIN_ID:
    time.sleep(60)
    sys.exit(1)

def get_api_key():
    try:
        with open(API_KEY_FILE, 'r') as f: return f.read().strip()
    except: return "DEFAULT_KEY"

def load_json(p):
    if not os.path.exists(p): return {}
    with open(p, 'r') as f: return json.load(f)

# Inisialisasi Bot
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

# --- FUNGSI LOGIKA ---
def get_list_accounts(prot):
    result = []
    if prot in ['vmess', 'vless', 'trojan']:
        cfg = load_json(XRAY_CONF)
        prot_users = []
        for ib in cfg.get('inbounds', []):
            if ib.get('protocol') == prot:
                for c in ib['settings'].get('clients', []):
                    email = c.get('email')
                    if email: prot_users.append(email)
        
        if os.path.exists(EXP_FILE):
            with open(EXP_FILE, 'r') as f:
                for line in f:
                    parts = line.strip().split()
                    if len(parts) >= 1 and parts[0] in prot_users:
                        exp = " ".join(parts[1:]) if len(parts)>1 else "Lifetime"
                        result.append(f"• `{parts[0]}` (Exp: {exp})")
                
    elif prot == 'ssh' and os.path.exists(SSH_EXP):
        with open(SSH_EXP, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 3: result.append(f"• `{parts[0]}` (Exp: {parts[2]})")
                        
    elif prot == 'l2tp' and os.path.exists(L2TP_EXP):
        with open(L2TP_EXP, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 3: result.append(f"• `{parts[0]}` (Exp: {parts[2]})")

    if not result: return f"Belum ada akun aktif untuk protokol {prot.upper()}."
    return f"📋 *DAFTAR AKUN {prot.upper()}*\n━━━━━━━━━━━━━━━━━━━━\n" + "\n".join(result)

def handle_backup(chat_id):
    now = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_file = f"/tmp/srpcom-backup-{now}.tar.gz"
    files_to_backup = ["/usr/local/etc/xray/config.json", "/usr/local/etc/xray/expiry.txt", "/usr/local/etc/xray/limit.txt", "/usr/local/etc/xray/locked.json", "/usr/local/etc/xray/bot_setting.conf", "/usr/local/etc/srpcom/env.conf", "/usr/local/etc/srpcom/l2tp_expiry.txt", "/usr/local/etc/srpcom/ssh_expiry.txt", "/usr/local/etc/srpcom/ssh_limit.txt", "/etc/ppp/chap-secrets"]
    valid_files = [f for f in files_to_backup if os.path.exists(f)]
    if valid_files:
        try:
            cmd = ['tar', '-czf', backup_file, '-C', '/'] + [f.lstrip('/') for f in valid_files]
            subprocess.run(cmd, check=True)
            with open(backup_file, 'rb') as doc:
                bot.send_document(chat_id, doc, caption=f"📦 *BACKUP DATA VPS*\nTanggal: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}", parse_mode="Markdown")
            os.remove(backup_file)
        except Exception as e: bot.send_message(chat_id, f"Error backup: {e}")
    else: bot.send_message(chat_id, "Tidak ada database.")

def get_xray_usage():
    ip_data = {}
    try:
        log_lines = subprocess.run(['tail', '-n', '3000', '/var/log/xray/access.log'], capture_output=True, text=True).stdout.splitlines()
        for line in log_lines:
            if 'accepted' in line and '127.0.0.1' not in line:
                parts = line.split()
                if len(parts) >= 7:
                    user = parts[6]
                    ip = parts[2].replace('tcp:', '').replace('udp:', '').split(':')[0]
                    if user not in ip_data: ip_data[user] = set()
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
                if user not in stats: stats[user] = {'downlink': 0, 'uplink': 0}
                stats[user][name_parts[3]] = item.get('value', 0)
    except: pass
    limits = {}
    if os.path.exists('/usr/local/etc/xray/limit.txt'):
        with open('/usr/local/etc/xray/limit.txt', 'r') as f:
            for line in f:
                p = line.strip().split()
                if len(p) >= 3: limits[p[0]] = {'ip': int(p[1]), 'quota': int(p[2])}
    all_users = set(list(stats.keys()) + list(ip_data.keys()))
    if not all_users: return "Belum ada user aktif."
    res = ["📊 *PEMAKAIAN XRAY*"]
    res.append("`User | IP | Usage / Limit`\n━━━━━━━━━━━━━━━━━━━━")
    for u in sorted(all_users):
        active_ips = len(ip_data.get(u, set()))
        lim_ip = limits.get(u, {}).get('ip', 0)
        dl, ul = stats.get(u, {}).get('downlink', 0), stats.get(u, {}).get('uplink', 0)
        tot_gb = (dl + ul) / (1024**3)
        lim_q = limits.get(u, {}).get('quota', 0)
        res.append(f"• `{u}` | {active_ips}/{lim_ip if lim_ip>0 else 'Unli'} | {tot_gb:.2f}GB/{lim_q if lim_q>0 else 'Unli'}")
    return "\n".join(res)

# --- KEYBOARDS ---
def main_menu_keyboard():
    markup = InlineKeyboardMarkup(row_width=3)
    markup.add(InlineKeyboardButton("🚀 VMESS", callback_data="prot_vmess"), InlineKeyboardButton("🚀 VLESS", callback_data="prot_vless"), InlineKeyboardButton("🚀 TROJAN", callback_data="prot_trojan"))
    markup.add(InlineKeyboardButton("🔐 SSH / OVPN", callback_data="prot_ssh"), InlineKeyboardButton("🛡️ L2TP IPsec", callback_data="prot_l2tp"))
    markup.add(InlineKeyboardButton("📊 MONITORING", callback_data="menu_monitor"), InlineKeyboardButton("⚙️ STATUS & BACKUP", callback_data="menu_status"))
    return markup

def status_menu_keyboard():
    markup = InlineKeyboardMarkup(row_width=1)
    markup.add(InlineKeyboardButton("💻 CEK STATUS SERVICES", callback_data="sys_cek_status"), InlineKeyboardButton("📦 REQUEST BACKUP DATA", callback_data="sys_backup"), InlineKeyboardButton("🔄 RESTART ALL VPN", callback_data="sys_restart"), InlineKeyboardButton("🔙 KEMBALI", callback_data="menu_main"))
    return markup

def protocol_menu_keyboard(prot):
    markup = InlineKeyboardMarkup(row_width=2)
    markup.add(InlineKeyboardButton("➕ Create Account", callback_data=f"act_add_{prot}"), InlineKeyboardButton("⏱️ Create Trial", callback_data=f"act_trial_{prot}"))
    markup.add(InlineKeyboardButton("🔄 Renew Account", callback_data=f"act_renew_{prot}"), InlineKeyboardButton("🗑️ Delete Account", callback_data=f"act_del_{prot}"))
    markup.add(InlineKeyboardButton("📄 Detail Account", callback_data=f"act_detail_{prot}"), InlineKeyboardButton("📋 List Accounts", callback_data=f"act_list_{prot}"))
    markup.add(InlineKeyboardButton("🔙 KEMBALI", callback_data="menu_main"))
    return markup

def monitor_menu_keyboard():
    markup = InlineKeyboardMarkup(row_width=1)
    markup.add(InlineKeyboardButton("📊 Pemakaian Data & IP (Xray)", callback_data="mon_xray_usage"), InlineKeyboardButton("🔍 Cek SSH (IP Aktif)", callback_data="mon_cekssh"), InlineKeyboardButton("🔙 KEMBALI", callback_data="menu_main"))
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
        if data == "menu_main": bot.edit_message_text("👋 *PANEL ADMIN VPS*", chat_id, msg_id, reply_markup=main_menu_keyboard(), parse_mode="Markdown")
        elif data == "menu_monitor": bot.edit_message_text("📊 *MENU MONITORING*", chat_id, msg_id, reply_markup=monitor_menu_keyboard(), parse_mode="Markdown")
        elif data == "menu_status": bot.edit_message_text("⚙️ *MENU STATUS*", chat_id, msg_id, reply_markup=status_menu_keyboard(), parse_mode="Markdown")
        elif data == "sys_cek_status": bot.send_message(chat_id, f"💻 *STATUS SERVER:*\n{api_req('cek-xray', 'GET')}", parse_mode="Markdown")
        elif data == "sys_backup": handle_backup(chat_id)
        elif data == "sys_restart":
            subprocess.run(['systemctl', 'restart', 'xray', 'caddy', 'ipsec', 'xl2tpd', 'dropbear', 'ssh-ws', 'openvpn-server@server-udp', 'openvpn-server@server-tcp', 'badvpn-7100', 'badvpn-7200', 'badvpn-7300'])
            bot.send_message(chat_id, "✅ Layanan VPN Direstart!")
        elif data == "mon_xray_usage": bot.send_message(chat_id, get_xray_usage(), parse_mode="Markdown")
        elif data == "mon_cekssh": bot.send_message(chat_id, f"📊 *STATUS SSH:*\n{api_req('cek-ssh', 'GET')}", parse_mode="Markdown")
        elif data.startswith("prot_"): bot.edit_message_text(f"🔧 *MANAGE {data.split('_')[1].upper()}*", chat_id, msg_id, reply_markup=protocol_menu_keyboard(data.split('_')[1]), parse_mode="Markdown")
        elif data.startswith("act_"):
            p = data.split("_"); act, prot, api_ep = p[1], p[2], PROT_MAP.get(p[2])
            if act == "list": bot.send_message(chat_id, get_list_accounts(prot), parse_mode="Markdown")
            elif act == "trial":
                payload = {"exp": 60, "limit_ip": 1} if prot == "ssh" else {"exp": 60, "limit_ip": 1, "limit_quota": 1}
                bot.send_message(chat_id, api_req(f"trial-{api_ep}", "POST", payload), parse_mode="Markdown")
            else:
                if act == "add":
                    if prot in ['vmess', 'vless', 'trojan']: t = "✏️ `User Expired(Hari) Limit_IP Limit_Quota`"
                    elif prot == "ssh": t = "✏️ `User Pass Expired Limit_IP`"
                    else: t = "✏️ `User Pass Expired`"
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
        # Perbaikan: Kirim dengan parse_mode="Markdown" agar backtick berfungsi
        bot.send_message(message.chat.id, api_req(endpoint, method, payload), parse_mode="Markdown")
    except: bot.send_message(message.chat.id, "❌ Format input salah!")

bot.infinity_polling()
