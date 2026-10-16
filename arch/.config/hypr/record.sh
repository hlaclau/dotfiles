#!/usr/bin/env bash
# Toggle a screen recording: select a region, record it with the desktop audio to
# ~/Videos/Recordings; run again to stop. The start time goes in $XDG_RUNTIME_DIR/recording-start
# for the quickshell island.
set -u

state="${XDG_RUNTIME_DIR:-/tmp}/recording-start"

if pid=$(pgrep -x wf-recorder); then
  kill -INT $pid # SIGINT: wf-recorder finalizes the file
  exit 0
fi

sleep 0.3 # let the key release and the island close before selecting
region=$(slurp) || exit 0
dir="$HOME/Videos/Recordings"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"

date +%s > "$state"
trap 'rm -f "$state"' EXIT
wf-recorder -g "$region" --audio="$(pactl get-default-sink).monitor" -f "$file" > /dev/null 2>&1
notify-send -a Recorder -i video-x-generic "Recording saved" "$file"
