# The /proc/self/exe problem

Edge under FEX starts, then the network service and GPU process die in a loop:

```
/proc/self/exe: 1: Syntax error: ")" unexpected
[...] Network service crashed or was terminated, restarting service.
[...] GPU process isn't usable. Goodbye.
```

Chromium launches its child processes by re-executing `/proc/self/exe`. Under FEX that's a symlink to `/usr/bin/FEX`, not to msedge. strace shows the execveat going to the rootfs `/bin/sh` with `/proc/self/exe` as the script:

```
execveat(".../Ubuntu_24_04_edge/bin/sh", ["/bin/sh", "/proc/self/exe", "--type=utility", "--utility-sub-type=network.mojom.NetworkService", ...
```

So dash tries to read the FEX ELF binary as a shell script. That's the syntax error.

FEX does have handling for this. `ExecveHandler` in `Source/Tools/LinuxEmulation/LinuxSyscalls/Syscalls.cpp` redirects a literal `/proc/self/exe` pathname to the guest binary. However, here the path is passed as an argument to `/bin/sh`, not as the pathname, so that redirect never fires. I think something in Edge's launch path falls back to `sh` when the ELF type check returns none, however I haven't confirmed which.

## Workaround

Tell Chromium where the real binary is:

```
FEX /opt/microsoft/msedge/msedge --browser-subprocess-path=/opt/microsoft/msedge/msedge ...
```

## Results (headless, --disable-gpu)

| Test | Result |
|---|---|
| `--dump-dom about:blank` | works, exit 0 |
| `--dump-dom https://example.com` | works, exit 0 |
| `--single-process` | crashpad ptrace failure, core dump |
| no workaround | child processes loop, GPU process isn't usable, abort |

## Not tested yet

Headed mode and GPU. The board reset hard three times earlier in the session, each time while Edge was running, and nothing shows in the journal. Headless runs with `scripts/monitor.sh` going stayed at 38-40 C with 12+ GB free the whole time, so I don't think it's memory or heat. I suspect the display or GPU driver.
