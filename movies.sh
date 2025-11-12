#!/bin/bash

MEDIA_DIRS=(
  "$HOME/ENT/Movies/"
  "$HOME/ENT/TV Shows/"
)

PLAYER="mpv"

if ! command -v $PLAYER &>/dev/null; then
  echo "'$PLAYER' is not installed. Please install it."
  exit 1
fi

if ! command -v fzf &>/dev/null; then
  echo "'fzf' is not installed. Please install it."
  exit 1
fi

media_list=$(find "${MEDIA_DIRS[@]}" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.avi" -o -name "*.webm" \) 2>/dev/null)

if [ -z "$media_list" ]; then
  echo "No media files found in the DIR."
  exit 1
fi

selected_file=$(echo "$media_list" | fzf --prompt="Select Media: " --height=40% --layout=reverse --border)

if [ -n "$selected_file" ]; then
  echo "Playing $selected_file..."
  setsid $PLAYER "$selected_file" &>/dev/null &
else
  echo "No file selected. Exiting..."
fi
