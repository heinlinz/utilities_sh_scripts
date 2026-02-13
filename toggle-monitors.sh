#!/bin/bash
# ~/.config/hypr/toggle-monitor.sh
# Cycle: Laptop -> Mirror -> External -> Laptop

INTERNAL="eDP-1"
EXTERNAL="HDMI-A-1"
STATUS_FILE="/sys/class/drm/card1-HDMI-A-1/status"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/toggle-monitor.state"

is_hdmi_connected() {
  [ -f "$STATUS_FILE" ] || return 1
  grep -q "connected" "$STATUS_FILE"
}

# Ensure state file exists
[ -f "$STATE_FILE" ] || echo "laptop" >"$STATE_FILE"
CURRENT_STATE="$(cat "$STATE_FILE" 2>/dev/null || echo laptop)"

# 1. Safety Check: If HDMI unplugged, force laptop mode immediately
if ! is_hdmi_connected; then
  hyprctl keyword monitor "$INTERNAL,preferred,auto,1.666667"
  hyprctl keyword monitor "$EXTERNAL,disable"
  echo "laptop" >"$STATE_FILE"
  notify-send "tm" "Laptop-only (HDMI disconnected)"
  exit 0
fi

# 2. Determine Next State (3-way toggle)
case "$CURRENT_STATE" in
"laptop")
  NEXT_STATE="mirror"
  ;;
"mirror")
  NEXT_STATE="external"
  ;;
"external")
  NEXT_STATE="laptop"
  ;;
*)
  NEXT_STATE="laptop"
  ;;
esac

# 3. Apply Next State
case "$NEXT_STATE" in
"mirror")
  # Enable Internal
  hyprctl keyword monitor "$INTERNAL,preferred,auto,1.666667"
  # Enable External and mirror the Internal one
  # Syntax: monitor=NAME,resolution,position,scale,mirror,SOURCE
  hyprctl keyword monitor "$EXTERNAL,1920x1080@120.00,auto,1,mirror,$INTERNAL"
  notify-send "tm" "Mirror Mode (Cloning $INTERNAL)"
  ;;

"external")
  # Step 1: Fully remove mirror state
  hyprctl keyword monitor "$EXTERNAL,disable"
  sleep 0.3

  # Step 2: Recreate HDMI as independent monitor
  hyprctl keyword monitor "$EXTERNAL,1920x1080@120.00,auto,1"
  sleep 0.5

  # Step 3: Focus it so Hyprland attaches workspace
  # hyprctl dispatch focusmonitor "$EXTERNAL"
  # sleep 0.3
  hyprctl keyword monitor "$INTERNAL,disable"
  notify-send "tm" "External-only ($EXTERNAL)"
  ;;

"laptop")
  # Enable Internal, Disable External
  hyprctl keyword monitor "$INTERNAL,preferred,auto,1.666667"
  hyprctl keyword monitor "$EXTERNAL,disable"
  notify-send "tm" "Laptop-only ($INTERNAL)"
  ;;
esac

# 4. Save new state
echo "$NEXT_STATE" >"$STATE_FILE"
