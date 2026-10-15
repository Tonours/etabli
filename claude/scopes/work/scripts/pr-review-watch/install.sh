#!/bin/bash
set -euo pipefail

LABEL="com.aguimard.pr-review-watch"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
SCRIPT="$HOME/.claude/scripts/pr-review-watch/watch.sh"
INTERVAL="${1:-300}"

[ -x "$SCRIPT" ] || { echo "missing $SCRIPT, run etabli scripts/install.sh first" >&2; exit 1; }
case "$INTERVAL" in ''|*[!0-9]*) echo "interval must be seconds" >&2; exit 2 ;; esac

mkdir -p "$HOME/.claude/logs"
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT</string>
  </array>
  <key>StartInterval</key>
  <integer>$INTERVAL</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$HOME/.claude/logs/pr-review-watch.launchd.out</string>
  <key>StandardErrorPath</key>
  <string>$HOME/.claude/logs/pr-review-watch.launchd.err</string>
</dict>
</plist>
EOF

AWAKE_LABEL="com.aguimard.pr-review-awake"
AWAKE_PLIST="$HOME/Library/LaunchAgents/$AWAKE_LABEL.plist"
cat >"$AWAKE_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$AWAKE_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/caffeinate</string>
    <string>-i</string>
    <string>-s</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF

for label_plist in "$LABEL:$PLIST" "$AWAKE_LABEL:$AWAKE_PLIST"; do
  launchctl bootout "gui/$(id -u)/${label_plist%%:*}" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "${label_plist#*:}"
done
echo "loaded $LABEL every ${INTERVAL}s"
echo "loaded $AWAKE_LABEL: no idle sleep, no system sleep on AC power (display still sleeps)"
echo "log: $HOME/.claude/logs/pr-review-watch.log"
echo "pause: touch $HOME/.claude/state/pr-review-watch/off"
echo "remove: launchctl bootout gui/$(id -u)/$LABEL && rm $PLIST"
echo "allow sleep again: launchctl bootout gui/$(id -u)/$AWAKE_LABEL && rm $AWAKE_PLIST"
