#!/bin/bash
# Удаление LaunchAgent'а janitor (сам репозиторий и логи не трогает).
set -eu
launchctl bootout "gui/$(id -u)/com.megarohas.janitor" 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/com.megarohas.janitor.plist"
echo "janitor выключен и удалён из автозапуска."
