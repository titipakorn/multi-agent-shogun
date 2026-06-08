#!/usr/bin/env python3
import sys
import os
import time
import json
import urllib.request
import urllib.error
import subprocess

def load_env(env_path):
    env_vars = {}
    if os.path.exists(env_path):
        with open(env_path, 'r', encoding='utf-8') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if '=' in line:
                    key, val = line.split('=', 1)
                    env_vars[key.strip()] = val.strip()
    return env_vars

def make_telegram_request(token, method, payload=None):
    url = f"https://api.telegram.org/bot{token}/{method}"
    headers = {"Content-Type": "application/json"}
    data = json.dumps(payload).encode('utf-8') if payload else None
    req = urllib.request.Request(url, data=data, headers=headers, method="POST" if payload else "GET")
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            return json.loads(res.read().decode('utf-8'))
    except Exception as e:
        return {"ok": False, "description": str(e)}

def append_to_inbox(inbox_path, msg_id, msg_text):
    import yaml
    
    entry = {
        "id": str(msg_id),
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "message": msg_text,
        "status": "pending"
    }
    
    data = {"inbox": []}
    if os.path.exists(inbox_path):
        try:
            with open(inbox_path, "r", encoding="utf-8") as f:
                loaded = yaml.safe_load(f)
                if isinstance(loaded, dict) and "inbox" in loaded:
                    data = loaded
        except Exception:
            pass
            
    if not isinstance(data.get("inbox"), list):
        data["inbox"] = []
        
    data["inbox"].append(entry)
    
    # Write atomically
    temp_path = inbox_path + ".tmp"
    with open(temp_path, "w", encoding="utf-8") as f:
        yaml.safe_dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
    os.replace(temp_path, inbox_path)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    env_path = os.path.join(script_dir, "../config/telegram.env")
    env = load_env(env_path)

    token = os.environ.get("TELEGRAM_BOT_TOKEN") or env.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID") or env.get("TELEGRAM_CHAT_ID")

    if not token or not chat_id or "your_bot_token_here" in token or "your_chat_id_here" in chat_id:
        print("[telegram_listener] Telegram credentials not configured. Exiting.", file=sys.stderr)
        sys.exit(1)

    print(f"[telegram_listener] Starting Telegram listener (Chat ID: {chat_id})...")

    # Register slash commands with Telegram
    commands_payload = {
        "commands": [
            {"command": "status", "description": "Get live dashboard and agent status"},
            {"command": "dashboard", "description": "Display current dashboard summary"},
            {"command": "help", "description": "Show usage instructions and routing help"}
        ]
    }
    register_res = make_telegram_request(token, "setMyCommands", commands_payload)
    if register_res.get("ok"):
        print("[telegram_listener] Successfully registered slash commands with Telegram.")
    else:
        print(f"[telegram_listener] Warning: Failed to register slash commands: {register_res.get('description')}")

    # Get current offset (only process messages sent after listener startup)
    updates_res = make_telegram_request(token, "getUpdates", {"limit": 1})
    offset = 0
    if updates_res.get("ok") and updates_res.get("result"):
        offset = updates_res["result"][-1]["update_id"] + 1

    inbox_path = os.path.join(script_dir, "../queue/ntfy_inbox.yaml")

    while True:
        try:
            poll_payload = {
                "offset": offset,
                "timeout": 30,
                "allowed_updates": ["message"]
            }
            poll_res = make_telegram_request(token, "getUpdates", poll_payload)

            if not poll_res.get("ok"):
                time.sleep(5)
                continue

            for update in poll_res.get("result", []):
                offset = update["update_id"] + 1
                
                if "message" in update:
                    msg = update["message"]
                    msg_chat_id = msg.get("chat", {}).get("id")
                    
                    # Only accept messages from the authorized chat
                    if str(msg_chat_id) != str(chat_id):
                        continue
                        
                    # Ignore replies (which are handled by telegram_ask.py)
                    if "reply_to_message" in msg:
                        continue
                        
                    msg_text = msg.get("text", "").strip()
                    if not msg_text:
                        continue
                        
                    msg_id = msg.get("message_id")
                    print(f"[telegram_listener] Received command: {msg_text}")
                    
                    # Write to the inbox file
                    append_to_inbox(inbox_path, msg_id, msg_text)
                    
                    # Signal Shogun to wake up
                    inbox_write_path = os.path.join(script_dir, "inbox_write.sh")
                    subprocess.run([
                        "bash", inbox_write_path, "shogun",
                        f"Received new command from Telegram: {msg_text}",
                        "ntfy_received", "telegram_listener"
                    ], check=True)
                    
            time.sleep(1)
        except Exception as e:
            print(f"[telegram_listener] Error: {e}", file=sys.stderr)
            time.sleep(5)

if __name__ == "__main__":
    main()
