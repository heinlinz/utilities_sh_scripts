#!/bin/bash

EDITOR="nvim"

CONFIG_DIR=(
  "$HOME/.config/hypr/"
  "$HOME/.local/share/omarchy/default/hypr/"
  "$HOME/.config/waybar/"
  "$HOME/.config/walker/"
  "$HOME/.config/swayosd/"
)

if ! command -v $EDITOR &>/dev/null; then
  echo "'$EDITOR is not installed. Please install it first."
  exit 1
fi

if ! command -v fzf &>/dev/null; then
  echo "'fzf' is not installed. Please install it first."
  exit 1
fi

config_files=$(find "${CONFIG_DIR[@]}" -type f -not -path "*.git" 2>/dev/null)

if [ -z "$config_files" ]; then
  echo "No config files found in the DIR"
  exit 1
fi

selected_file=$(echo "$config_files" | fzf --prompt="Select config file: " --height=50% --layout=reverse --border)

if [ -n "$selected_file" ]; then
  $EDITOR "$selected_file"
else
  echo "No files selected. Exiting..."
fi
