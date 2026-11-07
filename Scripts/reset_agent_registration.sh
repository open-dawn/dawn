#!/bin/bash
# Fixes dawnApp ↔ dawnAgent XPC handshake failures caused by a stale launchd
# Lightweight Code Requirement (LWCR) after Debug or Release rebuilds, or after
# moving DAWN.app while an old SMAppService login-item job still points at it.
#
# Symptoms:
#   - dawnAgent process is running, but dawnApp stays disconnected
#   - UI shows agent disconnected / handshake failed
#   - `launchctl print gui/$(id -u)/app.opendawn.dawnAgent` shows
#     `needs LWCR update`, `last exit code = 78: EX_CONFIG`, `job state = spawn failed`
#
# This is NOT an Xcode "codesign --remove-signature on all targets" build phase.
# Stripping signatures alone does not refresh launchd's managed LWCR; you must
# reset Background Task Management and let DAWN re-register the login item.

set -euo pipefail

PRODUCTS="${1:-}"
if [[ -z "${PRODUCTS}" ]]; then
  PRODUCTS="$(
    /usr/bin/find "${HOME}/Library/Developer/Xcode/DerivedData" \
      \( -path '*/Build/Products/Release/DAWN.app' -o -path '*/Build/Products/Debug/DAWN.app' \) \
      -print \
      2>/dev/null |
      /usr/bin/awk '
        /\/Release\/DAWN\.app$/ { print; found=1; exit }
        /\/Debug\/DAWN\.app$/ { debug=$0 }
        END { if (!found && debug != "") print debug }
      ' || true
  )"
  PRODUCTS="${PRODUCTS%/DAWN.app}"
fi

APP="${PRODUCTS}/DAWN.app"
if [[ ! -d "${APP}" ]]; then
  echo "error: DAWN.app not found under DerivedData products" >&2
  echo "usage: $0 [/path/to/Build/Products/Debug|Release]" >&2
  exit 1
fi

echo "Using ${APP}"

/usr/bin/killall dawnAgent DAWN 2>/dev/null || true
/bin/launchctl bootout "gui/$(/usr/bin/id -u)/app.opendawn.dawnAgent" 2>/dev/null || true

echo "Resetting Background Task Management database…"
/usr/bin/sfltool resetbtm
echo "BTM reset. Other apps may ask to re-enable login/background items."

echo "Launching DAWN so it re-registers dawnAgent…"
/usr/bin/open "${APP}"
/bin/sleep 4

if /usr/bin/pgrep -xq dawnAgent || /usr/bin/pgrep -f 'app.opendawn.dawnAgent' >/dev/null; then
  echo "dawnAgent is running."
else
  echo "warning: dawnAgent is not running yet." >&2
  echo "Check System Settings → General → Login Items & Extensions and allow DAWN / dawnAgent." >&2
fi

echo
echo "launchctl status:"
/bin/launchctl print "gui/$(/usr/bin/id -u)/app.opendawn.dawnAgent" 2>&1 \
  | /usr/bin/grep -E 'job state|needs LWCR|runs|last exit|state =' || true
