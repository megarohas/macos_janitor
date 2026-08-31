#!/bin/bash
# macos_janitor v2.1 — ночная уборка macOS
# v2.1: паритет по охвату с `mo clean` (Mole), но стратегия возрастная,
# а не «снести всё сейчас» — для ежедневного автозапуска это бережнее.
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
  "$HOME/Library/Caches/node-gyp"
  "$HOME/Library/Caches/pip"
  "$HOME/Library/Caches/deno"
  "$HOME/Library/Caches/com.googlecode.iterm2"
)
for d in "${dev_dirs[@]}"; do clean_old "$d" "$DAYS_CACHE"; done
# браузеры Playwright дорого перекачивать — им отдельный, щадящий порог (30 дн.)
clean_old "$HOME/Library/Caches/ms-playwright" 30
log "dev-кэши: npm/yarn/node-gyp/pip/deno/iTerm2 (playwright — 30 дн.)"

# кэш zsh-автодополнений (пересоздаётся при старте шелла)
find "$HOME" -maxdepth 1 -name ".zcompdump*" -mtime "+$DAYS_CACHE" -delete 2>/dev/null

# Docker/OrbStack: build-кэш старше недели (только если демон запущен)
if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
  docker builder prune -f --filter "until=168h" >>"$LOG" 2>&1
  log "docker: build-кэш старше 7 дн. очищен"
fi

# Симуляторы Xcode: удалить недоступные (после обновлений runtime'ов)
if command -v xcrun >/dev/null 2>&1; then
  xcrun simctl delete unavailable >>"$LOG" 2>&1 && log "simctl: недоступные симуляторы удалены"
fi

# ── 4. Кэши Claude (только если приложение закрыто) ──────────────────────────
if ! pgrep -xq "Claude"; then
  rm -rf "$HOME/Library/Application Support/Claude/Cache" \
         "$HOME/Library/Application Support/Claude/Code Cache" \
         "$HOME/Library/Application Support/Claude/GPUCache" 2>/dev/null
  log "Claude: кэши очищены (приложение не запущено)"
else
  log "Claude: запущен — кэши пропущены"
fi
clean_old "$HOME/Library/Logs/Claude" "$DAYS_CACHE"

# ── 4б. Кэши и логи приложений (по мотивам mo clean) ────────────────────────
clean_old "$HOME/Library/Application Support/Code/logs"       "$DAYS_CACHE"
clean_old "$HOME/Library/Application Support/Code/Cache"      "$DAYS_CACHE"
clean_old "$HOME/Library/Application Support/Code/CachedData" "$DAYS_CACHE"
# кэши песочниц (Containers) — только подкаталоги Caches
for c in "$HOME/Library/Containers"/*/Data/Library/Caches; do
  clean_old "$c" "$DAYS_CACHE"
done
clean_old "$HOME/Library/HTTPStorages"              "$DAYS_LOGS"
clean_old "$HOME/Library/Saved Application State"   "$DAYS_LOGS"
clean_old "$HOME/Library/Containers/com.apple.mail/Data/Library/Mail Downloads" "$DAYS_LOGS"
log "приложения: VS Code, песочницы, HTTPStorages, окна, вложения Mail"

# ── 5. Homebrew ──────────────────────────────────────────────────────────────
if [ -x "$BREW" ]; then
  "$BREW" cleanup -s --prune="$DAYS_CACHE" >>"$LOG" 2>&1
  "$BREW" autoremove >>"$LOG" 2>&1
  log "brew cleanup + autoremove выполнены"
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
