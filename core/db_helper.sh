#!/bin/bash
# ==========================================
# db_helper.sh
# MODULE: SQLITE DATABASE UTILITY HELPER
# ==========================================

DB_PATH="/var/lib/srpcom/srpcom.db"
mkdir -p "$(dirname "$DB_PATH")"

db_init() {
    sqlite3 "$DB_PATH" <<EOF
CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    protocol TEXT NOT NULL,
    uuid_password TEXT,
    expired_date TEXT NOT NULL,
    limit_ip INTEGER DEFAULT 0,
    limit_quota INTEGER DEFAULT 0,
    status TEXT DEFAULT 'ACTIVE',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS lock_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    reason TEXT NOT NULL,
    locked_at TEXT NOT NULL,
    client_data TEXT
);
EOF
}

db_query() {
    sqlite3 "$DB_PATH" "$1"
}

db_import_from_txt() {
    db_init
    
    # 1. Import Xray Expiry & Limits
    if [ -f "/usr/local/etc/xray/expiry.txt" ]; then
        while read -r u exp_d exp_t; do
            [ -z "$u" ] && continue
            
            # Find protocol and UUID from config.json if possible
            prot=$(jq -r --arg email "$u" '.inbounds[] | select(.settings.clients != null) | select(.settings.clients[].email == $email) | .protocol' /usr/local/etc/xray/config.json 2>/dev/null | head -n 1)
            prot=${prot:-vmess}
            uuid=$(jq -r --arg email "$u" '.inbounds[] | select(.settings.clients != null) | .settings.clients[] | select(.email == $email) | .id' /usr/local/etc/xray/config.json 2>/dev/null | head -n 1)
            [ "$uuid" == "null" ] && uuid=$(jq -r --arg email "$u" '.inbounds[] | select(.settings.clients != null) | .settings.clients[] | select(.email == $email) | .password' /usr/local/etc/xray/config.json 2>/dev/null | head -n 1)
            [ "$uuid" == "null" ] && uuid=""
            
            # Read limit ip and quota
            lim_data=$(grep -w "^$u" /usr/local/etc/xray/limit.txt 2>/dev/null)
            lim_ip=$(echo "$lim_data" | awk '{print $2}')
            lim_q=$(echo "$lim_data" | awk '{print $3}')
            lim_ip=${lim_ip:-0}
            lim_q=${lim_q:-0}
            
            # Check if user is locked
            status="ACTIVE"
            if [ -f "/usr/local/etc/xray/locked.json" ] && [ -s "/usr/local/etc/xray/locked.json" ]; then
                is_locked=$(jq -r --arg u "$u" '.[$u]' /usr/local/etc/xray/locked.json 2>/dev/null)
                if [ -n "$is_locked" ] && [ "$is_locked" != "null" ]; then
                    status="LOCKED"
                    reason=$(jq -r --arg u "$u" '.[$u].reason' /usr/local/etc/xray/locked.json 2>/dev/null)
                    locked_at=$(jq -r --arg u "$u" '.[$u].locked_at' /usr/local/etc/xray/locked.json 2>/dev/null)
                    client_data=$(jq -c --arg u "$u" '.[$u].client_data' /usr/local/etc/xray/locked.json 2>/dev/null)
                    
                    # insert to lock history
                    sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO lock_history (username, reason, locked_at, client_data) VALUES ('$u', '$reason', '$locked_at', '$client_data');"
                fi
            fi
            
            if [ "$status" != "LOCKED" ]; then
                sqlite3 "$DB_PATH" "DELETE FROM lock_history WHERE username='$u';"
            fi
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO accounts (username, protocol, uuid_password, expired_date, limit_ip, limit_quota, status) VALUES ('$u', '$prot', '$uuid', '$exp_d $exp_t', $lim_ip, $lim_q, '$status');"
        done < /usr/local/etc/xray/expiry.txt
    fi

    # 2. Import SSH Accounts
    if [ -f "/usr/local/etc/srpcom/ssh_expiry.txt" ]; then
        while read -r u pass exp_d exp_t; do
            [ -z "$u" ] && continue
            lim_ip=$(grep -w "^$u" /usr/local/etc/srpcom/ssh_limit.txt 2>/dev/null | awk '{print $2}')
            lim_ip=${lim_ip:-0}
            
            status="ACTIVE"
            passwd_status=$(passwd -S "$u" 2>/dev/null | awk '{print $2}')
            if [[ "$passwd_status" == "L" || "$passwd_status" == "LK" ]]; then
                status="LOCKED"
            fi
            
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO accounts (username, protocol, uuid_password, expired_date, limit_ip, limit_quota, status) VALUES ('$u', 'ssh', '$pass', '$exp_d $exp_t', $lim_ip, 0, '$status');"
        done < /usr/local/etc/srpcom/ssh_expiry.txt
    fi

    # 3. Import L2TP Accounts
    if [ -f "/usr/local/etc/srpcom/l2tp_expiry.txt" ]; then
        while read -r u pass exp_d exp_t; do
            [ -z "$u" ] && continue
            sqlite3 "$DB_PATH" "INSERT OR REPLACE INTO accounts (username, protocol, uuid_password, expired_date, limit_ip, limit_quota, status) VALUES ('$u', 'l2tp', '$pass', '$exp_d $exp_t', 0, 0, 'ACTIVE');"
        done < /usr/local/etc/srpcom/l2tp_expiry.txt
    fi
}

