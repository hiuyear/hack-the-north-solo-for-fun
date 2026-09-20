#!/bin/zsh
set -euo pipefail

cd "${0:A:h}"

BUNDLE_ID="com.hiuyear.BadgeKartBridge"
APP="$HOME/Applications/BadgeKartBridge.app"
STAGE=".build/BadgeKartBridge.app"
PLIST="macos/BadgeKartBridge-Info.plist"
LOG="$HOME/Library/Logs/BadgeKartBridge.log"
BINARY=".build/release/badge-kart-bridge"

print_accessibility_help() {
  cat <<'EOF'

========================================
Accessibility (required for key presses)
========================================

BadgeKartBridge will NOT always appear in the Accessibility list
after the permission prompt. That is a macOS TCC quirk, not a failed
install. Add the installed app with the + button:

  1. System Settings → Privacy & Security → Accessibility
  2. Unlock, then click the + button
  3. Press Command-Shift-G and paste:

       ~/Applications/BadgeKartBridge.app

  4. Choose BadgeKartBridge.app and turn its switch ON
  5. Run start.command again

Do NOT enable Terminal, Cursor, or iTerm instead of BadgeKartBridge.app.
Those are different permission identities. This launcher installs a
stable .app (bundle id com.hiuyear.BadgeKartBridge) and starts that
.app with `open`. Rebuilding the unsigned repo binary is not enough.

If you already added an old copy, remove it, then + add
~/Applications/BadgeKartBridge.app again.

EOF
}

quit_running_app() {
  osascript -e 'tell application "BadgeKartBridge" to quit' >/dev/null 2>&1 || true
  if pgrep -x BadgeKartBridge >/dev/null 2>&1; then
    pkill -x BadgeKartBridge >/dev/null 2>&1 || true
    sleep 0.3
  fi
}

if ! command -v swift >/dev/null 2>&1; then
  echo "swift is not installed. Install Xcode or Command Line Tools:"
  echo "  xcode-select --install"
  exit 1
fi

if [[ ! -f "$PLIST" ]]; then
  echo "missing $PLIST"
  exit 1
fi

echo "Building badge-kart-bridge (release)..."
swift build -c release --product badge-kart-bridge

mkdir -p "$STAGE/Contents/MacOS"
cp "$BINARY" "$STAGE/Contents/MacOS/BadgeKartBridge"
cp "$PLIST" "$STAGE/Contents/Info.plist"
chmod +x "$STAGE/Contents/MacOS/BadgeKartBridge"

needs_install=1
if [[ -x "$APP/Contents/MacOS/BadgeKartBridge" && -f "$APP/Contents/Info.plist" ]]; then
  if cmp -s "$STAGE/Contents/MacOS/BadgeKartBridge" "$APP/Contents/MacOS/BadgeKartBridge" \
     && cmp -s "$STAGE/Contents/Info.plist" "$APP/Contents/Info.plist"; then
    needs_install=0
  fi
fi

quit_running_app

if [[ "$needs_install" -eq 1 ]]; then
  echo "Installing $APP with stable bundle id $BUNDLE_ID"
  mkdir -p "$HOME/Applications"
  rm -rf "$APP"
  ditto "$STAGE" "$APP"
  # Ad-hoc sign once per changed binary. Do not use hardened runtime:
  # that blocks CGEvent injection. Identifier stays com.hiuyear.BadgeKartBridge.
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
  xattr -dr com.apple.quarantine "$APP" >/dev/null 2>&1 || true
  echo "Installed a new copy. If keys stop working, re-add this exact app with +."
else
  echo "Using existing $APP (binary unchanged; Accessibility identity preserved)"
fi

echo
echo "Installed app: $APP"
echo "Bundle id:     $BUNDLE_ID"
defaults read "$APP/Contents/Info" CFBundleIdentifier 2>/dev/null || true
echo "Log file:      $LOG"
print_accessibility_help

mkdir -p "$(dirname "$LOG")"
touch "$LOG"

echo "Launching $APP (not the repo binary; this is the Accessibility identity)"
open "$APP" --args "$@"

cleanup() {
  osascript -e 'tell application "BadgeKartBridge" to quit' >/dev/null 2>&1 || true
  pkill -x BadgeKartBridge >/dev/null 2>&1 || true
  if [[ -n "${TAIL_PID:-}" ]]; then
    kill "$TAIL_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM

echo "---- live log (Ctrl+C stops the bridge) ----"
echo "Look for: Player 1 controller ready"
echo "Then press/release A, LEFT/RIGHT, B, UP, DOWN, AUX1, START, shake once,"
echo "and unplug while holding A. Every action should print DOWN/UP."
echo

started=0
for _ in {1..50}; do
  if pgrep -x BadgeKartBridge >/dev/null 2>&1; then
    started=1
    break
  fi
  sleep 0.1
done
if [[ "$started" -ne 1 ]]; then
  echo "BadgeKartBridge.app did not start. Check Console.app or $LOG"
  exit 1
fi

tail -n 0 -F "$LOG" &
TAIL_PID=$!

while pgrep -x BadgeKartBridge >/dev/null 2>&1; do
  sleep 0.5
done
kill "$TAIL_PID" >/dev/null 2>&1 || true
TAIL_PID=""
