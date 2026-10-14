# macos_janitor

**English** | [Русский](README.ru.md)

A nightly macOS janitor: once a day it quietly sweeps out caches, old logs and
the Trash. Runs as a user LaunchAgent — no root, no third-party "cleaners".

## What it cleans

| Section | What exactly | Threshold |
|---|---|---|
| Caches | `~/Library/Caches`, `~/.cache` | files older than 7 days |
| Browsers | Chrome, Opera, Firefox, Safari, Slack (Code Cache/GPUCache/cache2) | 7 days |
| Dev | npm, yarn, node-gyp, pip, deno, iTerm2, `.zcompdump` | 7 days |
| Playwright | browsers are expensive to re-download — gentler threshold | 30 days |
| Docker | `docker builder prune` (only if the daemon is running) | 7 days |
| Xcode | `simctl delete unavailable` | — |
| Claude | Cache/Code Cache/GPUCache — **only if the app is closed**; logs | all / 7 days |
| Apps | VS Code (logs/caches), sandbox `Containers` caches, HTTPStorages, Saved Application State, Mail attachments | 7–30 days |
| Homebrew | `brew cleanup -s --prune=7` + `brew autoremove` | 7 days |
| Logs | `~/Library/Logs` | 30 days |
| Trash | `~/.Trash` | 30 days |
| MongoDB | `mongod.log` rotation (SIGUSR1), cleanup of rotated logs | 30 days |

The rule: only things that apps recreate on their own get deleted. Data,
settings, profiles and projects are left alone.

### janitor vs. Mole (`mo clean`)

v2.1 covers the same set of targets as `mo clean`, but **by age** rather than
"everything at once": for a daily automatic run that's gentler — hot caches
don't get rebuilt every morning. What janitor deliberately does **not** copy
from Mole: hunting for orphaned data of uninstalled apps (complex heuristics —
not for a nightly cron job) and one-off operations like incomplete Time Machine
backups. That's what Mole is still around for: janitor is daily hygiene,
`mo clean` is a manual deep clean. The two tools don't conflict.

## Install

```bash
./install.sh
```

Installs the `com.megarohas.janitor` LaunchAgent, scheduled to run **daily at
05:00** (if the Mac was asleep, launchd runs the job when it wakes up).

Manual run: `bash clean.sh`. Log: `~/Library/Logs/janitor.log`.
Remove from autostart: `./uninstall.sh`.

## History

- **v1** (2025) — a root daemon `com.user.cleaner` + a script at an absolute
  path. After the folder was moved, the daemon silently failed every day at 5:00
  for over a year; on top of that, the Chrome cache cleanup lines never worked
  (brace expansion inside quotes).
- **v2** (2026-08) — full rewrite: a user LaunchAgent instead of a root daemon,
  the script path is resolved at install time, bugs fixed, dev caches, Homebrew,
  Claude and MongoDB log rotation added. Sections are independent; a summary
  with an estimate of the freed space goes to the log.
