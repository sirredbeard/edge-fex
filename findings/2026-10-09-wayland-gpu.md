# Wayland and GPU acceleration work

Tested on the VENTUNO Q under the GDM `Ubuntu on Wayland` session.

The working launch path is:

```text
FEX /opt/microsoft/msedge/msedge \
  --browser-subprocess-path=/opt/microsoft/msedge/msedge \
  --no-sandbox \
  --test-type \
  --ozone-platform=wayland
```

`--browser-subprocess-path` remains necessary for Chromium child processes.
`--no-sandbox` also remains necessary: without it, the zygote exits before Edge
finishes starting. `--test-type` hides Chromium's persistent `--no-sandbox`
warning banner.

## Graphics result

Do not use `--disable-gpu`. Chromium's `SystemInfo.getInfo` reports:

- ANGLE over EGL/OpenGL
- Mesa freedreno, Adreno 623
- GPU compositing enabled
- GPU rasterization and multiple raster threads enabled
- Canvas, WebGL, and WebGPU enabled

The FEX package supplies host and guest EGL, GL, DRM, Vulkan, and Wayland
thunks. Hardware video decode still emits one VAAPI initialization error and
reports no decode profiles, but the rest of GPU acceleration is operational.

The board has a 7.5 GB `/dev/shm` tmpfs. Removing
`--disable-dev-shm-usage` lets Chromium use shared memory normally instead of
forcing it through `/tmp`.

## Observed behavior

Edge rendered Bing and its image-heavy home page correctly. Normal browsing,
maximize/unmaximize, snapping, and resizing did not create a new crash report.
GNOME still logged nonfatal Wayland assertions such as
`surface_state_changed: assertion 'wl_window->has_last_sent_configuration'
failed`, so the compositor interaction is not completely clean.

The browser remains somewhat CPU-heavy under translation. On Bing, the
accelerated instance used roughly 1.8 CPU cores during a 15-second sample,
mostly in one renderer. Memory remained below 2 GB, memory PSI stayed at zero,
and the hottest thermal zone stayed around 40-41 C.
