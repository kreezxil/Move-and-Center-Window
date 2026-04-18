#!/usr/bin/env bash

# File to track PIDs across loops
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
    current_pids=$(echo "$current_data" | awk '{print $2}' | sort -u)

    # Clean up tracked_pids: remove PIDs that are no longer running
    # This handles the "after they full closed once" requirement
    new_tracked_pids=""
    for p in $tracked_pids; do
        if kill -0 "$p" 2>/dev/null; then
            new_tracked_pids="$new_tracked_pids $p"
        fi
    done
    tracked_pids=$(echo "$new_tracked_pids" | tr ' ' '\n' | sort -u)

    # Check each current window
    while read -r w_id w_pid; do
        [[ -z "$w_id" ]] && continue

        # Only proceed if this PID is NOT in our tracked list
        if ! echo "$tracked_pids" | grep -qxw "$w_pid"; then
            
            # 1. Get Mouse Location
            eval "$(xdotool getmouselocation --shell 2>/dev/null)" || continue

            # 2. Identify Monitor
            monitor_geo=$(xrandr --listactivemonitors | grep -v "Monitors" | awk -v x="$X" -v y="$Y" '{
                split($3, a, "/|x|\\+|\\+");
                w=a[1]; h=a[3]; off_x=a[5]; off_y=a[6];
                if (x >= off_x && x < off_x + w && y >= off_y && y < off_y + h) {
                    print w, h, off_x, off_y
                }
            }')
            read -r m_w m_h m_x m_y <<< "$monitor_geo"

            # 3. Get Window Dimensions
            # Use || continue to handle windows that close mid-script (BadWindow fix)
            eval "$(xdotool getwindowgeometry --shell "$w_id" 2>/dev/null)" || continue

            # 4. Calculate Center
            target_x=$(( m_x + (m_w / 2) - (WIDTH / 2) ))
            target_y=$(( m_y + (m_h / 2) - (HEIGHT / 2) ))

            # 5. Move window
            wmctrl -i -r "$w_id" -e "0,$target_x,$target_y,-1,-1" 2>/dev/null || true

            # Mark this PID as tracked so we don't move its future/refresh windows
            tracked_pids="$tracked_pids $w_pid"
        fi
    done <<< "$current_data"

    sleep 0.5
done