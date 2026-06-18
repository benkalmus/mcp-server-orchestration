#!/bin/sh
# Cleanup orphaned Chromium processes older than TIMEOUT_MINUTES
# Runs every CHECK_INTERVAL seconds
# Kills entire process group (parent + children) via kill -9 -PID

TIMEOUT_MINUTES=${CLEANUP_TIMEOUT_MINUTES:-20}
CHECK_INTERVAL=${CLEANUP_CHECK_INTERVAL:-60}

echo "[cleanup] Started. Killing Chromium process groups older than ${TIMEOUT_MINUTES}m. Checking every ${CHECK_INTERVAL}s."

while true; do
  sleep "$CHECK_INTERVAL"
  
  # Find main chrome processes (not type=renderer/utility/zygote/gpu)
  # These are the browser process leaders. Killing them kills the whole group.
  pids=$(ps -eo pid,etimes,comm 2>/dev/null | while read pid etimes comm; do
    if echo "$comm" | grep -q "chrome"; then
      # Only target main browser processes (not child types)
      cmd=$(cat /proc/$pid/cmdline 2>/dev/null | tr '\0' ' ')
      if echo "$cmd" | grep -qv "type="; then
        age_min=$(( etimes / 60 ))
        if [ "$age_min" -ge "$TIMEOUT_MINUTES" ]; then
          echo "$pid"
        fi
      fi
    fi
  done)
  
  if [ -n "$pids" ]; then
    count=$(echo "$pids" | wc -l)
    echo "[cleanup] Killing $count Chromium browser process group(s) older than ${TIMEOUT_MINUTES}m"
    # Kill entire process group (negative PID kills process group)
    echo "$pids" | while read pid; do
      kill -9 -"$pid" 2>/dev/null || kill -9 "$pid" 2>/dev/null
    done
  fi
done
