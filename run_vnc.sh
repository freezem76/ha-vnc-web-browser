#!/bin/bash

config="$1"

# Remove any existing VNC lock files
rm -rf /tmp/.X*-lock /tmp/.X11-unix

# Ensure a per-user DBus session is available for Chromium and other desktop services.
# `startup.sh` runs this script as `vnc_user`, so start a session bus here if one
# is not already present. Use `dbus-launch` (provided by `dbus-x11`).
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    if command -v dbus-launch >/dev/null 2>&1; then
        # Start a session bus and export its environment to this shell
        eval "$(dbus-launch --sh-syntax)" || true
        export DBUS_SESSION_BUS_ADDRESS
        export DBUS_SESSION_BUS_PID
        echo "Started DBus session: $DBUS_SESSION_BUS_ADDRESS"
    fi
fi

# Extract display configurations
displays=$(echo "$config" | jq -c '.displays[]')

# Loop through each display configuration
while IFS= read -r display; do
    url=$(echo $display | jq -r '.url')
    resolution=$(echo $display | jq -r '.resolution')
    port=$(echo $display | jq -r '.port')
    depth=$(echo $display | jq -r '.depth // 16')
    view_only=$(echo $display | jq -r '.view_only // false')
    browser_args=$(echo $display | jq -r '.browser_args // ""')
    display_number=$((port - 5900))

    # Split resolution into width and height
    width=$(echo $resolution | cut -d'x' -f1)
    height=$(echo $resolution | cut -d'x' -f2)

    # Build VNC server options
    vnc_opts="-geometry ${width}x${height} -depth ${depth} -nevershared -rfbport $port -alwaysshared"
    if [ "$view_only" = "true" ]; then
        vnc_opts="$vnc_opts -viewonly"
    fi

    # Start a new VNC server for this display
    if [ ! -f "/home/vnc_user/.vnc/passwd" ]; then
        echo "Starting VNC server without password for display $display_number"
        Xvnc :$display_number $vnc_opts &
    else
        echo "Starting VNC server with password for display $display_number"
        Xvnc :$display_number $vnc_opts -rfbauth /home/vnc_user/.vnc/passwd &
    fi

    # Wait a moment for the VNC server to start
    sleep 2

    # Set the display resolution if RandR is available for this X server
    if DISPLAY=:$display_number xrandr -q >/dev/null 2>&1 ; then
        DISPLAY=:$display_number xrandr --output default --mode ${width}x${height}
    else
        echo "RandR not available for display $display_number; skipping xrandr"
    fi

    # Start Chromium in kiosk mode for this display
    DISPLAY=:$display_number chromium --new-window --no-sandbox --disable-gpu --kiosk --window-size=${width},${height} --window-position=0,0 --no-first-run --no-default-browser-check --disable-translate --disable-infobars --disable-suggestions-service --disable-save-password-bubble --user-data-dir="/data/chromium-data-$display_number" --load-preferences="/home/vnc_user/chromium_preferences.json" $browser_args "$url" &
done <<< "$displays"

# Keep the script running
tail -f /dev/null 