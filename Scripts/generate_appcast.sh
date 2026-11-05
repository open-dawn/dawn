#!/usr/bin/env bash

set -euo pipefail

usage() {
  echo "Usage: $0 <generate-appcast-path> <archives-directory> <output-appcast-path> <download-url-prefix> <release-notes-url-prefix> <expected-build-version> <expected-marketing-version>"
}

if [[ $# -ne 7 ]]; then
  usage >&2
  exit 64
fi

GENERATE_APPCAST_PATH="$1"
ARCHIVES_DIRECTORY="$2"
OUTPUT_APPCAST_PATH="$3"
DOWNLOAD_URL_PREFIX="$4"
RELEASE_NOTES_URL_PREFIX="$5"
EXPECTED_BUILD_VERSION="$6"
EXPECTED_MARKETING_VERSION="$7"

if [[ ! -x "$GENERATE_APPCAST_PATH" ]]; then
  echo "error: generate_appcast is not executable: $GENERATE_APPCAST_PATH" >&2
  exit 1
fi

if [[ ! -d "$ARCHIVES_DIRECTORY" ]]; then
  echo "error: archives directory not found: $ARCHIVES_DIRECTORY" >&2
  exit 1
fi

if [[ "$OUTPUT_APPCAST_PATH" != *.xml ]]; then
  echo "error: appcast output path must end in .xml" >&2
  exit 1
fi

if [[ "$DOWNLOAD_URL_PREFIX" != https://*/ ]]; then
  echo "error: download URL prefix must use HTTPS and end with /" >&2
  exit 1
fi

if [[ "$RELEASE_NOTES_URL_PREFIX" != https://*/ ]]; then
  echo "error: release notes URL prefix must use HTTPS and end with /" >&2
  exit 1
fi

shopt -s nullglob
DMG_PATHS=("$ARCHIVES_DIRECTORY"/*.dmg)
shopt -u nullglob

if [[ ${#DMG_PATHS[@]} -ne 1 ]]; then
  echo "error: expected exactly one DMG in $ARCHIVES_DIRECTORY" >&2
  exit 1
fi

ARCHIVE_BASENAME="$(basename "${DMG_PATHS[0]}" .dmg)"
RELEASE_NOTES_COUNT=0
RELEASE_NOTES_PATH=""

for extension in html md txt; do
  candidate="$ARCHIVES_DIRECTORY/$ARCHIVE_BASENAME.$extension"

  if [[ -f "$candidate" ]]; then
    RELEASE_NOTES_PATH="$candidate"
    ((RELEASE_NOTES_COUNT += 1))
  fi
done

if [[ "$RELEASE_NOTES_COUNT" -ne 1 ]]; then
  echo "error: expected exactly one release-notes file matching $ARCHIVE_BASENAME" >&2
  exit 1
fi

DMG_FILENAME="$(basename "${DMG_PATHS[0]}")"
EXPECTED_DOWNLOAD_URL="${DOWNLOAD_URL_PREFIX}${DMG_FILENAME}"
EXPECTED_CONTENT_LENGTH="$(/usr/bin/stat -f '%z' "${DMG_PATHS[0]}")"
EXPECTED_RELEASE_NOTES_URL="${RELEASE_NOTES_URL_PREFIX}$(basename "$RELEASE_NOTES_PATH")"

mkdir -p "$(dirname "$OUTPUT_APPCAST_PATH")"

"$GENERATE_APPCAST_PATH" \
  --ed-key-file - \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --release-notes-url-prefix "$RELEASE_NOTES_URL_PREFIX" \
  -o "$OUTPUT_APPCAST_PATH" \
  "$ARCHIVES_DIRECTORY"

if [[ ! -s "$OUTPUT_APPCAST_PATH" ]]; then
  echo "error: appcast was not generated: $OUTPUT_APPCAST_PATH" >&2
  exit 1
fi

/usr/bin/xmllint --noout "$OUTPUT_APPCAST_PATH"

ITEM_XPATH="(//*[local-name()='item'])[1]"

xml_value() {
  /usr/bin/xmllint \
    --xpath "string($1)" \
    "$OUTPUT_APPCAST_PATH"
}

BUILD_VERSION="$(xml_value "$ITEM_XPATH/*[local-name()='enclosure']/@*[local-name()='version']")"
MARKETING_VERSION="$(xml_value "$ITEM_XPATH/*[local-name()='enclosure']/@*[local-name()='shortVersionString']")"
DOWNLOAD_URL="$(xml_value "$ITEM_XPATH/*[local-name()='enclosure']/@url")"
CONTENT_LENGTH="$(xml_value "$ITEM_XPATH/*[local-name()='enclosure']/@length")"
ED_SIGNATURE="$(xml_value "$ITEM_XPATH/*[local-name()='enclosure']/@*[local-name()='edSignature']")"
MINIMUM_SYSTEM_VERSION="$(xml_value "$ITEM_XPATH/*[local-name()='minimumSystemVersion']")"
RELEASE_NOTES_URL="$(xml_value "$ITEM_XPATH/*[local-name()='releaseNotesLink']")"

for required_value in \
  "$BUILD_VERSION" \
  "$MARKETING_VERSION" \
  "$DOWNLOAD_URL" \
  "$CONTENT_LENGTH" \
  "$ED_SIGNATURE" \
  "$MINIMUM_SYSTEM_VERSION" \
  "$RELEASE_NOTES_URL"; do
  if [[ -z "$required_value" ]]; then
    echo "error: generated appcast is missing required update metadata" >&2
    exit 1
  fi
done

if [[ "$BUILD_VERSION" != "$EXPECTED_BUILD_VERSION" ]]; then
  echo "error: expected build $EXPECTED_BUILD_VERSION, found $BUILD_VERSION" >&2
  exit 1
fi

if [[ "$MARKETING_VERSION" != "$EXPECTED_MARKETING_VERSION" ]]; then
  echo "error: expected version $EXPECTED_MARKETING_VERSION, found $MARKETING_VERSION" >&2
  exit 1
fi

if [[ "$DOWNLOAD_URL" != "$EXPECTED_DOWNLOAD_URL" ]]; then
  echo "error: expected download URL $EXPECTED_DOWNLOAD_URL, found $DOWNLOAD_URL" >&2
  exit 1
fi

if [[ "$CONTENT_LENGTH" != "$EXPECTED_CONTENT_LENGTH" ]]; then
  echo "error: expected content length $EXPECTED_CONTENT_LENGTH, found $CONTENT_LENGTH" >&2
  exit 1
fi

if [[ "$RELEASE_NOTES_URL" != "$EXPECTED_RELEASE_NOTES_URL" ]]; then
  echo "error: expected release notes URL $EXPECTED_RELEASE_NOTES_URL, found $RELEASE_NOTES_URL" >&2
  exit 1
fi

echo "Generated appcast: $OUTPUT_APPCAST_PATH"
echo "Version: $MARKETING_VERSION ($BUILD_VERSION)"
