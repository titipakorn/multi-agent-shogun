#!/usr/bin/env python3
import sys
import os
import argparse
import time
import json
import urllib.request
import urllib.error

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
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode('utf-8')
        try:
            err_json = json.loads(err_msg)
            return {"ok": False, "description": err_json.get("description", str(e))}
        except Exception:
            return {"ok": False, "description": f"HTTP Error {e.code}: {e.reason}"}
    except Exception as e:
        return {"ok": False, "description": str(e)}

def main():
    parser = argparse.ArgumentParser(description="Ask the user a question via Telegram and block until answered.")
    parser.add_argument("--question", required=True, help="The question text to ask.")
    parser.add_argument("--options", nargs="+", help="Multiple-choice options. If omitted, waits for a text reply.")
    parser.add_argument("--timeout", type=int, default=3600, help="Timeout in seconds (default: 3600).")
    args = parser.parse_args()

    # Load credentials
    script_dir = os.path.dirname(os.path.abspath(__file__))
    env_path = os.path.join(script_dir, "../config/telegram.env")
    env = load_env(env_path)

    token = os.environ.get("TELEGRAM_BOT_TOKEN") or env.get("TELEGRAM_BOT_TOKEN")
    chat_id = os.environ.get("TELEGRAM_CHAT_ID") or env.get("TELEGRAM_CHAT_ID")

    if not token or not chat_id or "your_bot_token_here" in token or "your_chat_id_here" in chat_id:
        print("ERROR: Telegram credentials not configured. Please create config/telegram.env or set TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID.", file=sys.stderr)
        sys.exit(1)

    # Write to current_question.json for Shogun panel feedback
    question_file = os.path.join(script_dir, "../queue/current_question.json")
    question_data = {
        "question": args.question,
        "options": args.options or [],
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "status": "pending"
    }
    try:
        with open(question_file, "w", encoding="utf-8") as f:
            json.dump(question_data, f, indent=2, ensure_ascii=False)
    except Exception as e:
        print(f"WARNING: Failed to write to {question_file}: {e}", file=sys.stderr)

    def cleanup_question_file():
        try:
            if os.path.exists(question_file):
                os.remove(question_file)
        except Exception:
            pass

    # 1. Get the current latest update_id to set offset
    updates_res = make_telegram_request(token, "getUpdates", {"limit": 1, "allowed_updates": ["message", "callback_query"]})
    offset = 0
    if updates_res.get("ok") and updates_res.get("result"):
        offset = updates_res["result"][-1]["update_id"] + 1

    # 2. Send the question
    payload = {
        "chat_id": chat_id,
        "text": f"❓ *Question:*\n{args.question}",
        "parse_mode": "Markdown"
    }

    if args.options:
        keyboard = []
        for idx, opt in enumerate(args.options):
            keyboard.append([{"text": opt, "callback_data": f"opt_{idx}"}])
        # Append "Other (free text)" option as the last choice
        keyboard.append([{"text": "✏️ Other (free text)", "callback_data": "opt_other"}])
        payload["reply_markup"] = {"inline_keyboard": keyboard}

    send_res = make_telegram_request(token, "sendMessage", payload)
    if not send_res.get("ok"):
        print(f"ERROR: Failed to send message to Telegram: {send_res.get('description')}", file=sys.stderr)
        cleanup_question_file()
        sys.exit(1)

    sent_message_id = send_res["result"]["message_id"]
    start_time = time.time()
    waiting_for_free_text = False

    # 3. Poll for the answer
    try:
        while True:
            if time.time() - start_time > args.timeout:
                print("ERROR: Timeout waiting for user response on Telegram.", file=sys.stderr)
                sys.exit(1)

            # Long poll updates
            poll_payload = {
                "offset": offset,
                "timeout": 10,
                "allowed_updates": ["message", "callback_query"]
            }
            poll_res = make_telegram_request(token, "getUpdates", poll_payload)

            if not poll_res.get("ok"):
                time.sleep(2)
                continue

            for update in poll_res.get("result", []):
                offset = update["update_id"] + 1

                # Option A: Callback query (button tap)
                if "callback_query" in update:
                    cb = update["callback_query"]
                    cb_msg = cb.get("message", {})
                    if cb_msg.get("message_id") == sent_message_id:
                        data = cb.get("data", "")
                        
                        if data == "opt_other":
                            # Acknowledge the callback
                            make_telegram_request(token, "answerCallbackQuery", {"callback_query_id": cb["id"], "text": "Please type your response."})
                            
                            # Edit original message to remove buttons and prompt for text input
                            new_text = f"❓ *Question:*\n{args.question}\n\n✏️ *Please type your custom reply below:*"
                            make_telegram_request(token, "editMessageText", {
                                "chat_id": chat_id,
                                "message_id": sent_message_id,
                                "text": new_text,
                                "parse_mode": "Markdown"
                            })
                            waiting_for_free_text = True
                            continue
                            
                        elif data.startswith("opt_"):
                            try:
                                opt_idx = int(data.split("_")[1])
                                selected_option = args.options[opt_idx]
                            except Exception:
                                selected_option = data

                            # Acknowledge the callback
                            make_telegram_request(token, "answerCallbackQuery", {"callback_query_id": cb["id"], "text": f"Selected: {selected_option}"})

                            # Edit the message to show selection and remove buttons
                            new_text = f"❓ *Question:*\n{args.question}\n\n✅ *Selected:* {selected_option}"
                            make_telegram_request(token, "editMessageText", {
                                "chat_id": chat_id,
                                "message_id": sent_message_id,
                                "text": new_text,
                                "parse_mode": "Markdown"
                            })

                            # Return selected option
                            print(selected_option)
                            sys.exit(0)

                # Option B: Direct text reply or waiting for free text from the user
                elif "message" in update:
                    msg = update["message"]
                    msg_chat_id = msg.get("chat", {}).get("id")
                    
                    if str(msg_chat_id) == str(chat_id):
                        reply_to = msg.get("reply_to_message", {})
                        is_reply = reply_to.get("message_id") == sent_message_id
                        
                        if is_reply or waiting_for_free_text:
                            reply_text = msg.get("text", "").strip()
                            if reply_text:
                                # Confirm receipt by editing the original message to show the reply
                                new_text = f"❓ *Question:*\n{args.question}\n\n✅ *Reply:* {reply_text}"
                                make_telegram_request(token, "editMessageText", {
                                    "chat_id": chat_id,
                                    "message_id": sent_message_id,
                                    "text": new_text,
                                    "parse_mode": "Markdown"
                                })

                                print(reply_text)
                                sys.exit(0)

            time.sleep(1)

    except KeyboardInterrupt:
        print("Interrupted.", file=sys.stderr)
        sys.exit(1)
    finally:
        cleanup_question_file()

if __name__ == "__main__":
    main()
