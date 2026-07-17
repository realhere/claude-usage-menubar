#!/usr/bin/env python3
"""
Claude usage helper (updated 2026-07-18 for the new /usage endpoint).

Decrypts the desktop Claude app cookies, calls the official usage endpoint with
the desktop app's User-Agent, and prints a compact JSON summary for the menu bar app.

Output (success):
  {"ok": true, "five_hour": 19, "seven_day": 12,
   "resets": {"five_hour": "...", "seven_day": "..."},
   "models": [{"name": "Fable", "percent": 10, "resets_at": "..."}]}
Output (failure):
  {"ok": false, "error": "..."}

Privacy: sessionKey is only sent to claude.ai's official endpoint; never stored, never
sent to any third party.
"""
import sqlite3, subprocess, hashlib, os, shutil, tempfile, json, urllib.request, sys

CK = os.path.expanduser("~/Library/Application Support/Claude/Cookies")
CACHE = os.path.expanduser("~/ClaudeUsage/model_cache.json")


def load_cache():
    try:
        return json.load(open(CACHE))
    except Exception:
        return {}


def save_cache(cache):
    try:
        json.dump(cache, open(CACHE, "w"))
    except Exception:
        pass
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Claude/0.16.1 Chrome/138.0.0.0 Electron/42.5.1 Safari/537.36")


def fail(msg):
    print(json.dumps({"ok": False, "error": msg}, ensure_ascii=False))
    sys.exit(0)


def keychain_password():
    try:
        return subprocess.check_output(
            ["security", "find-generic-password", "-w",
             "-s", "Claude Safe Storage", "-a", "Claude"],
            stderr=subprocess.DEVNULL).strip()
    except Exception:
        fail("keychain access denied")


def decrypt(enc, key):
    if enc[:3] in (b"v10", b"v11"):
        enc = enc[3:]
    out = subprocess.run(
        ["openssl", "enc", "-d", "-aes-128-cbc", "-nopad",
         "-K", key.hex(), "-iv", (b" " * 16).hex()],
        input=enc, capture_output=True).stdout
    if out:
        n = out[-1]
        if 1 <= n <= 16:
            out = out[:-n]
    return out[32:].decode("utf-8", "replace")


def load_cookies():
    if not os.path.exists(CK):
        fail("desktop Claude app cookies not found")
    pw = keychain_password()
    key = hashlib.pbkdf2_hmac("sha1", pw, b"saltysalt", 1003, 16)
    tmp = tempfile.mktemp(suffix=".db")
    shutil.copy(CK, tmp)
    try:
        con = sqlite3.connect(tmp)
        rows = list(con.execute(
            "select name, encrypted_value from cookies where host_key like '%claude.ai'"))
        con.close()
    finally:
        try: os.remove(tmp)
        except OSError: pass
    cookies = {}
    for name, enc in rows:
        try:
            cookies[name] = decrypt(enc, key)
        except Exception:
            pass
    if "sessionKey" not in cookies:
        fail("not logged in (no sessionKey)")
    return cookies


def as_int(v):
    try:
        return int(round(float(v)))
    except (TypeError, ValueError):
        return None


def main():
    cookies = load_cookies()
    org = cookies.get("lastActiveOrg", "").strip()
    if not org:
        fail("no active org")
    url = "https://claude.ai/api/organizations/%s/usage" % org
    req = urllib.request.Request(url, headers={
        "Cookie": "; ".join("%s=%s" % (n, v) for n, v in cookies.items()),
        "User-Agent": UA,
        "Accept": "*/*",
        "Referer": "https://claude.ai/settings/usage",
        "anthropic-client-platform": "web_claude_ai",
    })
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        if e.code in (401, 403):
            fail("auth failed (HTTP %d) - re-login desktop app or update UA" % e.code)
        fail("HTTP %d" % e.code)
    except Exception as e:
        fail("network error: %s" % type(e).__name__)

    def block(key):
        b = data.get(key)
        return b if isinstance(b, dict) else {}

    fh = block("five_hour")
    sd = block("seven_day")

    # per-model weekly limits come from limits[] entries of kind weekly_scoped
    models = []
    for L in (data.get("limits") or []):
        if L.get("kind") == "weekly_scoped":
            scope = L.get("scope") or {}
            model = (scope.get("model") or {})
            name = model.get("display_name")
            pct = as_int(L.get("percent"))
            if name and pct is not None:
                models.append({"name": name, "percent": pct, "resets_at": L.get("resets_at")})

    import time
    now = int(time.time())
    cache = load_cache()
    live_names = set()
    for m in models:
        live_names.add(m["name"])
        cache[m["name"]] = {"percent": m["percent"], "resets_at": m.get("resets_at"), "ts": now}
        m["stale_seconds"] = 0
    save_cache(cache)
    # API 沒回傳的 model，用 8 天內的快取值補上（標記 stale）
    for name, info in cache.items():
        if name not in live_names and (now - info.get("ts", 0)) < 8 * 86400:
            models.append({"name": name, "percent": info.get("percent"),
                           "resets_at": info.get("resets_at"),
                           "stale_seconds": now - info.get("ts", 0)})

    out = {
        "ok": True,
        "five_hour": as_int(fh.get("utilization")),
        "seven_day": as_int(sd.get("utilization")),
        "resets": {
            "five_hour": fh.get("resets_at"),
            "seven_day": sd.get("resets_at"),
        },
        "models": models,
    }
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