db_export_to_txt() {
    # Export SQLite back to text files for backwards compatibility (e.g. backup)
    mkdir -p /usr/local/etc/xray
    mkdir -p /usr/local/etc/srpcom
    
    # 1. Clear files
    > /usr/local/etc/xray/expiry.txt
    > /usr/local/etc/xray/limit.txt
    > /usr/local/etc/srpcom/ssh_expiry.txt
    > /usr/local/etc/srpcom/ssh_limit.txt
    > /usr/local/etc/srpcom/l2tp_expiry.txt
    
    # 2. Export Xray
    sqlite3 "$DB_PATH" "SELECT username, expired_date FROM accounts WHERE protocol IN ('vmess', 'vless', 'trojan');" | while IFS='|' read -r u exp; do
        [ -z "$u" ] && continue
        echo "$u $exp" >> /usr/local/etc/xray/expiry.txt
    done
    sqlite3 "$DB_PATH" "SELECT username, limit_ip, limit_quota FROM accounts WHERE protocol IN ('vmess', 'vless', 'trojan');" | while IFS='|' read -r u lip lq; do
        [ -z "$u" ] && continue
        echo "$u $lip $lq" >> /usr/local/etc/xray/limit.txt
    done
    
    # 3. Export SSH
    sqlite3 "$DB_PATH" "SELECT username, uuid_password, expired_date FROM accounts WHERE protocol = 'ssh';" | while IFS='|' read -r u pass exp; do
        [ -z "$u" ] && continue
        echo "$u $pass $exp" >> /usr/local/etc/srpcom/ssh_expiry.txt
    done
    sqlite3 "$DB_PATH" "SELECT username, limit_ip FROM accounts WHERE protocol = 'ssh';" | while IFS='|' read -r u lip; do
        [ -z "$u" ] && continue
        echo "$u $lip" >> /usr/local/etc/srpcom/ssh_limit.txt
    done
    
    # 4. Export L2TP
    sqlite3 "$DB_PATH" "SELECT username, uuid_password, expired_date FROM accounts WHERE protocol = 'l2tp';" | while IFS='|' read -r u pass exp; do
        [ -z "$u" ] && continue
        echo "$u $pass $exp" >> /usr/local/etc/srpcom/l2tp_expiry.txt
    done
    
    # 5. Export locked.json
    locked_count=$(sqlite3 "$DB_PATH" "SELECT count(*) FROM accounts WHERE status='LOCKED' AND protocol IN ('vmess', 'vless', 'trojan');")
    if [ "$locked_count" -gt 0 ]; then
        echo "{" > /usr/local/etc/xray/locked.json
        first=true
        sqlite3 "$DB_PATH" "SELECT username, reason, locked_at, client_data FROM lock_history WHERE username IN (SELECT username FROM accounts WHERE status='LOCKED');" | while IFS='|' read -r u r t c; do
            [ -z "$u" ] && continue
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> /usr/local/etc/xray/locked.json
            fi
            echo "  \"$u\": {\"user\": \"$u\", \"reason\": \"$r\", \"locked_at\": \"$t\", \"client_data\": $c}" >> /usr/local/etc/xray/locked.json
        done
        echo "}" >> /usr/local/etc/xray/locked.json
    else
        echo "{}" > /usr/local/etc/xray/locked.json
    fi
}

# Allow direct executions of functions from external scripts
if [ -n "$1" ]; then
    "$@"
fi
