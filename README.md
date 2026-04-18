# Move Center Window

**Automatic X11 Window Placement**

A lightweight background utility that ensures newly opened application windows appear exactly where you are looking — on the monitor containing your mouse cursor.

---

## Features

- 🖱️ **Mouse-Aware** — Dynamically calculates monitor bounds and centers windows on the active screen based on cursor location.
- ⚙️ **Process Tracking** — Monitors PIDs to ensure apps only center on initial launch, preventing jumping during refreshes.
- 🛡️ **X11 Resilience** — Built-in error handling suppresses standard "BadWindow" race conditions.
- 🔄 **Systemd Native** — Runs cleanly as a user-level background service with automatic recovery.

---

## Compatibility

This utility is tightly coupled to the X11 display server.

### Environment Support

| Status       | Environment                          | Notes |
|--------------|--------------------------------------|-------|
| ✅ Supported | X11 with EWMH-compliant window managers (Muffin, Mutter, KWin, Xfce4, etc.) | Tested primarily on Linux Mint |
| ❌ Not Supported | **Wayland** | Wayland's security model breaks `xdotool` and `wmctrl` |
| ⚠️ Untested / Edge Cases | Tiled WMs (i3, bspwm), Non-systemd distros | May require manual configuration |

### Requirements Checklist

- `wmctrl` — Window management
- `xdotool` — Mouse & window querying
- `x11-xserver-utils` (or `xorg-xrandr` on Arch) — Display geometry
- `bash`
- `systemd` (recommended)

---

## Installation

### 1. Install Dependencies

**Debian / Ubuntu / Linux Mint:**
```bash
sudo apt update && sudo apt install wmctrl xdotool x11-xserver-utils
```

**Arch Linux:**
```bash
sudo pacman -S wmctrl xdotool xorg-xrandr
```

### 2. Install the Utility

#### Automated (Recommended)

```bash
chmod +x install.sh
./install.sh
```

#### Manual Installation

1. Move the script:
   ```bash
   mv move-center-window.sh ~/bin/
   ```

2. Move the systemd unit:
   ```bash
   mv move-center-window.service ~/.config/systemd/user/
   ```

3. Reload systemd:
   ```bash
   systemctl --user daemon-reload
   ```

4. Enable and start the service:
   ```bash
   systemctl --user enable --now move-center-window.service
   ```

---

## Codebase

### `move-center-window.sh`

```bash
#!/usr/bin/env bash

# Tracked PIDs to avoid re-centering apps already running or in tray
tracked_pids=""

get_window_data() {
    # Returns: "WindowID PID"
    wmctrl -lp 2>/dev/null | awk '{print $1, $3}'
}

# Initial state: Track what's already open to ignore them
tracked_pids=$(get_window_data | awk '{print $2}' | sort -u)

while true
do
    current_data=$(get_window_data)
    
    # Cleanup tracked_pids: remove PIDs no longer in the system
    new_tracked_pids=""
    for p in $tracked_pids; do
        if kill -0 "$p" 2>/dev/null; then
            new_tracked_pids="$new_tracked_pids $p"
        fi
    done
    tracked_pids=$(echo "$new_tracked_pids" | tr ' ' '\n' | sort -u)

    # Process each window found
    while read -r w_id w_pid; do
        [[ -z "$w_id" || -z "$w_pid" ]] && continue

        # Only proceed if this PID is NOT in our tracked list
        if ! echo "$tracked_pids" | grep -qxw "$w_pid"; then
            
            # 1. Get Mouse Location
            eval "$(xdotool getmouselocation --shell 2>/dev/null)" || continue

            # 2. Identify Monitor
            monitor_geo=$(xrandr --listactivemonitors | grep -v "Monitors" | awk -v x="$X" -v y="$Y" '{
                split($3, a, "/|x|\\\\+|\\\\+");
                w=a[1]; h=a[3]; off_x=a[5]; off_y=a[6];
                if (x >= off_x && x < off_x + w && y >= off_y && y < off_y + h) {
                    print w, h, off_x, off_y
                }
            }')
            read -r m_w m_h m_x m_y <<< "$monitor_geo"

            # 3. Get Window Dimensions (handle race conditions)
            eval "$(xdotool getwindowgeometry --shell "$w_id" 2>/dev/null)" || continue

            # 4. Calculate Center
            target_x=$(( m_x + (m_w / 2) - (WIDTH / 2) ))
            target_y=$(( m_y + (m_h / 2) - (HEIGHT / 2) ))

            # 5. Move window
            wmctrl -i -r "$w_id" -e "0,$target_x,$target_y,-1,-1" 2>/dev/null || true

            # Mark PID as tracked
            tracked_pids="$tracked_pids $w_pid"
        fi
    done <<< "$current_data"

    sleep 0.5
done
```

### `move-center-window.service`

```ini
[Unit]
Description=Center New Windows on Mouse Monitor
After=default.target

[Service]
Environment="DISPLAY=:0"
ExecStart=%h/bin/move-center-window.sh

# Restart Logic
Restart=always
RestartSec=3
# Disable rate limiting to handle rapid X11 bursts
StartLimitIntervalSec=0

[Install]
WantedBy=default.target
```

---

**License:** MIT  
**Environment:** X11 only

---

*Made for users who want new windows to appear where their mouse is.*
