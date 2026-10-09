#!/bin/sh
# Run x86_64 Microsoft Edge under FEX.
# --browser-subprocess-path avoids FEX returning ENOEXEC for execve("/proc/self/exe"),
# which otherwise kills the network/GPU/renderer child processes.
# The memory cap stops a runaway Edge from taking the whole board down.
EDGE=/opt/microsoft/msedge/msedge
if [ -n "${WAYLAND_DISPLAY:-}" ]; then
  set -- --ozone-platform=wayland "$@"
fi
exec systemd-run --user --scope --quiet -p MemoryMax=8G -p MemorySwapMax=0 \
  FEX "$EDGE" --browser-subprocess-path="$EDGE" --no-sandbox --test-type \
  --no-first-run --no-default-browser-check "$@"
