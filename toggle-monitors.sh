#!/bin/bash
# ~/.config/hypr/toggle-monitor.sh
# Toggle between laptop-only and external-only using DRM status (card1)

INTERNAL="eDP-1"
EXTERNAL="HDMI-A-1" # hyprctl name
STATUS_FILE="/sys/class/drm/card1-HDMI-A-1/status"
STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/toggle-monitor.state"

is_hdmi_connected() {
  [ -f "$STATUS_FILE" ] || return 1
  grep -q "connected" "$STATUS_FILE"
}

# Make sure we have a remembered state (default 'external' so first toggle goes laptop)
[ -f "$STATE_FILE" ] || echo "external" >"$STATE_FILE"
STATE="$(cat "$STATE_FILE" 2>/dev/null || echo external)"

if ! is_hdmi_connected; then
  # HDMI not physically connected → force laptop-only
  hyprctl keyword monitor "$INTERNAL,preferred,auto,1.666667"
  hyprctl keyword monitor "$EXTERNAL,disable"
  echo "laptop" >"$STATE_FILE"
  notify-send "tm" "Laptop-only (HDMI not detected)"
  exit 0
fi

# HDMI connected → toggle
if [ "$STATE" = "external" ]; then
  # Switch to laptop-only
  hyprctl keyword monitor "$INTERNAL,preferred,auto,1.666667"
  hyprctl keyword monitor "$EXTERNAL,disable"
  echo "laptop" >"$STATE_FILE"
  notify-send "tm" "Laptop-only ($INTERNAL)"
else
  # Switch to external-only (enable external first)
  hyprctl keyword monitor "$EXTERNAL,1920x1080@120.00,auto,1"
  hyprctl keyword monitor "$INTERNAL,disable"
  echo "external" >"$STATE_FILE"
  notify-send "tm" "External-only ($EXTERNAL)"
fi
