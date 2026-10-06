#!/bin/bash
# Installs a launchd job that runs scripts/weekly-report.py every Monday at 09:00 (runs when the Mac wakes if it was asleep).
# Remove it with: launchctl bootout gui/$(id -u)/com.goelir.iptvmac-weekly && rm ~/Library/LaunchAgents/com.goelir.iptvmac-weekly.plist
set -euo pipefail
cd "$(dirname "$0")/.."
LABEL=com.goelir.iptvmac-weekly
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>$(command -v python3)</string><string>$PWD/scripts/weekly-report.py</string></array>
  <key>StartCalendarInterval</key><dict><key>Weekday</key><integer>1</integer><key>Hour</key><integer>9</integer><key>Minute</key><integer>0</integer></dict>
  <key>StandardOutPath</key><string>$HOME/Library/Logs/iptvmac-weekly.log</string>
  <key>StandardErrorPath</key><string>$HOME/Library/Logs/iptvmac-weekly.log</string>
</dict></plist>
EOF
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed: every Monday 09:00 -> reports in ~/Movies/IPTVMac-demo/weekly/"
