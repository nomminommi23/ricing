# ricing

My personal dotfiles for a [Hyprland](https://hyprland.org/) desktop on Arch Linux. This repo tracks only the rice-relevant configs out of `~/.config` (see [`.gitignore`](.gitignore)) — everything else in the home config directory is left untouched.

**Heads up:** the majority of this configuration — especially the entire Quickshell bar — was built with [Claude Code](https://claude.com/claude-code). I described what I wanted, reviewed the results, and iterated from there rather than hand-writing most of the QML/config myself. If you're browsing this repo for ideas, keep that in mind: it's an AI-assisted rice, not a from-scratch hand-tuned one.

## Stack

| Piece | Tool |
|---|---|
| Compositor | [Hyprland](https://hyprland.org/) |
| Bar | Custom [Quickshell](https://quickshell.org/) shell (`quickshell/default/`) — replaces Waybar entirely |
| Launcher | Rofi |
| Terminal | Kitty |
| Theming | [aether](aether/) — palette-driven theme generator |
| Qt/GTK theming | qt5ct, qt6ct, nwg-look |
| File manager | Dolphin (`kdeglobals`, `dolphinrc`) |

## The bar

Waybar has been fully retired. The whole top bar is one Quickshell shell (`quickshell/default/Bar.qml`), instantiated per monitor, laid out with real QML layouts instead of a mix of two independent renderers guessing at each other's positions. It includes:

- **Logo + workspaces** — per-monitor workspace pills (Hyprland IPC), click to switch
- **Window switcher** — a button between the workspaces and the window title that drops down a list of every open window across all workspaces; click one to focus it. Also bound to `Mod+Shift+A`
- **Active window title** — per-monitor, shows the title of whichever window is focused on that specific screen
- **System tray** — StatusNotifierItem icons with left-click activate / right-click context menu
- **CPU / RAM / disk / GPU** — live stats pills with hover tooltips (per-core CPU breakdown, load average, memory/disk usage, GPU temperature + VRAM); click the CPU pill to toggle it between usage % and temperature
- **Volume** — click opens the mixer, right-click mutes, scroll adjusts volume (via `wpctl`)
- **Network** — shows the active connection (Wi-Fi SSID or wired); hover shows the local IP, click toggles to the public IP
- **Clock** — hover for the full date + ISO week number, click opens a small month calendar
- **Power menu** — restart / shutdown / logout dropdown

All the stats are pulled by small shell scripts in `quickshell/default/scripts/` rather than baked into the QML.

## Theming (aether)

The color palette lives in [`aether/`](aether/) and is the single source of truth — [`aether/theme/colors.toml`](aether/theme/colors.toml) defines the palette, and aether renders it out into per-app configs (Hyprland, Kitty, Rofi, Waybar-era CSS, btop, Zed, etc.), most of which get `@import`ed or sourced by that app's real config rather than edited directly. The bar's own colors in `Bar.qml` are hand-matched to this palette rather than generated, since Quickshell reads QML, not CSS.

## Requirements

Beyond Hyprland itself, the bar's scripts expect: `quickshell`, `nmcli`, `wpctl`, `nvidia-smi` (GPU stats — no-ops gracefully if absent), `sensors` (lm_sensors, for CPU temperature), `python3`, and `curl` (for the network widget's public-IP lookup).

## Layout

```
hypr/        Hyprland config
quickshell/  The bar (Bar.qml + helper QML components + scripts/)
rofi/        Launcher config + theme
kitty/       Terminal config + theme
aether/      Palette source + generated per-app theme files
btop/        System monitor config
qt5ct/ qt6ct/ nwg-look/ gtk-3.0/   Qt/GTK theming
```
