# Review of ~/arduino-management against these findings

Read only. Nothing in that repo was touched. It has commit da44b4b, "Run GNOME on demand through GDM", from 01:20 UTC.

## What it does

- Drops the old `startx` session (Xorg :0 on vt8, no GDM, no PAM/logind session).
- `launch_desktop.sh` starts `display-manager.service` on demand, you pick `Ubuntu on Wayland`, `stop_desktop.sh` stops GDM and goes back to the saved VT.
- GDM stays off at boot, default target stays `multi-user.target`.

## Does it help the Edge-in-FEX project

Partly, and it's a reasonable bet. Two caveats.

1. It avoids the X11 window path from the mutter backtrace only for native Wayland clients. Edge from the rootfs defaults to X11, so it would go through Xwayland and could hit the same `meta_window_unmaximize()` assertion. Edge needs `--ozone-platform=wayland` (or `--ozone-platform-hint=auto`) to actually dodge it.
2. Wayland under FEX is untested. The rootfs has Wayland client libs (6 `libwayland*` files), but the guest needs `XDG_RUNTIME_DIR=/run/user/1000` and `WAYLAND_DISPLAY` to reach the compositor socket. FEX should pass both through, I just haven't tried.

It also doesn't prove the cause. The crash dated 00:30:54 predates the current X11 session, and I only have the one backtrace.

## State right now

GDM is inactive. The session on screen is still the old X11 one (Xorg :0 vt8, gnome-shell as a plain process), so none of the new path has run yet.

## Test plan, once a GDM Wayland session is up

1. `echo $XDG_SESSION_TYPE` should say `wayland`.
2. `scripts/run-edge.sh --ozone-platform=wayland --disable-gpu --no-first-run --user-data-dir=/tmp/ew about:blank`
3. Maximize, unmaximize, snap, resize, and watch `logs/monitor-*.log` plus `/var/crash` for a new gnome-shell report.
4. Repeat with `--ozone-platform=x11` (Xwayland) to see if the assertion comes back.
