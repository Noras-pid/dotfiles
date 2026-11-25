#!/usr/bin/env python3
"""orrery-agent usage-update — collect coding-agent usage into one JSON file.

Writes ~/.local/state/orrery/agents.json:
  {
    "updated": <epoch>,
    "accounts": [ { id, name, plan, limits: [ {name, percent, resets_at} ],
                    extra: {enabled, used, limit} | null, error } ],
    "tokens": { "days": [ {date, total, output} ... 7 ], "models": [ {model, total, output} ] }
  }

Providers are functions returning an account dict (or None when the agent is
not set up on this machine). Add one for another agent and it appears in
the panel. Only the local credential files are read; nothing is written to
them — if a token has expired the account is reported as such, and running
the agent once refreshes it.
"""
import glob, json, os, sys, time, urllib.request
from datetime import datetime, timedelta, timezone

HOME = os.path.expanduser("~")
STATE = os.path.join(HOME, ".local/state/orrery")
OUT = os.path.join(STATE, "agents.json")


# ---------------------------------------------------------------- Claude Code
def claude():
    cred = os.path.join(HOME, ".claude/.credentials.json")
    if not os.path.exists(cred):
        return None
    acct = {"id": "claude", "name": "Claude Code", "plan": "", "limits": [], "extra": None, "error": ""}
    try:
        oauth = json.load(open(cred)).get("claudeAiOauth") or {}
    except (OSError, ValueError) as e:
        acct["error"] = f"credentials unreadable: {e}"
        return acct
    plan = oauth.get("subscriptionType") or ""
    acct["plan"] = {"pro": "Pro", "max": "Max", "team": "Team", "enterprise": "Enterprise"}.get(plan, plan.title())
    token = oauth.get("accessToken")
    if not token:
        acct["error"] = "not logged in — run claude"
        return acct
    if oauth.get("expiresAt", 0) / 1000 < time.time():
        acct["error"] = "token expired — run claude once to refresh"
        return acct
    req = urllib.request.Request(
        "https://api.anthropic.com/api/oauth/usage",
        headers={"Authorization": f"Bearer {token}", "anthropic-beta": "oauth-2025-04-20",
                 "Accept": "application/json", "User-Agent": "orrery-agent"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            d = json.load(r)
    except Exception as e:  # network, 401, 429, …
        code = getattr(e, "code", None)
        acct["error"] = ("Usage is rate-limited for a moment; it refreshes on its own" if code == 429
                         else "Sign-in expired: run claude once to refresh it" if code in (401, 403)
                         else f"Couldn't reach the usage service ({code})" if code
                         else "Couldn't reach the usage service (offline?)")
        return acct
    names = {"five_hour": "Session (5h)", "seven_day": "Weekly", "seven_day_opus": "Weekly · Opus",
             "seven_day_sonnet": "Weekly · Sonnet", "seven_day_oauth_apps": "Weekly · apps"}
    for key, label in names.items():
        v = d.get(key)
        if isinstance(v, dict) and v.get("utilization") is not None:
            acct["limits"].append({"name": label, "percent": round(v["utilization"]),
                                   "resets_at": v.get("resets_at") or ""})
    x = d.get("extra_usage") or {}
    if x.get("is_enabled"):
        acct["extra"] = {"enabled": True, "used": x.get("used_credits"), "limit": x.get("monthly_limit"),
                         "percent": x.get("utilization"), "currency": x.get("currency") or "USD"}
    return acct


# --------------------------------------------------- local token counts (Claude)
def claude_tokens(days=7):
    """Sum token usage from Claude Code's transcripts (~/.claude/projects),
    by day and by model, over the last `days` days. Streams are written as
    several lines per response sharing a requestId, so count each once."""
    since = datetime.now(timezone.utc) - timedelta(days=days)
    since_s = since.timestamp()
    by_day, by_model, seen = {}, {}, set()
    for f in glob.glob(os.path.join(HOME, ".claude/projects/*/*.jsonl")):
        try:
            if os.path.getmtime(f) < since_s:
                continue
            with open(f, "rb") as fh:
                for line in fh:
                    if b'"usage"' not in line:
                        continue
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    m = e.get("message") or {}
                    u = m.get("usage")
                    if not u or e.get("type") != "assistant":
                        continue
                    key = e.get("requestId") or m.get("id")
                    if key in seen:
                        continue
                    seen.add(key)
                    ts = e.get("timestamp", "")
                    try:
                        t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                    except ValueError:
                        continue
                    if t < since:
                        continue
                    out = u.get("output_tokens", 0)
                    total = (u.get("input_tokens", 0) + out + u.get("cache_read_input_tokens", 0)
                             + u.get("cache_creation_input_tokens", 0))
                    day = t.astimezone().strftime("%Y-%m-%d")
                    dd = by_day.setdefault(day, {"date": day, "total": 0, "output": 0})
                    dd["total"] += total; dd["output"] += out
                    model = (m.get("model") or "unknown").replace("claude-", "")
                    if model.startswith("<"):   # <synthetic> — no tokens
                        continue
                    mm = by_model.setdefault(model, {"model": model, "total": 0, "output": 0})
                    mm["total"] += total; mm["output"] += out
        except OSError:
            continue
    today = datetime.now().date()
    days_out = []
    for i in range(days - 1, -1, -1):
        d = (today - timedelta(days=i)).strftime("%Y-%m-%d")
        days_out.append(by_day.get(d, {"date": d, "total": 0, "output": 0}))
    models = sorted(by_model.values(), key=lambda x: -x["total"])
    return {"days": days_out, "models": models}


def codex_tokens(days=7):
    """Sum token usage from Codex's session logs (~/.codex/sessions/**.jsonl),
    by day and by model. Each `token_count` event carries the thread's running
    total, so a request's use is the step from the previous total (repeats
    add nothing); the model comes from the latest `turn_context`."""
    since = datetime.now(timezone.utc) - timedelta(days=days)
    since_s = since.timestamp()
    by_day, by_model = {}, {}
    for f in glob.glob(os.path.join(HOME, ".codex/sessions/**/*.jsonl"), recursive=True):
        try:
            if os.path.getmtime(f) < since_s:
                continue
            model, last_total, last_out = "unknown", 0, 0
            with open(f, "rb") as fh:
                for line in fh:
                    if b'"turn_context"' not in line and b'"token_count"' not in line:
                        continue
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    p = e.get("payload") or {}
                    if e.get("type") == "turn_context":
                        model = p.get("model") or model
                        continue
                    if p.get("type") != "token_count" or not p.get("info"):
                        continue
                    tu = p["info"].get("total_token_usage") or {}
                    total, out = tu.get("total_tokens", 0), tu.get("output_tokens", 0)
                    step, step_out = total - last_total, out - last_out
                    if step <= 0:
                        continue
                    last_total, last_out = total, out
                    try:
                        t = datetime.fromisoformat(e.get("timestamp", "").replace("Z", "+00:00"))
                    except ValueError:
                        continue
                    if t < since:
                        continue
                    day = t.astimezone().strftime("%Y-%m-%d")
                    dd = by_day.setdefault(day, {"date": day, "total": 0, "output": 0})
                    dd["total"] += step; dd["output"] += max(0, step_out)
                    mm = by_model.setdefault(model, {"model": model, "total": 0, "output": 0})
                    mm["total"] += step; mm["output"] += max(0, step_out)
        except OSError:
            continue
    today = datetime.now().date()
    days_out = []
    for i in range(days - 1, -1, -1):
        d = (today - timedelta(days=i)).strftime("%Y-%m-%d")
        days_out.append(by_day.get(d, {"date": d, "total": 0, "output": 0}))
    models = sorted(by_model.values(), key=lambda x: -x["total"])
    return {"days": days_out, "models": models}


# Desktop session is read in memory. Only usage numbers enter the state file.
def claude_desktop():
    acct = {"id": "claude", "name": "Claude", "plan": "", "limits": [], "extra": None, "error": ""}
    cookie_path = os.path.join(HOME, ".config/Claude/Cookies")
    if not os.path.exists(cookie_path):
        return claude() or dict(acct, error="Открой Claude и войди в аккаунт.")
    try:
        import hashlib, sqlite3, secretstorage
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        from cryptography.hazmat.primitives.padding import PKCS7
        from curl_cffi import requests
        bus = secretstorage.dbus_init()
        items = [item for item in secretstorage.search_items(bus, {
            "application": "Claude", "xdg:schema": "chrome_libsecret_os_crypt_password_v2"
        }) if not item.is_locked()]
        if not items:
            acct["error"] = "Хранилище Claude заблокировано. Открой приложение и обнови лимиты."
            return acct
        key = hashlib.pbkdf2_hmac("sha1", items[0].get_secret(), b"saltysalt", 1, 16)
        cookies = {}
        with sqlite3.connect("file:" + cookie_path + "?mode=ro", uri=True, timeout=2) as db:
            rows = db.execute("SELECT host_key,name,value,encrypted_value FROM cookies WHERE host_key IN ('.claude.ai','claude.ai') AND name IN ('sessionKey','lastActiveOrg') ORDER BY last_access_utc").fetchall()
        for host, name, value, encrypted in rows:
            if not value:
                if encrypted[:3] != b"v11":
                    continue
                decrypt = Cipher(algorithms.AES(key), modes.CBC(b" " * 16)).decryptor()
                raw = decrypt.update(encrypted[3:]) + decrypt.finalize()
                padding = PKCS7(128).unpadder()
                raw = padding.update(raw) + padding.finalize()
                if raw.startswith(hashlib.sha256(host.encode()).digest()):
                    raw = raw[32:]
                value = raw.decode()
            cookies[name] = value
        if not cookies.get("sessionKey") or not cookies.get("lastActiveOrg"):
            acct["error"] = "Открой Claude и войди в аккаунт."
            return acct
        import uuid
        org = str(uuid.UUID(cookies["lastActiveOrg"]))
        response = requests.get("https://claude.ai/api/organizations/" + org + "/usage",
            cookies={"sessionKey": cookies["sessionKey"]}, impersonate="chrome",
            headers={"Accept": "application/json", "Referer": "https://claude.ai/settings/usage"}, timeout=15)
        if response.status_code != 200:
            acct["error"] = ("Слишком частые запросы. Обновление повторится позже." if response.status_code == 429
                else "Открой Claude и проверь вход в аккаунт." if response.status_code in (401, 403)
                else "Сервис лимитов Claude временно недоступен.")
            return acct
        payload = response.json()
        names = {"five_hour": "За 5 часов", "seven_day": "За неделю", "seven_day_opus": "Opus · неделя",
            "seven_day_sonnet": "Sonnet · неделя", "seven_day_oauth_apps": "Приложения · неделя", "seven_day_cowork": "Cowork · неделя"}
        for key, label in names.items():
            value = payload.get(key)
            if isinstance(value, dict) and isinstance(value.get("utilization"), (int, float)):
                acct["limits"].append({"name": label, "percent": round(value["utilization"]), "resets_at": value.get("resets_at") or ""})
        if not acct["limits"]:
            acct["error"] = "Claude не вернул данные о лимитах для этого аккаунта."
    except Exception:
        acct["error"] = "Не удалось обновить Claude. Проверь подключение и вход в приложение."
    return acct


def codex():
    import subprocess, queue, threading
    acct = {"id": "codex", "name": "Codex", "plan": "", "limits": [], "extra": None, "error": ""}
    process = None
    try:
        process = subprocess.Popen(["codex", "app-server", "--listen", "stdio://"],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        messages = queue.Queue()
        def reader():
            for line in process.stdout:
                try: messages.put(json.loads(line))
                except ValueError: pass
            messages.put(None)
        threading.Thread(target=reader, daemon=True).start()
        def send(message):
            process.stdin.write(json.dumps(message) + "\n")
            process.stdin.flush()
        def result(identifier):
            end = time.monotonic() + 20
            while time.monotonic() < end:
                message = messages.get(timeout=max(0.01, end - time.monotonic()))
                if message is None: raise RuntimeError("closed")
                if message.get("id") == identifier:
                    if "error" in message: raise RuntimeError("request failed")
                    return message["result"]
            raise TimeoutError()
        send({"id": 1, "method": "initialize", "params": {"clientInfo": {"name": "orrery_limits", "version": "1.0"}}})
        result(1)
        send({"method": "initialized"})
        send({"id": 2, "method": "account/rateLimits/read"})
        payload = result(2)
        buckets = payload.get("rateLimitsByLimitId") or {"codex": payload.get("rateLimits") or {}}
        for bucket_id, bucket in buckets.items():
            if not isinstance(bucket, dict): continue
            plan = bucket.get("planType")
            if plan: acct["plan"] = {"prolite": "Pro Lite", "promax": "Pro Max"}.get(plan, plan.title())
            for kind in ("primary", "secondary"):
                window = bucket.get(kind)
                if not isinstance(window, dict) or window.get("usedPercent") is None: continue
                minutes = window.get("windowDurationMins") or 0
                label = "За неделю" if minutes == 10080 else "За 5 часов" if minutes == 300 else "За сутки" if minutes == 1440 else ("За " + str(minutes // 60) + " ч") if minutes and minutes % 60 == 0 else ("За " + str(minutes) + " мин") if minutes else "Текущий лимит"
                if len(buckets) > 1: label = (bucket.get("limitName") or bucket_id) + " · " + label
                reset = window.get("resetsAt")
                acct["limits"].append({"name": label, "percent": round(window["usedPercent"]),
                    "resets_at": datetime.fromtimestamp(reset, timezone.utc).isoformat() if reset else ""})
        if not acct["limits"]: acct["error"] = "Лимиты подписки недоступны. Проверь вход в Codex."
    except Exception:
        acct["error"] = "Не удалось обновить Codex. Проверь подключение и вход в аккаунт."
    finally:
        if process is not None:
            process.terminate()
            try: process.wait(timeout=3)
            except subprocess.TimeoutExpired: process.kill(); process.wait()
            for stream in (process.stdin, process.stdout):
                if stream: stream.close()
    return acct


PROVIDERS = [claude_desktop, codex]



def main():
    import fcntl
    os.makedirs(STATE, exist_ok=True)
    lock = open(os.path.join(STATE, "agents.lock"), "w")
    try: fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError: return
    try:
        with open(OUT) as f: previous = {a["id"]: a for a in json.load(f).get("accounts", [])}
    except (OSError, ValueError, KeyError): previous = {}
    accounts = []
    for p in PROVIDERS:
        try:
            a = p()
        except Exception as e:
            a = {"id": p.__name__, "name": p.__name__, "plan": "", "limits": [], "extra": None, "error": str(e)}
        if a:
            old = previous.get(a["id"], {})
            if a.get("error") and old.get("limits"):
                a["limits"] = old["limits"]
                a["plan"] = a.get("plan") or old.get("plan", "")
                a["updated"] = old.get("updated", 0)
                a["stale"] = True
            else:
                a["updated"] = int(time.time()) if not a.get("error") else 0
                a["stale"] = False
            accounts.append(a)
    claude_t = claude_tokens()
    data = {"updated": int(time.time()), "accounts": accounts, "tokens": claude_t,   # "tokens": older shells
            "tokens_by": {"claude": claude_t, "codex": codex_tokens()}}
    os.makedirs(STATE, exist_ok=True)
    tmp = OUT + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(data, fh)
    os.chmod(tmp, 0o600)
    os.replace(tmp, OUT)
    if "--print" in sys.argv:
        print(json.dumps(data, indent=2))


if __name__ == "__main__":
    main()
