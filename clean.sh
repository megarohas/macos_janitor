#!/bin/bash
# macos_janitor v2 — ночная уборка macOS
# Запускается LaunchAgent'ом com.megarohas.janitor ежедневно в 05:00 (см. install.sh).
# Философия: удаляем только то, что система/приложения пересоздают сами.
# Каждая секция независима: ошибка в одной не роняет остальные (set -e намеренно нет).

set -u

DAYS_CACHE=7    # кэши: файлы старше N дней
DAYS_LOGS=30    # логи: старше N дней
DAYS_TRASH=30   # корзина: старше N дней
LOG="$HOME/Library/Logs/janitor.log"
BREW=/opt/homebrew/bin/brew

ts()  { date "+%Y-%m-%d %H:%M:%S"; }
log() { echo "[$(ts)] $*" | tee -a "$LOG"; }

free_kb() { df -k "$HOME" | awk 'NR==2 {print $4}'; }

# Удалить в каталоге файлы старше N дней + опустевшие подкаталоги
clean_old() { # $1=dir $2=days
  [ -d "$1" ] || return 0
  find "$1" -type f -mtime "+$2" -delete 2>/dev/null
  find "$1" -mindepth 1 -type d -empty -delete 2>/dev/null
}

BEFORE=$(free_kb)
log "🧹 janitor v2: старт"

# ── 1. Общие пользовательские кэши ───────────────────────────────────────────
clean_old "$HOME/Library/Caches" "$DAYS_CACHE"
clean_old "$HOME/.cache"         "$DAYS_CACHE"
log "кэши: ~/Library/Caches и ~/.cache (старше ${DAYS_CACHE} дн.)"

# ── 2. Браузеры ──────────────────────────────────────────────────────────────
# (в v1 здесь был баг: {Cache,Code Cache} внутри кавычек не раскрывается)
browser_dirs=(
  "$HOME/Library/Caches/Google/Chrome"
  "$HOME/Library/Caches/com.operasoftware.Opera"
  "$HOME/Library/Caches/Firefox"
  "$HOME/Library/Containers/com.apple.Safari/Data/Library/Caches"
  "$HOME/Library/Application Support/Google/Chrome/Default/Code Cache"
  "$HOME/Library/Application Support/Google/Chrome/Default/GPUCache"
  "$HOME/Library/Application Support/com.operasoftware.Opera/Code Cache"
  "$HOME/Library/Application Support/com.operasoftware.Opera/GPUCache"
  "$HOME/Library/Application Support/Slack/Service Worker/CacheStorage"
)
for d in "$HOME/Library/Application Support/Firefox/Profiles"/*/cache2 \
         "$HOME/Library/Application Support/Firefox/Profiles"/*/startupCache; do
  browser_dirs+=("$d")
done
for d in "${browser_dirs[@]}"; do clean_old "$d" "$DAYS_CACHE"; done
log "браузеры: Chrome/Opera/Firefox/Safari/Slack"

# ── 3. Dev-инструменты ───────────────────────────────────────────────────────
dev_dirs=(
  "$HOME/.npm/_cacache"
  "$HOME/.npm/_logs"
  "$HOME/Library/Caches/Yarn"
  "$HOME/.cache/yarn"
  "$HOME/Library/Caches/ms-playwright"
  "$HOME/Library/Caches/node-gyp"
  "$HOME/Library/Caches/pip"
  "$HOME/Library/Caches/deno"
  "$HOME/Library/Caches/com.googlecode.iterm2"
)
for d in "${dev_dirs[@]}"; do clean_old "$d" "$DAYS_CACHE"; done
log "dev-кэши: npm/yarn/playwright/node-gyp/pip/deno/iTerm2"

# ── 4. Кэши Claude (только если приложение закрыто) ──────────────────────────
if ! pgrep -xq "Claude"; then
  rm -rf "$HOME/Library/Application Support/Claude/Cache" \
         "$HOME/Library/Application Support/Claude/Code Cache" \
         "$HOME/Library/Application Support/Claude/GPUCache" 2>/dev/null
  log "Claude: кэши очищены (приложение не запущено)"
else
  log "Claude: запущен — кэши пропущены"
fi

# ── 5. Homebrew ──────────────────────────────────────────────────────────────
if [ -x "$BREW" ]; then
  "$BREW" cleanup -s --prune="$DAYS_CACHE" >>"$LOG" 2>&1
  log "brew cleanup выполнен"
fi

# ── 6. Логи и корзина ────────────────────────────────────────────────────────
clean_old "$HOME/Library/Logs" "$DAYS_LOGS"
clean_old "$HOME/.Trash"       "$DAYS_TRASH"
log "логи (>${DAYS_LOGS} дн.) и корзина (>${DAYS_TRASH} дн.)"

# ── 7. Ротация лога MongoDB (~/mongo-data растёт с logappend) ───────────────
if pgrep -xq mongod; then
  pkill -USR1 -x mongod 2>/dev/null && log "mongod: лог ротирован (SIGUSR1)"
fi
find "$HOME/mongo-data" -maxdepth 1 -name "mongod.log.*" -mtime +30 -delete 2>/dev/null

# ── Итог ─────────────────────────────────────────────────────────────────────
AFTER=$(free_kb)
FREED_MB=$(( (AFTER - BEFORE) / 1024 ))
[ "$FREED_MB" -lt 0 ] && FREED_MB=0
log "✅ готово: освобождено ~${FREED_MB} МБ, свободно $(df -h "$HOME" | awk 'NR==2 {print $4}')"

# ротация собственного лога
tail -n 1000 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
exit 0
