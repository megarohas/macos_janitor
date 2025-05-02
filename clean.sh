#!/bin/bash

LOGFILE="$HOME/clean_log.txt"
DAYS=7
echo "🧹 Cleaning old temporary files (older than $DAYS days): $(date)" | tee -a "$LOGFILE"

# List of safe directories
targets=(
  "$HOME/Library/Caches"
  "$HOME/Library/Application Support/Slack/Service Worker/CacheStorage"
  "$HOME/Library/Containers/com.apple.Safari/Data/Library/Caches"
  "$HOME/Library/Logs"
  "$HOME/.Trash"

  # Chrome caches
  "$HOME/Library/Caches/Google/Chrome"
  "$HOME/Library/Application Support/Google/Chrome/Default/Application Cache"
  "$HOME/Library/Application Support/Google/Chrome/Default/Code Cache"

  # Firefox caches
  "$HOME/Library/Caches/Firefox"
  "$HOME/Library/Application Support/Firefox/Profiles"/*/cache2
  "$HOME/Library/Application Support/Firefox/Profiles"/*/startupCache
  "$HOME/Library/Application Support/Firefox/Profiles"/*/minidumps

  # Firefox Dev caches
  "$HOME/Library/Caches/FirefoxDeveloperEdition"
  "$HOME/Library/Application Support/FirefoxDeveloperEdition/Profiles"/*/cache2
  "$HOME/Library/Application Support/FirefoxDeveloperEdition/Profiles"/*/startupCache
  "$HOME/Library/Application Support/FirefoxDeveloperEdition/Profiles"/*/minidumps

  # Yandex browser caches
  "$HOME/Library/Caches/Yandex"
  "$HOME/Library/Application Support/Yandex/YandexBrowser/Default/Application Cache"
  "$HOME/Library/Application Support/Yandex/YandexBrowser/Default/Code Cache"

  # npm cache and logs
  "$HOME/.npm/_cacache"
  "$HOME/.npm/_logs"

  # yarn cache
  "$HOME/Library/Caches/Yarn"
  "$HOME/.cache/yarn"
)

# Size before cleaning
size_before=$(du -sk ${targets[@]} 2>/dev/null | awk '{sum += $1} END {print sum}')

# Remove files older than N days
for dir in "${targets[@]}"; do
  if [ -d "$dir" ]; then
    find "$dir" -type f -mtime +$DAYS -print -delete 2>/dev/null
  fi
done

# Extra: Clean Chrome and Chrome Dev caches entirely
echo "🧽 Forcing clean of Chrome and Chrome Dev caches..." | tee -a "$LOGFILE"

rm -rf "$HOME/Library/Application Support/Google/Chrome/Default/{Cache,Code Cache,GPUCache}" 2>/dev/null
rm -rf "$HOME/Library/Caches/Google/Chrome/Default/{Cache,Code Cache,GPUCache}" 2>/dev/null

rm -rf "$HOME/Library/Application Support/Google/Chrome Dev/Default/{Cache,Code Cache,GPUCache}" 2>/dev/null
rm -rf "$HOME/Library/Caches/Google/Chrome Dev/Default/{Cache,Code Cache,GPUCache}" 2>/dev/null

# Size after cleaning
size_after=$(du -sk ${targets[@]} 2>/dev/null | awk '{sum += $1} END {print sum}')
freed_kb=$((size_before - size_after))
freed_mb=$(echo "scale=2; $freed_kb / 1024" | bc)

echo "💾 Freed up: $freed_mb MB" | tee -a "$LOGFILE"

# --- Xcode / CocoaPods Cleanup ---
echo "🔧 Checking for Xcode and CocoaPods..." | tee -a "$LOGFILE"

if [ -d "/Applications/Xcode.app" ]; then
  echo "🧽 Cleaning Xcode DerivedData and simulators..." | tee -a "$LOGFILE"

  if [ -d "$HOME/Library/Developer/Xcode/DerivedData" ]; then
    echo "⨯ Deleting DerivedData..." | tee -a "$LOGFILE"
    rm -rf "$HOME/Library/Developer/Xcode/DerivedData"
  fi

  echo "⨯ Deleting Device Support..." | tee -a "$LOGFILE"
  rm -rf "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
  rm -rf "$HOME/Library/Developer/Xcode/watchOS DeviceSupport"
  rm -rf "$HOME/Library/Developer/Xcode/tvOS DeviceSupport"

  echo "⨯ Deleting old simulators..." | tee -a "$LOGFILE"
  xcrun simctl delete unavailable 2>/dev/null

  echo "⨯ Cleaning Xcode caches..." | tee -a "$LOGFILE"
  rm -rf "$HOME/Library/Caches/com.apple.dt.Xcode"
  rm -rf "$HOME/Library/Caches/org.carthage.CarthageKit"
else
  echo "🚫 Xcode not found, skipping Xcode cleanup." | tee -a "$LOGFILE"
fi

if command -v pod &>/dev/null; then
  echo "⨯ Cleaning CocoaPods cache..." | tee -a "$LOGFILE"
  pod cache clean --all 2>/dev/null
else
  echo "🚫 CocoaPods not installed." | tee -a "$LOGFILE"
fi

# --- Cleaning Purgable Space ---
echo "🧼 Cleaning Purgable Space..." | tee -a "$LOGFILE"
sudo purge

# --- Deleting Local Time Machine Backups ---
echo "🗄️ Checking and deleting local Time Machine backups..." | tee -a "$LOGFILE"
tmutil listlocalsnapshots / | while read snapshot; do
  echo "⨯ Deleting local snapshot $snapshot..." | tee -a "$LOGFILE"
  sudo tmutil deletelocalsnapshots "$snapshot" 2>/dev/null
done

echo "✅ Cleanup completed: $(date)" | tee -a "$LOGFILE"
