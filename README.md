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

It's a blue theme (`#1793d1` accent on a dark `#1a1b26` background) built around the stock default Hyprland wallpaper — the anime girl waiting at the train stop with the glowing blue Hyprland-logo cats. Every accent color across the bar, Rofi, Kitty, and the rest was picked to match that wallpaper's palette rather than the other way around.

## Hotkeys

`Mod` = <kbd>Super</kbd>.

### Apps

| Key | Action |
|---|---|
| `Mod + Return` | Terminal (Kitty) |
| `Mod + W` | Browser (Zen) |
| `Mod + N` | File manager (Dolphin) |
| `Mod + Space` | App launcher (Rofi) |
| `Mod + Shift + P` | Spotify |
| `Mod + Shift + C` | Discord |
| `Mod + Shift + S` | Steam |
| `Mod + Shift + T` | btop (in terminal) |
| `Mod + Alt + C` | Qalculate |
| `Mod + C` | Clipboard history (cliphist + Rofi) |

### Bar

| Key | Action |
|---|---|
| `Mod + Shift + A` | Toggle the window switcher dropdown |

### Windows

| Key | Action |
|---|---|
| `Mod + Q` | Close active window |
| `Mod + Shift + E` | Exit Hyprland |
| `Mod + F` | Toggle fullscreen |
| `Mod + V` | Toggle floating |
| `Mod + P` | Toggle pseudotiling |
| `Mod + ← / → / K / J` | Move focus (left/right/up/down) |
| `Mod + Shift + ← / → / ↑ / ↓` | Move window |
| `Mod + Ctrl + H / L / K / J` | Resize active window |
| `Mod + LMB` drag | Move window |
| `Mod + RMB` drag | Resize window |

### Workspaces

| Key | Action |
|---|---|
| `Mod + 1` … `Mod + 9` | Switch to workspace 1–9 |
| `Mod + Shift + 1` … `Mod + Shift + 9` | Move window to workspace 1–9 |
| `Mod + Scroll` | Next/previous workspace |

### Screenshots

| Key | Action |
|---|---|
| `Print` | Region screenshot → clipboard |
| `Shift + Print` | Region screenshot → `~/Pictures/Screenshots/` |

### Media / audio / brightness

| Key | Action |
|---|---|
| `XF86AudioRaiseVolume` / `LowerVolume` | Volume up/down |
| `XF86AudioMute` | Mute |
| `XF86AudioMicMute` | Mute mic |
| `XF86MonBrightnessUp` / `Down` | Brightness up/down |
| `XF86AudioPlay` / `Next` / `Prev` | Media playback control |

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
