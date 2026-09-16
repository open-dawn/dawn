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

APP_NAME="$(basename "$APP_PATH")"
OUTPUT_DIRECTORY="$(dirname "$OUTPUT_PATH")"
WORK_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/create-dmg.XXXXXX")"
STAGING_DIRECTORY="$WORK_DIRECTORY/staging"

cleanup() {
  if [[ -n "${WORK_DIRECTORY:-}" && -d "$WORK_DIRECTORY" ]]; then
    rm -rf "$WORK_DIRECTORY"
  fi
}

trap cleanup EXIT INT TERM

mkdir -p "$OUTPUT_DIRECTORY"
mkdir -p "$STAGING_DIRECTORY"

echo "Copying $APP_NAME into disk image staging directory"

/usr/bin/ditto \
  "$APP_PATH" \
  "$STAGING_DIRECTORY/$APP_NAME"

echo "Adding Application shortcut"

/bin/ln -s \
  /Applications \
  "$STAGING_DIRECTORY/Applications"

echo "Creating $OUTPUT_PATH"

/usr/bin/hdiutil create \
  -srcfolder "$STAGING_DIRECTORY" \
  -volname "$VOLUME_NAME" \
  -fs APFS \
  -format UDZO \
  "$OUTPUT_PATH"

echo "Verifying disk image"

/usr/bin/hdiutil verify "$OUTPUT_PATH"

echo "Created disk image: $OUTPUT_PATH"
