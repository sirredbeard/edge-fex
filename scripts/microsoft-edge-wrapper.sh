#!/bin/sh
# Run x86_64 Microsoft Edge under FEX.
# --browser-subprocess-path avoids FEX returning ENOEXEC for execve("/proc/self/exe"),
# which otherwise kills the network/GPU/renderer child processes.
# The memory cap stops a runaway Edge from taking the whole board down.
EDGE=/opt/microsoft/msedge/msedge
exec systemd-run --user --scope --quiet -p MemoryMax=8G -p MemorySwapMax=0 \
  FEX "$EDGE" --browser-subprocess-path="$EDGE" --no-sandbox --disable-dev-shm-usage "$@"
