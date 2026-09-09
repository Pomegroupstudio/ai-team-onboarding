#!/usr/bin/env python3
"""
telegram_muse_bridge.py — Autonomous Meta Muse Telegram Bridge
===============================================================
Control your local/remote Meta Muse coding agent directly from Telegram!
Zero external dependencies required (uses standard Python urllib & json).

Quickstart:
1. Message @BotFather on Telegram, create a bot, and get your BOT_TOKEN.
2. Set environment variables:
     export TELEGRAM_BOT_TOKEN="your_bot_token_here"
     export TELEGRAM_ALLOWED_USER_ID="your_telegram_user_id"  # (Optional but strongly recommended for security)
3. Run:
     python3 telegram_muse_bridge.py
"""

import os
import sys
import json
import time
import subprocess
import urllib.request
import urllib.parse

BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN")
ALLOWED_USER_ID = os.environ.get("TELEGRAM_ALLOWED_USER_ID")
MUSE_BIN = os.path.expanduser("~/.local/bin/muse")
WORKSPACE_DIR = os.path.dirname(os.path.abspath(__file__))

if not BOT_TOKEN:
    print("❌ Error: TELEGRAM_BOT_TOKEN environment variable is not set.")
    print("Usage:")
    print("  export TELEGRAM_BOT_TOKEN='123456789:ABCdefGhIJKlmNoPQRsTUVwxyZ'")
    print("  python3 telegram_muse_bridge.py")
    sys.exit(1)

BASE_URL = f"https://api.telegram.org/bot{BOT_TOKEN}"

def send_message(chat_id, text, parse_mode="Markdown"):
    """Send a message to a Telegram chat."""
    url = f"{BASE_URL}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": text,
    }
    if parse_mode:
        payload["parse_mode"] = parse_mode

    data = urllib.parse.urlencode(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        # Fallback without markdown if markdown parsing fails
        if parse_mode:
            return send_message(chat_id, text, parse_mode=None)
        print(f"Failed to send message: {e}")
        return None

def execute_muse(prompt):
    """Run muse exec in the workspace and capture stdout/stderr."""
    cmd = [MUSE_BIN, "exec", "--yolo", prompt]
    try:
        result = subprocess.run(
            cmd,
            cwd=WORKSPACE_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=300  # 5 min cap per task
        )
        return result.stdout.strip()
    except subprocess.TimeoutExpired:
        return "❌ Error: Muse task timed out after 5 minutes."
    except Exception as e:
        return f"❌ Execution error: {e}"

def get_git_status():
    """Get current git status and modified files."""
    try:
        res = subprocess.run(
            ["git", "status", "--short"],
            cwd=WORKSPACE_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        return res.stdout.strip() or "Clean working directory (no modified files)."
    except Exception as e:
        return f"Git error: {e}"

def main():
    print("==================================================")
    print("  🤖 Meta Muse Telegram Autonomous Bridge Active   ")
    print("==================================================")
    print(f"Workspace: {WORKSPACE_DIR}")
    print(f"Muse Binary: {MUSE_BIN}")
    if ALLOWED_USER_ID:
        print(f"Security: Restricted to User ID {ALLOWED_USER_ID}")
    else:
        print("⚠️ Warning: TELEGRAM_ALLOWED_USER_ID not set. Any user who finds this bot can send commands!")
    print("Listening for incoming Telegram commands...\n")

    offset = 0

    while True:
        try:
            url = f"{BASE_URL}/getUpdates?offset={offset}&timeout=25"
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, timeout=30) as resp:
                data = json.loads(resp.read().decode("utf-8"))

            if not data.get("ok"):
                time.sleep(2)
                continue

            for update in data.get("result", []):
                offset = update["update_id"] + 1
                message = update.get("message")
                if not message or "text" not in message:
                    continue

                chat_id = message["chat"]["id"]
                user_id = str(message["from"]["id"])
                user_name = message["from"].get("username", "Unknown")
                text = message["text"].strip()

                # Security check
                if ALLOWED_USER_ID and user_id != str(ALLOWED_USER_ID):
                    print(f"Unauthorized access attempt from @{user_name} (ID: {user_id})")
                    send_message(chat_id, f"⛔ Unauthorized. Your Telegram User ID is `{user_id}`. Add it to `TELEGRAM_ALLOWED_USER_ID`.", parse_mode="Markdown")
                    continue

                print(f"[{user_name}] {text}")

                if text == "/start" or text == "/help":
                    help_msg = (
                        "🤖 *Meta Muse Autonomous Coding Bridge*\n\n"
                        "Send me any task and I will execute it on your repository using Meta Muse!\n\n"
                        "*Available Commands:*\n"
                        "• `/task <prompt>` — Execute an autonomous task\n"
                        "• `/status` — View git status and modified files\n"
                        "• `/diff` — View git diff of recent changes\n"
                        "• Or simply send your coding prompt directly!\n\n"
                        "_Example:_ `/task Add dark mode toggle to pomodoro.html`"
                    )
                    send_message(chat_id, help_msg)

                elif text == "/status":
                    status = get_git_status()
                    send_message(chat_id, f"📁 *Git Status:*\n```\n{status}\n```")

                elif text == "/diff":
                    try:
                        diff = subprocess.run(["git", "diff", "--stat"], cwd=WORKSPACE_DIR, stdout=subprocess.PIPE, text=True).stdout
                        send_message(chat_id, f"📝 *Recent Changes:*\n```\n{diff or 'No uncommitted changes'}\n```")
                    except Exception as e:
                        send_message(chat_id, f"Error reading diff: {e}")

                else:
                    prompt = text
                    if prompt.startswith("/task"):
                        prompt = prompt[len("/task"):].strip()

                    if not prompt:
                        send_message(chat_id, "Please provide a prompt. Example: `/task refactor script.js`")
                        continue

                    send_message(chat_id, f"⚡ *Muse is working on your task...*\n_{prompt}_")

                    # Run autonomous muse task
                    output = execute_muse(prompt)

                    # Truncate if output exceeds Telegram's 4000 char message limit
                    if len(output) > 3800:
                        output = output[:3800] + "\n... [truncated]"

                    git_stat = get_git_status()
                    reply = (
                        "✅ *Task Finished!*\n\n"
                        f"*Muse Output:*\n```\n{output}\n```\n\n"
                        f"*Workspace Changes:*\n```\n{git_stat}\n```"
                    )
                    send_message(chat_id, reply)

        except urllib.error.URLError as e:
            time.sleep(3)
        except Exception as e:
            print(f"Error in polling loop: {e}")
            time.sleep(3)

if __name__ == "__main__":
    main()
