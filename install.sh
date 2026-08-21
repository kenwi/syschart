#!/usr/bin/env bash
#
# install.sh - install the syschart/sysprobe tools for the current user.
#
# Usage:
#   ./install.sh [--interval SECONDS] [--no-start] [--uninstall]
#
#   --interval N     seconds between system samples (default 5)
#   --no-start       install files but do not enable/start the systemd service
#   --uninstall      remove the service and scripts
#
# Installs to:
#   ~/.local/bin/sysprobe, ~/.local/bin/syschart
#   ~/.config/systemd/user/sysprobe.service
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BIN_DIR="${SYSPROBE_BIN_DIR:-$HOME/.local/bin}"
SYSTEMD_USER_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sysprobe"
INTERVAL=5
NO_START=0
UNINSTALL=0

usage() {
    sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --no-start)
            NO_START=1
            shift
            ;;
        --uninstall)
            UNINSTALL=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "install.sh: unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 1 ]]; then
    echo "install.sh: invalid --interval: $INTERVAL (must be >= 1)" >&2
    exit 1
fi

write_service() {
    local unit="$SYSTEMD_USER_DIR/sysprobe.service"
    mkdir -p "$SYSTEMD_USER_DIR"
    printf '[Unit]\nDescription=Sample CPU/memory/load/temperature every %s seconds to a log\n\n' "$INTERVAL" > "$unit"
    printf '[Service]\nType=simple\nExecStart=%s/sysprobe --loop --interval %s\n' "$BIN_DIR" "$INTERVAL" >> "$unit"
    printf 'Restart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=default.target\n' >> "$unit"
    echo "  $unit"
}

do_install() {
    echo "Installing syschart..."
    mkdir -p "$BIN_DIR"
    install -m 0755 "$SCRIPT_DIR/bin/sysprobe" "$BIN_DIR/sysprobe"
    install -m 0755 "$SCRIPT_DIR/bin/syschart" "$BIN_DIR/syschart"
    echo "  $BIN_DIR/sysprobe"
    echo "  $BIN_DIR/syschart"

    write_service

    if [[ "$NO_START" -eq 0 ]]; then
        if command -v systemctl >/dev/null && [[ -n "${XDG_RUNTIME_DIR:-}" ]] && systemctl --user is-system-running >/dev/null 2>&1; then
            systemctl --user daemon-reload
            systemctl --user enable sysprobe.service
            systemctl --user restart sysprobe.service
            echo "Service enabled and started."
        else
            echo "No user systemd session detected — skipping service start."
            echo "Start it later with: systemctl --user enable --now sysprobe"
        fi
    else
        echo "Skipped service start (--no-start)."
        echo "Start it later with: systemctl --user enable --now sysprobe"
    fi

    echo
    echo "Done. Try: syschart  (or syschart --show for the interactive chart)"
}

do_uninstall() {
    echo "Uninstalling syschart..."
    if command -v systemctl >/dev/null && [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
        systemctl --user disable --now sysprobe.service 2>/dev/null || true
        systemctl --user daemon-reload
        echo "  service stopped and disabled"
    fi
    rm -f "$SYSTEMD_USER_DIR/sysprobe.service"
    echo "  removed $SYSTEMD_USER_DIR/sysprobe.service"
    rm -f "$BIN_DIR/sysprobe" "$BIN_DIR/syschart"
    echo "  removed scripts from $BIN_DIR"
    if [[ -d "$STATE_DIR" ]]; then
        rm -rf "$STATE_DIR"
        echo "  removed log data $STATE_DIR"
    fi
    echo "Done."
}

if [[ "$UNINSTALL" -eq 1 ]]; then
    do_uninstall
else
    do_install
fi
