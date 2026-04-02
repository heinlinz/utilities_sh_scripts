#!/bin/bash
# ~/.config/hypr/toggle-monitor.sh
# Cycle: Laptop -> Mirror -> External -> Laptop
#
# Setup: chmod +x ~/.config/hypr/toggle-monitor.sh
# Bind in hyprland.conf:
#   bind = $mainMod, F7, exec, ~/.config/hypr/toggle-monitor.sh

INTERNAL="eDP-1"
EXTERNAL="HDMI-A-1"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/toggle-monitor.state"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log() { logger -t toggle-monitor "$*"; }

notify() { notify-send -a "Display" -t 3000 "Monitor" "$1"; }

# Dynamically find the sysfs status file for the external connector.
# Tries card0 then card1 then any cardN to be GPU-agnostic.
find_status_file() {
    for f in /sys/class/drm/card*-HDMI-A-1/status \
              /sys/class/drm/card*-DP-1/status \
              /sys/class/drm/card*-HDMI-A-2/status; do
        # glob expansion: pick first real file that exists
        [ -f "$f" ] && echo "$f" && return 0
    done
    return 1
}

is_hdmi_connected() {
    local sf
    sf=$(find_status_file) || return 1
    # sysfs reports "connected" (possibly with trailing whitespace/newline)
    grep -qi "^connected" "$sf"
}

# Verify the external monitor is actually recognised by Hyprland right now.
# Hyprctl exits 0 and outputs JSON even when disconnected, so we parse it.
is_hyprland_external_active() {
    hyprctl monitors -j 2>/dev/null \
        | grep -q "\"name\":\"${EXTERNAL}\""
}

apply() {
    # Wrapper: run hyprctl keyword, log on failure.
    hyprctl keyword monitor "$@" >/dev/null 2>&1 \
        || log "WARNING: 'hyprctl keyword monitor $*' returned non-zero"
}

# ---------------------------------------------------------------------------
# Detect connected resolution/refresh from Hyprland for the external monitor.
# Falls back to 1920x1080@60 if detection fails.
# ---------------------------------------------------------------------------
detect_external_mode() {
    local modes
    modes=$(hyprctl monitors all -j 2>/dev/null \
        | python3 -c "
import sys, json
monitors = json.load(sys.stdin)
for m in monitors:
    if m.get('name') == '${EXTERNAL}':
        # Prefer the first available mode reported by Hyprland
        modes = m.get('availableModes', [])
        if modes:
            print(modes[0])
            sys.exit(0)
        # Fallback: use current width/height/refreshRate fields
        w = m.get('width', 1920)
        h = m.get('height', 1080)
        r = m.get('refreshRate', 60)
        print(f'{w}x{h}@{r:.2f}')
        sys.exit(0)
" 2>/dev/null)
    echo "${modes:-1920x1080@60.00}"
}

# ---------------------------------------------------------------------------
# State bootstrap
# ---------------------------------------------------------------------------

mkdir -p "$(dirname "$STATE_FILE")"
[ -f "$STATE_FILE" ] || echo "laptop" > "$STATE_FILE"
CURRENT_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "laptop")

# ---------------------------------------------------------------------------
# Safety check: HDMI not physically connected → force laptop mode
# ---------------------------------------------------------------------------

if ! is_hdmi_connected; then
    apply "$INTERNAL,preferred,auto,1.333"
    apply "$EXTERNAL,disable"
    echo "laptop" > "$STATE_FILE"
    log "HDMI disconnected – forced laptop mode"
    notify "Laptop-only (HDMI disconnected)"
    exit 0
fi

# ---------------------------------------------------------------------------
# Determine next state
# ---------------------------------------------------------------------------

case "$CURRENT_STATE" in
    laptop)   NEXT_STATE="mirror"   ;;
    mirror)   NEXT_STATE="external" ;;
    external) NEXT_STATE="laptop"   ;;
    *)        NEXT_STATE="laptop"   ;;
esac

log "Transitioning: $CURRENT_STATE → $NEXT_STATE"

EXT_MODE=$(detect_external_mode)
log "External mode resolved: $EXT_MODE"

# ---------------------------------------------------------------------------
# Apply state
# ---------------------------------------------------------------------------

case "$NEXT_STATE" in

    mirror)
        apply "$INTERNAL,preferred,auto,1"
        sleep 0.2
        apply "$EXTERNAL,${EXT_MODE},auto,1,mirror,$INTERNAL"
        notify "Mirror mode (cloning $INTERNAL)"
        ;;

    external)
        # 1. Tear down any mirror state cleanly
        apply "$EXTERNAL,disable"
        sleep 0.4

        # 2. Bring up external as independent monitor
        apply "$EXTERNAL,${EXT_MODE},auto,1"
        sleep 0.5

        # 3. Move all workspaces that are currently on the internal
        #    to the external so no workspace gets stranded off-screen.
        #    hyprctl dispatch only works after the monitor is active.
        if is_hyprland_external_active; then
            WORKSPACES=$(hyprctl workspaces -j 2>/dev/null \
                | python3 -c "
import sys, json
ws = json.load(sys.stdin)
for w in ws:
    if w.get('monitor') == '${INTERNAL}':
        print(w['id'])
" 2>/dev/null)
            for WS_ID in $WORKSPACES; do
                hyprctl dispatch moveworkspacetomonitor "$WS_ID $EXTERNAL" >/dev/null 2>&1
            done
        fi

        # 4. Disable internal
        apply "$INTERNAL,disable"
        notify "External-only ($EXTERNAL  $EXT_MODE)"
        ;;

    laptop)
        apply "$INTERNAL,preferred,auto,1.3333"
        sleep 0.3

        # Move all workspaces from external back to internal before disabling
        if is_hyprland_external_active; then
            WORKSPACES=$(hyprctl workspaces -j 2>/dev/null \
                | python3 -c "
import sys, json
ws = json.load(sys.stdin)
for w in ws:
    if w.get('monitor') == '${EXTERNAL}':
        print(w['id'])
" 2>/dev/null)
            for WS_ID in $WORKSPACES; do
                hyprctl dispatch moveworkspacetomonitor "$WS_ID $INTERNAL" >/dev/null 2>&1
            done
        fi

        sleep 0.2
        apply "$EXTERNAL,disable"
        notify "Laptop-only ($INTERNAL)"
        ;;

esac

# ---------------------------------------------------------------------------
# Persist new state
# ---------------------------------------------------------------------------

echo "$NEXT_STATE" > "$STATE_FILE"
log "State saved: $NEXT_STATE"
