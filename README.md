# IgnisLua

A reactive GTK4 widget and service framework for Wayland desktop shells, written
in Lua 5.5 with a small native C11 engine.

IgnisLua is a port of the Python [Ignis](https://github.com/ignis-sh/ignis)
project. It keeps the same declarative widget model and service layer, drops the
Python runtime, and binds GTK4 directly through GObject Introspection.

- Reference shell: [sysv86/Exo](https://github.com/sysv86/Exo)
- Lua bindings: [sysv86/LuaGObject](https://github.com/sysv86/LuaGObject)

## Highlights

- **Reactive widgets.** Widget properties are `Binding`s: assign a binding to
  any property and the widget updates itself when the source changes.
- **GTK4 first.** Native GTK4/GDK4 introspection layer, `gtk4-layer-shell` for
  layer surfaces, no GTK3 compatibility shims.
- **Native C11 engine.** Library pre-binding, compositor IPC and fast system
  reads happen in `ignis/native.so`, not in Lua.
- **Desktop services.** Audio, backlight, Bluetooth, network, MPRIS, system
  tray, notifications, power profiles, UPower, systemd, wallpaper, screen
  recording, and compositor integrations for Niri and Hyprland.
- **Batteries included.** Dependency-free SCSS compiler, JSON codec, socket and
  file-monitor utilities, Material 3 spring animation, CLI/IPC control.
- **Measured footprint.** Measured on a 12th-gen i5 running Niri with GTK 4.24
  and Lua 5.5:
  - example bar (`examples/bar`), idle: **~86 MiB PSS / ~192 MiB RSS**, 13 threads;
  - full Exo shell (`exo/config.lua`), idle: **~112 MiB PSS / ~225 MiB RSS**,
    15 threads, of which ~47 MiB is private;
  - the same shell with the quick center open: ~119 MiB PSS / ~232 MiB RSS.

  PSS is the process's proportional share of the shared GTK4/Pango/Mesa/font
  stack; RSS counts those libraries in full for the process, so it is the
  pessimistic number. Start-up from `exec` to a parsed configuration is about
  **120 ms** on a warm cache, most of it spent loading the GTK4/GI libraries.
  Numbers come from `/proc/<pid>/smaps_rollup`.

## Architecture

```
src/ignis_launcher.c   -> bin/ignis-bin   native launcher (C11)
src/ignis_native.c     -> ignis/native.so native engine (C11, loaded by Lua)
ignis/                 framework: widgets, services, managers, utils
examples/bar/          minimal bar example configuration
```

### Native engine

`ignis/native.so` is loaded before any GTK symbol is resolved and takes care of
what Lua cannot do safely:

- `dlopen`s `libgtk4-layer-shell.so.0` and the optional GVC library with
  `RTLD_NOW | RTLD_GLOBAL` from a C constructor, so `LD_PRELOAD` and
  `LD_LIBRARY_PATH` tricks are not needed.
- Enforces the load order `Gtk4LayerShell 1.0` → `Gdk 4.0` → `Gtk 4.0`.
- Works with both `girepository-2.0` (GLib 2.80+) and the older
  `girepository-1.0`.
- Provides a non-blocking `AF_UNIX` (`SOCK_STREAM` + `poll`) IPC client used by
  the Niri and Hyprland services, plus `opendir`/`readdir` helpers for fast
  `/sys` reads and package counting.

### Framework layout

| Path | Purpose |
| --- | --- |
| `ignis/init.lua` | package entry point, XDG paths, GI/GTK exports |
| `ignis/base_widget.lua` | widget mixin: bindings, enums, CSS, property routing |
| `ignis/widgets/` | declarative widgets (box, button, entry, stack, switch, …) |
| `ignis/services/` | desktop services (audio, network, tray, MPRIS, …) |
| `ignis/utils/` | json, scss, spring, socket, poll, file, monitor, … |
| `ignis/gi/` | GTK4/GDK4 introspection overrides |
| `ignis/*.lua` | app, window/CSS/options/command managers, IPC, CLI |
| `deps/LuaGObject/` | LuaGObject fork used for the Lua 5.5 build |

## Requirements

- Linux with a Wayland compositor (Niri, Hyprland, Sway, River)
- GTK 4, `gtk4-layer-shell`, GLib 2.80+ recommended
- Lua 5.5 (LuaJIT also works)
- LuaGObject — either a system install or a local build in `deps/install`
  (`scripts/setup_lua.sh` clones and builds
  [sysv86/LuaGObject](https://github.com/sysv86/LuaGObject); the launcher adds
  `deps/install` to `package.path`/`package.cpath` automatically)

Optional, used when present: `matugen`, `swww`, `gpu-screen-recorder`,
`slurp`, `hyprlock`, `dart-sass`/`grass`.

## Build and install

Arch Linux package:

```bash
makepkg -si
```

Make:

```bash
make                 # builds ignis/native.so and bin/ignis-bin
sudo make install    # PREFIX=/usr by default
```

Meson:

```bash
meson setup build --prefix=/usr
ninja -C build
sudo ninja -C build install
```

LuaRocks, Nix and the helper scripts under `scripts/` are available as well
(`setup_arch.sh`, `setup_lua.sh`, `run_exo.sh`, `install_exo.sh`).

## Running

```bash
# native launcher with the bundled example bar
./bin/ignis-bin init -c examples/bar/config.lua

# or through the Lua CLI
lua5.5 bin/ignis init -c examples/bar/config.lua

# systemd user unit (installed by `make install`)
systemctl --user enable --now ignis.service
```

## Controlling a running instance

```bash
ignis toggle-window Launcher
ignis open-window Settings
ignis close-window OSD
ignis list-windows
ignis run-command set-wallpaper /path/to/wallpaper.png
ignis list-commands
ignis run-lua 'print(require("ignis").VERSION)'
ignis run-file ./debug.lua
ignis reload
ignis quit
ignis system-info
```

Bind these to compositor shortcuts; each call is a single IPC round trip.

## Configuration

A configuration is a Lua file that returns a table of windows and widgets and
registers commands. See `examples/bar/config.lua` for a small one and
[sysv86/Exo](https://github.com/sysv86/Exo) for a complete shell (bar, launcher,
quick center, notifications, OSD, power menu, settings).

```lua
local ignis = require("ignis")
local widgets = ignis.widgets

return {
    windows = {
        {
            name = "example-bar",
            widget = widgets.CenterBox({
                start_widget = widgets.Label({ label = "IgnisLua" }),
                end_widget = widgets.Button({
                    label = "Quit",
                    on_click = function() ignis.App.get_default():quit() end,
                }),
            }),
        },
    },
}
```

## Testing

```bash
make test      # builds the native engine, then runs lua test.lua
```

## Contributing

Bug reports, feature requests and pull requests use the templates in
`.github/`. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a PR.

## License

LGPL-2.1-or-later. The bundled LuaGObject fork is MIT licensed.
