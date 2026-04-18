#!/usr/bin/env bash

# Exit on error
set -e

APP_NAME="move-center-window"
BIN_DIR="$HOME/bin"
SYSTEMD_DIR="$HOME/.config/systemd/user"

echo "--- Installing $APP_NAME ---"

# 1. Create directories if they don't exist
mkdir -p "$BIN_DIR"
mkdir -p "$SYSTEMD_DIR"

# 2. Install the script
echo "Installing script to $BIN_DIR..."
# Ensure we are copying from the correct path relative to the repo root
if [ -f "bin/move-center-window.sh" ]; then
    cp bin/move-center-window.sh "$BIN_DIR/"
else
    cp move-center-window.sh "$BIN_DIR/"
fi
chmod +x "$BIN_DIR/move-center-window.sh"

# 3. Install the systemd service
echo "Installing systemd service..."
cp "move-center-window.service" "$SYSTEMD_DIR/"

# 4. Reload systemd and start
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload

echo "Enabling and starting service..."
systemctl --user enable "$APP_NAME.service"
systemctl --user restart "$APP_NAME.service"

echo "--- Installation Complete ---"
echo "Status:"
systemctl --user status "$APP_NAME.service" | grep "Active:"