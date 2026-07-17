#!/usr/bin/env bash
set -uo pipefail
LABEL="local.claudeusage.menubar"
UID_="$(id -u)"
launchctl bootout "gui/$UID_/$LABEL" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/ClaudeUsage.app"
echo "Uninstalled the app and its auto-start agent."
echo "Cache/logs in ~/ClaudeUsage were left intact - remove manually if you like:"
echo "    rm -rf ~/ClaudeUsage"
