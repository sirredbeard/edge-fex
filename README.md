# edge-fex

Notes, logs, and scripts from getting the amd64 build of Microsoft Edge running under FEX on an arm64 Arduino VENTUNO Q.

This is a data dump for now. It will turn into a guide once it works reliably.

## Setup

- Board: Arduino VENTUNO Q (Qualcomm, arm64), Ubuntu, kernel 6.8.0-1089-qcom
- FEX: fex-emu-armv8.2 2610-1, binfmt_misc handlers registered for x86 and x86_64
- RootFS: Ubuntu 24.04 (`Ubuntu_24_04_edge`), Edge installed inside it
- Edge: microsoft-edge-stable 155.0.4283.45-1 (amd64)
- .NET: 10 removed, 11.0.100-rc.1 installed to `/usr/share/dotnet`

## Findings so far

- Edge's child processes (network service, GPU, zygote) die with `/proc/self/exe: 1: Syntax error: ")" unexpected`. Chromium re-executes `/proc/self/exe`, FEX hands that to `/bin/sh` as if it was a script, and dash chokes on the ELF header. Passing `--browser-subprocess-path=/opt/microsoft/msedge/msedge` works around it. See `findings/`.
- `--single-process` just trades it for a crashpad ptrace failure and a core dump.
- The board has hard-reset three times during testing, with no trace in the journal. `scripts/monitor.sh` logs health once a second with fsync so the last lines survive. I suspect memory or thermals, however I don't have evidence yet.

## Scripts

- `scripts/monitor.sh` - 1 Hz health log (load, memory, PSI, hottest thermal zone)
- `scripts/run-edge.sh` - runs Edge under FEX with a memory cap and a watchdog that kills it on low memory or high temperature
- `scripts/microsoft-edge-wrapper.sh` - the plain launcher wrapper

## License

MIT
