#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ELECTRON="/usr/local/share/electron42/electron"
APP_DIR="${SCRIPT_DIR}/out"
GIT_DIR="${APP_DIR}/git"

# Ensure window icon exists
if [ ! -f "${APP_DIR}/static/icon-logo.png" ]; then
    cp "${SCRIPT_DIR}/app/static/linux/icon-logo.png" \
       "${APP_DIR}/static/icon-logo.png" 2>/dev/null || true
fi

if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    eval "$(dbus-launch --sh-syntax)" 2>/dev/null || true
fi

if ! pgrep -x gnome-keyring-d >/dev/null 2>&1; then
    dbus-send --session --dest=org.freedesktop.DBus \
        --type=method_call --print-reply \
        /org/freedesktop/DBus org.freedesktop.DBus.ListNames \
        >/dev/null 2>&1 || true
fi

export LOCAL_GIT_DIRECTORY="${GIT_DIR}"
exec "${ELECTRON}" "${APP_DIR}/main.js" "$@"
