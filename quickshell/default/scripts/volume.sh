#!/bin/bash
# Emits "pct|muted" for the default audio sink, e.g. "72|0" or "72|1"
out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
pct=$(echo "$out" | awk '{printf "%d", $2*100}')
muted=0
echo "$out" | grep -q MUTED && muted=1
echo "${pct}|${muted}"
