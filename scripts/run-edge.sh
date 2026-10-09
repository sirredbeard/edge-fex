#!/bin/bash
# Run x86_64 Edge under FEX with a watchdog that kills it before the board falls over.
# Kills Edge if MemAvailable < MIN_MB or the hottest thermal zone passes MAX_C.
# Usage: run-edge.sh [edge args...]   (env: MIN_MB=1500 MAX_C=90 MEM_CAP=6G)
MIN_MB=${MIN_MB:-1500}; MAX_C=${MAX_C:-90}; MEM_CAP=${MEM_CAP:-6G}
EDGE=/opt/microsoft/msedge/msedge
DIR=$(dirname "$(readlink -f "$0")")/../logs
STAMP=$(date +%Y%m%d-%H%M%S)
UNIT=edge-fex-$STAMP
mkdir -p "$DIR"; RUNLOG="$DIR/run-$STAMP.log"

# --browser-subprocess-path: FEX can't execve("/proc/self/exe") for Chromium children
# (they die with 'Syntax error: ")" unexpected'), so point Chromium at the real path.
# --no-sandbox is required because the zygote exits during sandbox setup under FEX.
# --test-type suppresses Chromium's persistent warning banner for --no-sandbox.
EDGE_ARGS=(
  --browser-subprocess-path="$EDGE"
  --no-sandbox
  --test-type
  --no-first-run
  --no-default-browser-check
)
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  EDGE_ARGS+=(--ozone-platform=wayland)
fi

systemd-run --user --scope --quiet --unit="$UNIT" -p MemoryMax="$MEM_CAP" -p MemorySwapMax=0 \
  FEX "$EDGE" "${EDGE_ARGS[@]}" "$@" \
  >"$RUNLOG" 2>&1 &
PID=$!
echo "pid=$PID unit=$UNIT.scope log=$RUNLOG"
while kill -0 $PID 2>/dev/null; do
  avail=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
  maxt=0; for z in /sys/class/thermal/thermal_zone*/temp; do t=$(cat $z 2>/dev/null) && [ "$t" -gt "$maxt" ] && maxt=$t; done
  if [ "$avail" -lt "$MIN_MB" ] || [ $((maxt/1000)) -ge "$MAX_C" ]; then
    echo "WATCHDOG kill: avail=${avail}MB temp=$((maxt/1000))C" | tee -a "$RUNLOG"
    systemctl --user stop "$UNIT.scope"
    break
  fi
  sleep 0.5
done
wait $PID 2>/dev/null; echo "exit=$?" >> "$RUNLOG"
