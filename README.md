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
- The board resets weren't FEX. apport caught a `gnome-shell` SIGABRT from a GLib assertion in `meta_window_unmaximize()` (mutter 46.2-1ubuntu0.24.04.16), a minute before each reboot. I suspect Edge's maximize/unmaximize request on X11 triggers it, however I haven't proven that. See `findings/2026-10-09-gnome-shell-crash.md`.
- Headed Edge works in the GDM Wayland session. Native Wayland avoids the old X11 launch path and survived normal browsing, maximize/unmaximize, snapping, and resizing without a new crash report.
- GPU acceleration works through FEX's EGL/OpenGL thunk. Chromium reports ANGLE on freedreno/Adreno 623 with GPU compositing, rasterization, Canvas, WebGL, and WebGPU enabled. Do not pass `--disable-gpu`.
- `--no-sandbox` is still required: without it, Edge's zygote exits before startup. `--test-type` suppresses the persistent warning banner.
- `/dev/shm` is a 7.5 GB tmpfs on this board, so the launchers no longer pass `--disable-dev-shm-usage`; forcing Chromium shared memory through `/tmp` only adds overhead here.
- Pages render correctly. CJK text shows as boxes until `fonts-noto-cjk` goes in the rootfs.
- One Edge process hit a FEX SIGSEGV. No stack yet.

## Scripts

- `scripts/monitor.sh` - 1 Hz health log (load, memory, PSI, hottest thermal zone)
- `scripts/run-edge.sh` - runs Edge under FEX with native Wayland and GPU acceleration, a memory cap, and a watchdog that stops its dedicated scope on low memory or high temperature
- `scripts/microsoft-edge-wrapper.sh` - the plain launcher wrapper with the same Wayland/GPU defaults

## License

MIT
