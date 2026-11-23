#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <app-path> <output-dmg-path> <volume-name>"
}

if [[ $# -ne 3 ]]; then
  usage >&2
  exit 64
fi

APP_PATH="$1"
OUTPUT_PATH="$2"
VOLUME_NAME="$3"

SCRIPT_DIRECTORY="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIRECTORY/.." && pwd)"
BACKGROUND_PATH="$REPO_ROOT/Resources/dmg.png"

if [[ ! -d "$APP_PATH" || "$APP_PATH" != *.app ]]; then
  echo "error: application not found: $APP_PATH" >&2
  exit 1
fi

if [[ "$OUTPUT_PATH" != *.dmg ]]; then
  echo "error: output path must end in .dmg: $OUTPUT_PATH" >&2
  exit 1
fi

if [[ -e "$OUTPUT_PATH" ]]; then
  echo "error: output already exists: $OUTPUT_PATH" >&2
  exit 1
fi

if [[ -z "$VOLUME_NAME" ]]; then
  echo "error: volume name must not be empty" >&2
  exit 1
fi

if [[ ! -f "$BACKGROUND_PATH" ]]; then
  echo "error: background image not found: $BACKGROUND_PATH" >&2
  exit 1
fi

APP_NAME="$(basename "$APP_PATH")"
OUTPUT_DIRECTORY="$(dirname "$OUTPUT_PATH")"
WORK_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/create-dmg.XXXXXX")"
STAGING_DIRECTORY="$WORK_DIRECTORY/staging"
MOUNT_POINT="/Volumes/$VOLUME_NAME"
RW_DMG="$WORK_DIRECTORY/dawn-rw.dmg"
VOLUME_MOUNTED=0

WINDOW_WIDTH=657
WINDOW_HEIGHT=367
ICON_SIZE=128
ICON_Y=$((WINDOW_HEIGHT / 2))
LEFT_ICON_X=$((WINDOW_WIDTH / 4))
RIGHT_ICON_X=$((WINDOW_WIDTH * 3 / 4))

cleanup() {
  if [[ "${VOLUME_MOUNTED:-0}" -eq 1 ]]; then
    /usr/bin/hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1 || true
  fi

  if [[ -n "${WORK_DIRECTORY:-}" && -d "$WORK_DIRECTORY" ]]; then
    rm -rf "$WORK_DIRECTORY"
  fi
}

trap cleanup EXIT INT TERM

if [[ -e "$MOUNT_POINT" ]]; then
  echo "error: volume already mounted at $MOUNT_POINT" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIRECTORY"
mkdir -p "$STAGING_DIRECTORY/.background"

echo "Copying $APP_NAME into disk image staging directory"

/usr/bin/ditto \
  "$APP_PATH" \
  "$STAGING_DIRECTORY/$APP_NAME"

echo "Adding Application shortcut"

/bin/ln -s \
  /Applications \
  "$STAGING_DIRECTORY/Applications"

echo "Adding disk image background"

/usr/bin/ditto \
  "$BACKGROUND_PATH" \
  "$STAGING_DIRECTORY/.background/background.png"

STAGING_SIZE_MB="$(/usr/bin/du -sm "$STAGING_DIRECTORY" | /usr/bin/awk '{ print $1 }')"
IMAGE_SIZE_MB=$((STAGING_SIZE_MB + 30))

echo "Creating read-write disk image (${IMAGE_SIZE_MB} MB)"

/usr/bin/hdiutil create \
  -size "${IMAGE_SIZE_MB}m" \
  -fs HFS+ \
  -volname "$VOLUME_NAME" \
  -type UDIF \
  "$RW_DMG"

echo "Mounting disk image"

/usr/bin/hdiutil attach \
  "$RW_DMG" \
  -readwrite \
  -noverify \
  -noautoopen \
  >/dev/null
VOLUME_MOUNTED=1

for _ in $(seq 1 40); do
  if [[ -d "$MOUNT_POINT" ]]; then
    break
  fi
  /bin/sleep 0.25
done

if [[ ! -d "$MOUNT_POINT" ]]; then
  echo "error: mounted volume not found at $MOUNT_POINT" >&2
  exit 1
fi

echo "Copying staged contents onto volume"

/usr/bin/ditto \
  "$STAGING_DIRECTORY" \
  "$MOUNT_POINT"

/usr/bin/chflags hidden "$MOUNT_POINT/.background"

echo "Configuring Finder window (${WINDOW_WIDTH}x${WINDOW_HEIGHT})"

/usr/bin/osascript <<EOF
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, $((100 + WINDOW_WIDTH)), $((100 + WINDOW_HEIGHT))}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to $ICON_SIZE
    set background picture of theViewOptions to file ".background:background.png"
    set position of item "$APP_NAME" of container window to {$LEFT_ICON_X, $ICON_Y}
    set position of item "Applications" of container window to {$RIGHT_ICON_X, $ICON_Y}
    update without registering applications
    delay 2
    close
    open
    delay 1
    close
  end tell
end tell
EOF

sync

echo "Detaching disk image"

/usr/bin/hdiutil detach "$MOUNT_POINT"
VOLUME_MOUNTED=0

echo "Compressing $OUTPUT_PATH"

/usr/bin/hdiutil convert \
  "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_PATH" \
  >/dev/null

echo "Verifying disk image"

/usr/bin/hdiutil verify "$OUTPUT_PATH"

echo "Created disk image: $OUTPUT_PATH"
