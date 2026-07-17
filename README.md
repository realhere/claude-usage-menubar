# Claude Usage (menu bar)

A tiny macOS menu bar app that shows your Claude subscription usage at a glance —
no need to open the settings menu.

```
▮▮▮ 5H 20% | W 12% | F 10%
```

Click it for a breakdown with color-coded progress bars and reset times:

- **5-hour** usage (rolling session limit)
- **Weekly** usage (overall)
- Per-model weekly usage (e.g. **Fable**), when the API reports it

Progress bars are green (< 50%), orange (50–79%), red (≥ 80%). Values refresh
every 5 minutes. The app lives only in the menu bar (no Dock icon) and starts
automatically at login.

## Requirements

- **macOS 12+**
- **Xcode Command Line Tools** (for `swiftc`): `xcode-select --install`
- The **Claude desktop app** installed and **logged in** (this app reads its
  local session to authenticate — see *How it works* below)

## Install

```bash
git clone https://github.com/<your-username>/claude-usage-menubar.git
cd claude-usage-menubar
./install.sh
```

The script builds a small `.app`, installs it to `~/Applications`, and sets up a
LaunchAgent so it starts at login. On first launch macOS may ask for keychain
access (to read the Claude app's cookies) — click **Allow**.

## Uninstall

```bash
./uninstall.sh
```

## How it works

There is no public Claude usage API, so this app reads the same data the Claude
web app shows:

1. It reads the Claude **desktop app's cookies** from
   `~/Library/Application Support/Claude/Cookies` (a local SQLite file) and
   decrypts them with the *"Claude Safe Storage"* key from your macOS **login
   keychain** — the same mechanism Chrome/Electron apps use for their own cookies.
2. It calls the **official** `claude.ai` usage endpoint
   (`/api/organizations/{org}/usage`) — the very endpoint the web app uses — with
   those cookies, and reads back your usage percentages.

## Privacy & security

- Your session key is **only** sent to `claude.ai`'s official endpoint. It is
  **never** stored on disk and **never** sent anywhere else.
- The only things written locally are a small cache of the last-seen per-model
  percentages (`~/ClaudeUsage/model_cache.json`) and an optional debug log — no
  credentials.
- Everything the app does is in this repo. Read `usage_helper.py` (≈150 lines) —
  it's short and auditable.

## Limitations & known issues

- **macOS only.**
- **Requires the Claude desktop app** installed and logged in.
- Uses an **undocumented** `claude.ai` endpoint. It can change or break at any
  time — that's the nature of an unofficial tool. If usage stops loading, the API
  may have changed; check the endpoint against the web app's Network tab.
- Authentication relies on the desktop app keeping its Cloudflare clearance
  cookie fresh. If you fully quit the Claude desktop app for a long time, the menu
  bar may briefly show an error until you reopen it.
- The pinned **User-Agent** in `usage_helper.py` matches a specific Claude desktop
  version. After a major desktop-app update you may need to update the `UA` string
  near the top of `usage_helper.py`.

## Customization

- Change the refresh interval: `refreshInterval` in `main.swift`.
- Change the menu bar icon: the `chart.bar.xaxis` SF Symbol in `main.swift`.
- Rebuild after edits: `./install.sh`.

## License

MIT — see [LICENSE](LICENSE).

## Disclaimer

Not affiliated with, authorized, or endorsed by Anthropic. "Claude" is a
trademark of Anthropic. This is an unofficial, personal-use tool that reads your
own account's usage from your own machine. Use at your own risk; you are
responsible for complying with Anthropic's terms of service.
