#!/bin/sh
# Cleanup orphaned Chromium processes older than TIMEOUT_MINUTES
# Runs every CHECK_INTERVAL seconds

TIMEOUT_MINUTES=${CLEANUP_TIMEOUT_MINUTES:-20}
CHECK_INTERVAL=${CLEANUP_CHECK_INTERVAL:-60}

echo "[cleanup] Started. Killing Chromium processes older than ${TIMEOUT_MINUTES}m. Checking every ${CHECK_INTERVAL}s."

while true; do
  sleep "$CHECK_INTERVAL"
  
  # Find chromium processes older than timeout
  pids=$(find /proc -maxdepth 1 -name '[0-9]*' -type d 2>/dev/null | while read pid_dir; do
    pid=$(basename "$pid_dir")
    exe=$(readlink "$pid_dir/exe" 2>/dev/null)
    if echo "$exe" | grep -q "chromium\|chrome"; then
      start_time=$(stat -c %Y "$pid_dir" 2>/dev/null)
      if [ -n "$start_time" ]; then
        now=$(date +%s)
        age_min=$(( (now - start_time) / 60 ))
        if [ "$age_min" -ge "$TIMEOUT_MINUTES" ]; then
          echo "$pid"
        fi
      fi
    fi
  done)
  
  if [ -n "$pids" ]; then
    count=$(echo "$pids" | wc -l)
    echo "[cleanup] Killing $count Chromium process(es) older than ${TIMEOUT_MINUTES}m"
    echo "$pids" | xargs kill -9 2>/dev/null
  fi
done
