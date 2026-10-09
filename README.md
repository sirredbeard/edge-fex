# edge-fex

<img width="1857" height="873" alt="HUKFq8EWEAAj2Iw" src="https://github.com/user-attachments/assets/1065a105-ea95-448f-95c2-33c521dffe2f" />

Run the amd64 build of [Microsoft Edge](https://www.microsoft.com/edge) under
[FEX-Emu](https://github.com/FEX-Emu/FEX) on an arm64
[Arduino VENTUNO Q](https://docs.arduino.cc/hardware/ventuno-q/), then attach
[Playwright](https://playwright.dev/) to the browser for automated web
browsing.

It is slow. It is also useful. The point of this project is to get Edge
running on the board with a persistent, authenticated browser profile.

I created a dedicated profile on this board, signed into my Microsoft account,
and signed into a handful of sites I want an agent to use.

## Why

I need my agents to browse the web for me from an authenticated browser profile and my home IP address. All my passwords are stored in Edge sync. I needed Edge to run in GUI mode so I could log into my Microsoft account, sync my passwords, and then log into a handful of sites that block the IP ranges my cloud agent was coming from. This way, my agent can browse the web on my behalf, from an authenicated profile, on my home IP address.

## What works

The current launch path is:

```text
FEX /opt/microsoft/msedge/msedge \
  --browser-subprocess-path=/opt/microsoft/msedge/msedge \
  --no-sandbox \
  --test-type \
  --ozone-platform=wayland
```

This starts the amd64 Edge binary on the arm64 board. The browser renders
normal pages, the network service and renderer children stay alive, and
Playwright can attach to Edge through the Chrome DevTools Protocol (CDP).

The working path uses the GDM `Ubuntu on Wayland` session. Headed Edge survived
normal browsing, maximize/unmaximize, snapping, and resizing in that session
without a new `gnome-shell` crash report.

GPU acceleration works through FEX's EGL/OpenGL thunk. Chromium reported ANGLE
over EGL/OpenGL on the Adreno 623, with GPU compositing, rasterization, Canvas,
WebGL, and WebGPU enabled.

The browser is still very very slow compared with native arm64 software. In a
15-second sample on a normal image-heavy page, the accelerated instance used
roughly 1.8 CPU cores. Memory remained below 2 GB, memory PSI stayed at zero,
and the hottest thermal zone stayed around 40-41 C.

This is Edge loading a page under FEX. The local account column and terminal
title are redacted:

![Edge renderer processes loading a page under FEX](screenshots/edge-loading-redacted.png)

This is the same browser at rest:

![Edge renderer processes at rest under FEX](screenshots/edge-rest-redacted.png)

## My setup

My setup that produced these results was:

- Arduino VENTUNO Q
- arm64 host kernel `6.8.0-1089-qcom`
- Ubuntu 24.04 rootfs named `Ubuntu_24_04_edge`
- `fex-emu-armv8.2` version `2610-1`
- FEX binfmt handlers registered for x86 and x86_64
- `microsoft-edge-stable` version `155.0.4283.45-1`, amd64

## How this works

There are three layers:

1. The VENTUNO Q runs an arm64 Linux userspace.
2. FEX translates the amd64 Edge executable and its child processes.
3. Edge uses the host Wayland compositor and host graphics stack through FEX's
   library thunks.

The rootfs contains the Edge installation at:

```text
/opt/microsoft/msedge/msedge
```

That path exists inside the rootfs. It does not exist as
`/opt/microsoft/msedge/msedge` in the host filesystem.

The repository scripts run that binary through `FEX`, put it in a user
systemd scope, cap its memory, and write the browser output to `logs/`.

You can confirm that a translated Edge helper is running without touching the
browser:

```bash
$ for pid in $(pgrep -f msedge_crashpad_handler); do
    printf '%s ' "$pid"
    readlink "/proc/$pid/exe"
  done
```

On this board the executable behind those x86_64 Edge helpers is
`/usr/bin/FEX`. The helper command line still names
`/opt/microsoft/msedge/msedge_crashpad_handler`.

### The child-process workaround

Chromium normally re-executes `/proc/self/exe` for the network service, GPU
process, zygote, and renderer children. Under this FEX setup, that path can
fall through to the rootfs `/bin/sh`. `dash` then tries to parse the FEX ELF
binary as a shell script and reports:

```text
/proc/self/exe: 1: Syntax error: ")" unexpected
```

Pass the real Edge path explicitly:

```text
--browser-subprocess-path=/opt/microsoft/msedge/msedge
```

Without that option, the parent process can appear to start while the network
and GPU children crash in a loop.

### The sandbox workaround

`--no-sandbox` is required on this FEX setup because the Edge zygote exits
during sandbox setup. `--test-type` hides the persistent warning banner caused
by `--no-sandbox`.

This is a local experimental setup. Do not treat it as a secure general
purpose browser.

### Wayland instead of X11

Use the GDM `Ubuntu on Wayland` session:

```bash
$ echo "$XDG_SESSION_TYPE"
wayland
```

The launcher adds `--ozone-platform=wayland` when `WAYLAND_DISPLAY` is set.
The Wayland path avoids the X11 launch path associated with the observed
`gnome-shell` SIGABRT in `meta_window_unmaximize()`.

## Steps to replicate

These are the steps used on the VENTUNO Q.

1. Install FEX on the arm64 host and configure an Ubuntu 24.04 rootfs in
   `$HOME/.fex-emu/Config.json`.
2. Install the amd64 `microsoft-edge-stable` package inside that rootfs.
3. Confirm that the `FEX-x86` and `FEX-x86_64` binfmt handlers are enabled.
4. Start a GDM `Ubuntu on Wayland` session and check that
   `$XDG_SESSION_TYPE` is `wayland`.
5. Run `./scripts/monitor.sh` in one terminal.
6. Run `./scripts/run-edge.sh` in another terminal.
7. Check that Edge opens and that the network and renderer processes remain
   alive.
8. Test a simple page, then test maximize, unmaximize, snapping, and resizing.
9. Create the dedicated profile described below.
10. Close headed Edge, start the same profile with `--headless=new` and CDP
   enabled, and attach Playwright.

## Make Edge the default browser

The VENTUNO Q already has a desktop entry for the FEX launcher:

```text
$HOME/.local/share/applications/microsoft-edge-fex.desktop
```

The desktop entry calls `/usr/local/bin/microsoft-edge-stable`, which runs the
amd64 Edge binary through FEX and adds the Wayland, child-process, sandbox, and
memory-limit arguments from `scripts/microsoft-edge-wrapper.sh`.

Set it as the default browser for the current desktop user:

```bash
$ xdg-settings set default-web-browser microsoft-edge-fex.desktop
$ xdg-mime default microsoft-edge-fex.desktop x-scheme-handler/http
$ xdg-mime default microsoft-edge-fex.desktop x-scheme-handler/https
$ xdg-mime default microsoft-edge-fex.desktop text/html
```

Check the result:

```bash
$ xdg-settings get default-web-browser
microsoft-edge-fex.desktop
$ xdg-mime query default x-scheme-handler/http
microsoft-edge-fex.desktop
$ xdg-mime query default x-scheme-handler/https
microsoft-edge-fex.desktop
$ xdg-mime query default text/html
microsoft-edge-fex.desktop
```

This changes future links and HTML files. It does not restart or replace an
Edge process that is already running, and it does not change the default
browser for another Linux user.

The scripts are the important part of the setup:

- [`scripts/run-edge.sh`](scripts/run-edge.sh) starts Edge in a memory-capped
  systemd scope and stops it if memory or temperature becomes unsafe.
- [`scripts/microsoft-edge-wrapper.sh`](scripts/microsoft-edge-wrapper.sh)
  provides the same Edge arguments without the watchdog loop.
- [`scripts/monitor.sh`](scripts/monitor.sh) records board health once a
  second, including memory PSI and temperature.


## Run Edge

Run the watchdog launcher:

```bash
$ ./scripts/run-edge.sh
```

The launcher:

- runs `/opt/microsoft/msedge/msedge` through `FEX`
- adds the child-process, sandbox, first-run, and Wayland arguments
- places Edge in a user systemd scope
- caps the scope at `MEM_CAP`, which defaults to `6G`
- stops the scope if available memory drops below `MIN_MB`, default `1500`
- stops the scope if the hottest thermal zone reaches `MAX_C`, default `90`
- writes stdout and stderr to a timestamped file under `logs/`

Override the watchdog values when testing:

```bash
$ MIN_MB=2000 MAX_C=85 MEM_CAP=6G ./scripts/run-edge.sh
```

Pass additional Edge arguments after the script:

```bash
$ ./scripts/run-edge.sh --no-first-run about:blank
```

The simpler wrapper uses an 8 GB memory cap and does not run the watchdog:

```bash
$ ./scripts/microsoft-edge-wrapper.sh
```

For a quick headless smoke test:

```bash
$ ./scripts/run-edge.sh \
    --headless=new \
    --dump-dom \
    about:blank
```

The earlier tests also returned exit code 0 for `about:blank` and
`https://example.com` with the child-process workaround. `--single-process`
is not a substitute. It led to a crashpad ptrace failure and exit code 139.

## Create the authenticated profile

The Edge profile contains cookies, local storage, tokens, history, and other browser state, useful for avoiding Bot blocks.

Choose a local path outside the checkout:

```bash
$ export EDGE_PROFILE="$HOME/.config/edge-fex-playwright"
$ mkdir -p "$EDGE_PROFILE"
```

Start headed Edge with the dedicated profile and the default loopback CDP
endpoint:

```bash
$ ./scripts/run-edge.sh \
    --user-data-dir="$EDGE_PROFILE" \
    --remote-debugging-port=9333
```

Sign into the Microsoft account in the Edge window, then sign into the small
set of sites that the agent is approved to use. Complete any multi-factor
authentication prompts in the headed browser.

The profile is the authenticated state. Close Edge cleanly after the sign-in
session finishes, then use the same `EDGE_PROFILE` for the headless launch.

## Run headless Edge for Playwright

Start the same profile without a visible browser window:

```bash
$ ./scripts/run-edge.sh \
    --headless=new \
    --user-data-dir="$EDGE_PROFILE" \
    --remote-debugging-port=9333
```

Do not start two Edge instances against the same profile at the same time.
Edge locks the profile, and concurrent writers can corrupt browser state.

The CDP endpoint is intentionally bound to `localhost`. Do not replace that
with a LAN address or forward the port outside the board. Anyone who can reach
the DevTools endpoint can generally drive the authenticated browser.

Check that the endpoint answers from the board without printing the browser
WebSocket URL into a shared log:

```bash
$ curl --silent http://localhost:9333/json/version | sed \
    -E 's#("webSocketDebuggerUrl"[[:space:]]*:[[:space:]]*")[^"]+#\1<redacted>#'
```

If the command returns JSON containing a browser version and a redacted
`webSocketDebuggerUrl`, Edge is ready for Playwright.

## Use Playwright over CDP

Install Playwright Core in the agent's own project, not in the Edge rootfs:

```bash
$ npm install playwright-core
```

Attach to the already-running browser:

```javascript
const { chromium } = require("playwright-core");

const browser = await chromium.connectOverCDP("http://localhost:9333");
const [context] = browser.contexts();
if (!context) {
  throw new Error("Edge did not expose the persistent profile context");
}
const page = context.pages()[0] || await context.newPage();

await page.goto("https://example.com", { waitUntil: "domcontentloaded" });
console.log(await page.title());
```

The first context is the profile loaded by Edge, so cookies and local storage
from the headed sign-in session are available to Playwright. Do not call
`browser.close()` if Edge should remain available for the next task. Ending the
agent process drops the CDP connection without asking Edge to shut down.

For a long-running agent, keep the browser lifecycle outside the page task:

1. Start Edge with the dedicated profile and CDP enabled.
2. Wait for `http://localhost:9333/json/version`.
3. Connect Playwright over CDP.
4. Reuse the existing context for browser tasks.
5. Close the connection when the task ends.
6. Stop the Edge systemd scope when no more tasks need the profile.

## Monitor the board

Start the one-second health logger before a long Edge run:

```bash
$ ./scripts/monitor.sh
```

Or choose a log file:

```bash
$ ./scripts/monitor.sh "$HOME/edge-fex/logs/monitor-wayland.log"
```

The monitor records load, available memory, swap, dirty pages, memory PSI,
thermal temperature, the number of FEX and Edge processes, and the largest
processes. It calls `sync` after each line so the tail is more likely to
survive a hard reset.

## Troubleshooting

### Edge starts, then the network service or GPU process dies

Check the launcher arguments:

```bash
$ ps -eo pid,comm,args | grep '[m]sedge'
```

The command line must contain:

```text
--browser-subprocess-path=/opt/microsoft/msedge/msedge
--no-sandbox
```

The first option fixes the `/proc/self/exe` and shell-parser failure. The
second is required by the current FEX sandbox behavior.

### Edge opens a window and the board resets

Check `/var/crash` and the monitor log before blaming FEX. The earlier resets
were associated with an arm64 `gnome-shell` SIGABRT from a GLib assertion in
`meta_window_unmaximize()`, not a memory or thermal event from FEX.

Use the GDM Wayland session and native Wayland:

```bash
$ echo "$XDG_SESSION_TYPE"
$ ./scripts/run-edge.sh --ozone-platform=wayland
```

Then test maximize, unmaximize, snapping, and resizing one at a time while
watching the monitor log.

### CJK text renders as boxes

Install the missing CJK font package inside the Ubuntu 24.04 Edge rootfs:

```bash
$ sudo apt install fonts-noto-cjk
```

The command must run against the rootfs that contains
`/opt/microsoft/msedge/msedge`, not an unrelated host userspace.

### Hardware video decode reports a VAAPI error

The logs contain a VAAPI initialization error and no video decode profiles.
The rest of the graphics path remains usable. GPU compositing, rasterization,
Canvas, WebGL, and WebGPU were enabled, so do not disable the whole GPU path
just to hide the video decode warning.

### `--single-process` crashes

Do not use it as a workaround. The recorded run failed in crashpad ptrace
setup and exited with code 139.

### Playwright cannot connect

Check the following:

1. Edge is still running with `--remote-debugging-port=9333`.
2. Playwright uses `http://localhost:9333`, not a stale WebSocket URL.
3. The profile is not locked by another Edge process.
4. The CDP endpoint is ready before Playwright connects.
5. The agent and Edge are on the same board or are using an explicitly
   protected local forwarding mechanism.

Do not bind CDP to all interfaces as a debugging shortcut.

## Known limitations

- FEX translation makes Edge noticeably slow, especially with several tabs or
  JavaScript-heavy pages.
- The current launch requires `--no-sandbox`, so this is not a hardened
  general-purpose browser deployment.
- One Edge process produced a FEX SIGSEGV.
- Hardware video decode is not working.
- CJK fonts are missing until `fonts-noto-cjk` is installed in the rootfs.
- GNOME still emitted nonfatal Wayland assertions about compositor surface
  configuration.
- The Edge, FEX, Ubuntu, kernel, and board versions in this document can drift.
  Recheck them before treating an old result as a regression.

## Repository layout

```text
edge-fex/
├── findings/                         # investigation notes and crash excerpts
├── logs/                             # sanitized browser and board logs
├── screenshots/                      # redacted performance captures
├── scripts/
│   ├── microsoft-edge-wrapper.sh     # simple scoped Edge launcher
│   ├── monitor.sh                    # one-second board health logger
│   └── run-edge.sh                   # watchdog launcher
├── LICENSE
└── README.md
```

## Additional Reading

- [FEX-Emu](https://github.com/FEX-Emu/FEX)
- [FEX Linux user documentation](https://wiki.fex-emu.com/index.php/Welcome)
- [Microsoft Edge for Linux](https://www.microsoft.com/edge/business/download)
- [Playwright documentation](https://playwright.dev/docs/intro)
- [Playwright connectOverCDP](https://playwright.dev/docs/api/class-browsertype#browser-type-connect-over-cdp)
- [Arduino VENTUNO Q](https://docs.arduino.cc/hardware/ventuno-q/)

## License

[MIT](LICENSE)
