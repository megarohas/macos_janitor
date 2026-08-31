#!/bin/bash
# Установка janitor как пользовательского LaunchAgent (без sudo).
# Идемпотентно: повторный запуск переустанавливает агент.
set -eu

DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST="$HOME/Library/LaunchAgents/com.megarohas.janitor.plist"
UID_NUM=$(id -u)

mkdir -p "$HOME/Library/LaunchAgents"
sed -e "s|__JANITOR_DIR__|$DIR|g" -e "s|__HOME__|$HOME|g" \
  "$DIR/com.megarohas.janitor.plist.template" > "$PLIST"
chmod 644 "$PLIST"
chmod +x "$DIR/clean.sh"

launchctl bootout "gui/$UID_NUM/com.megarohas.janitor" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"

echo "✅ janitor установлен: ежедневно в 05:00"
echo "   скрипт:  $DIR/clean.sh"
echo "   лог:     $HOME/Library/Logs/janitor.log"
echo "   пробный запуск вручную: bash \"$DIR/clean.sh\""
echo
echo "ℹ️  Старый root-демон v1 (/Library/LaunchDaemons/com.user.cleaner.plist)"
echo "   удаляется скриптом cleanup_root.sh из репозитория megarohas_mac_tweaks."
