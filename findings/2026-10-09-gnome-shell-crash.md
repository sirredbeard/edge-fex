# The board resets are gnome-shell, not FEX

apport caught it: `/var/crash/_usr_bin_gnome-shell.1000.crash`, dated Fri Oct 9 00:30:54 2026, a minute before the boot at 00:31.

- gnome-shell 46.0-0ubuntu6~24.04.15, libmutter-14-0 46.2-1ubuntu0.24.04.16, arm64
- SIGABRT from a GLib assertion inside `meta_window_unmaximize()` in libmutter
- Matches the "bright blue GUI, then the machine goes down" symptom: the shell dies, the session goes with it

See `crashes/gnome-shell-backtrace-excerpt.txt`.

The mutter update in the archive (46.2-1ubuntu0.24.04.18) doesn't mention anything related, only refresh rate tolerance and KMS timing. So I don't expect it to fix this.

I suspect Edge triggers it by asking for maximize/unmaximize on an X11 window in a way mutter doesn't like, however I haven't proven that. The window in `crashes/headed-edge-and-gnome-shell-crash-dialog.png` is the one Edge opened after a GUI launch, and that same session had the gnome-shell crash dialog up.

## Headed Edge works

Headed, `--disable-gpu`, X11 on :0, launched through `scripts/run-edge.sh`: window opens, example.com renders, translate bubble and all. CDP on 9333 answered. Page renders under FEX fine. Two things still wrong:

- CJK text shows as boxes. The rootfs needs `fonts-noto-cjk`.
- A FEX SIGSEGV (`/var/crash/_usr_bin_FEX.1000.crash`, 01:01:43) from one of the Edge processes. No stack in the report yet.

## The white dialog

The blank dialog in `edge_in_fex.png` was from an Edge launched without `--browser-subprocess-path`. I haven't reproduced it with the wrapper. First-run WebUI dialogs may just need `--no-first-run`.
