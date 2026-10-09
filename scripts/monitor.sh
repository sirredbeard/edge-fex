#!/bin/bash
# Sample board health once a second into a log, fsync'd, so the last lines survive a hard crash.
# Usage: monitor.sh [logfile]
LOG=${1:-$HOME/edge-fex/logs/monitor-$(date +%Y%m%d-%H%M%S).log}
mkdir -p "$(dirname "$LOG")"
echo "# started $(date -Is) boot=$(cat /proc/sys/kernel/random/boot_id) uptime=$(cut -d' ' -f1 /proc/uptime)" >> "$LOG"
while true; do
  maxt=0; maxz=""
  for z in /sys/class/thermal/thermal_zone*; do
    t=$(cat "$z/temp" 2>/dev/null) || continue
    [ "$t" -gt "$maxt" ] && { maxt=$t; maxz=$(cat "$z/type"); }
  done
  mem=$(awk '/MemAvailable/{a=$2}/SwapFree/{s=$2}/^Dirty/{d=$2}END{printf "avail_mb=%d swapfree_mb=%d dirty_kb=%d",a/1024,s/1024,d}' /proc/meminfo)
  psi=$(awk '/some/{printf "%s ",$2}' /proc/pressure/memory 2>/dev/null)
  top=$(ps -eo rss,comm --sort=-rss | awk 'NR>1&&NR<=4{printf "%s:%dM ",$2,$1/1024}')
  edge=$(pgrep -fc 'msedge|FEX' )
  echo "$(date +%T) load=$(cut -d' ' -f1-3 /proc/loadavg) $mem memPSI=[$psi] maxtemp=$((maxt/1000))C($maxz) fex_procs=$edge top=[$top]" >> "$LOG"
  sync -d "$LOG" 2>/dev/null || sync
  sleep 1
done
