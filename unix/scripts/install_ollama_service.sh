#!/usr/bin/env bash
# Install Ollama as a systemd user or system service
set -euo pipefail

OLLAMA_HOST="${OLLAMA_HOST:-0.0.0.0}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
SERVICE_USER="${SERVICE_USER:-ollama}"
INSTALL_MODE="${1:-system}"   # system | user

UNIT_NAME="ollama"
OLLAMA_BIN="$(command -v ollama 2>/dev/null || echo /usr/local/bin/ollama)"

# --- helpers -----------------------------------------------------------------

die() { echo "ERROR: $*" >&2; exit 1; }

ensure_ollama() {
    if [[ -x "$OLLAMA_BIN" ]]; then return; fi
    echo "ollama not found — installing via official script..."
    curl -fsSL https://ollama.com/install.sh | sh
    OLLAMA_BIN="$(command -v ollama)"
}

# --- uninstall ---------------------------------------------------------------

if [[ "${1:-}" == "--uninstall" ]]; then
    if [[ "$EUID" -ne 0 ]]; then die "Uninstall requires root (sudo)."; fi
    systemctl stop  "$UNIT_NAME" 2>/dev/null || true
    systemctl disable "$UNIT_NAME" 2>/dev/null || true
    rm -f "/etc/systemd/system/${UNIT_NAME}.service"
    systemctl daemon-reload
    echo "Service '$UNIT_NAME' removed."
    exit 0
fi

# --- preflight ---------------------------------------------------------------

ensure_ollama

if [[ "$INSTALL_MODE" == "system" && "$EUID" -ne 0 ]]; then
    die "System-mode install requires root. Run: sudo $0 system\nFor user-mode: $0 user"
fi

# --- write unit file ---------------------------------------------------------

if [[ "$INSTALL_MODE" == "system" ]]; then
    # Create dedicated service user if absent
    if ! id "$SERVICE_USER" &>/dev/null; then
        useradd --system --shell /usr/sbin/nologin --home-dir /var/lib/ollama \
                --create-home "$SERVICE_USER"
        echo "Created user: $SERVICE_USER"
    fi

    UNIT_FILE="/etc/systemd/system/${UNIT_NAME}.service"
    LOG_DIR="/var/log/ollama"
    mkdir -p "$LOG_DIR"
    chown "$SERVICE_USER":"$SERVICE_USER" "$LOG_DIR"

    cat > "$UNIT_FILE" <<EOF
[Unit]
Description=Ollama LLM Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SERVICE_USER}
ExecStart=${OLLAMA_BIN} serve
Restart=on-failure
RestartSec=5
Environment="OLLAMA_HOST=${OLLAMA_HOST}:${OLLAMA_PORT}"
StandardOutput=append:${LOG_DIR}/ollama.log
StandardError=append:${LOG_DIR}/ollama-err.log

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now "$UNIT_NAME"

    echo ""
    echo "Service : $UNIT_NAME (system)"
    echo "Status  : $(systemctl is-active $UNIT_NAME)"
    echo "Endpoint: http://${OLLAMA_HOST}:${OLLAMA_PORT}"
    echo "Logs    : journalctl -u $UNIT_NAME -f   |   $LOG_DIR/"
    echo ""
    echo "Test: curl http://localhost:${OLLAMA_PORT}/api/tags"

else
    # User-mode (no root required, starts on login)
    UNIT_DIR="$HOME/.config/systemd/user"
    UNIT_FILE="${UNIT_DIR}/${UNIT_NAME}.service"
    mkdir -p "$UNIT_DIR"

    cat > "$UNIT_FILE" <<EOF
[Unit]
Description=Ollama LLM Service (user)
After=default.target

[Service]
Type=simple
ExecStart=${OLLAMA_BIN} serve
Restart=on-failure
RestartSec=5
Environment="OLLAMA_HOST=${OLLAMA_HOST}:${OLLAMA_PORT}"

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now "$UNIT_NAME"

    echo ""
    echo "Service : $UNIT_NAME (user)"
    echo "Status  : $(systemctl --user is-active $UNIT_NAME)"
    echo "Endpoint: http://${OLLAMA_HOST}:${OLLAMA_PORT}"
    echo "Logs    : journalctl --user -u $UNIT_NAME -f"
    echo ""
    echo "Test: curl http://localhost:${OLLAMA_PORT}/api/tags"
    echo ""
    echo "NOTE: Enable lingering so service survives logout:"
    echo "  loginctl enable-linger $USER"
fi
