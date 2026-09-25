# ricing

My personal dotfiles for a [Hyprland](https://hyprland.org/) desktop on Arch Linux. This repo tracks only the rice-relevant configs out of `~/.config` (see [`.gitignore`](.gitignore)) — everything else in the home config directory is left untouched.

**Heads up:** the majority of this configuration — especially the entire Quickshell bar — was built with [Claude Code](https://claude.com/claude-code). I described what I wanted, reviewed the results, and iterated from there rather than hand-writing most of the QML/config myself. If you're browsing this repo for ideas, keep that in mind: it's an AI-assisted rice, not a from-scratch hand-tuned one.

## Stack

| Piece | Tool |
|---|---|
| Compositor | [Hyprland](https://hyprland.org/) |
| Login screen | SDDM — stock theme, not customized/tracked here (config lives under `/etc`, outside this repo's scope) |
| Bar | Custom [Quickshell](https://quickshell.org/) shell (`quickshell/default/`) — replaces Waybar entirely |
| Launcher | Rofi |
| Terminal | Kitty |
| Cursor | Custom Arch-logo cursor set (pointer, text, resize, wait spinner, …) in the rice palette — artwork in [`shapes.py`](hypr/cursor/shapes.py), [`build.py`](hypr/cursor/build.py) installs a Hyprcursor and an XCursor theme to `~/.local/share/icons/ArchLogo` |
| Notifications | [mako](mako/) — themed via aether, same as the rest |
| Theming | [aether](aether/) — palette-driven theme generator |
| Qt/GTK theming | qt5ct, qt6ct, nwg-look |
| File manager | Dolphin (`kdeglobals`, `dolphinrc`) |

## The bar

Waybar has been fully retired. The whole top bar is one Quickshell shell (`quickshell/default/Bar.qml`), instantiated per monitor, laid out with real QML layouts instead of a mix of two independent renderers guessing at each other's positions. It includes:

- **Logo + workspaces** — per-monitor workspace pills (Hyprland IPC), click to switch. Click the logo itself to toggle taskbar mode (below)
- **Taskbar mode** — clicking the logo swaps the workspace pills, window title, and stat pills for a compact Windows-style taskbar of every open window, shown as icon buttons (resolved via `DesktopEntries.heuristicLookup()`, the same mechanism app launchers use, falling back to the title's first letter if no icon is found). Hover a button for the full title, click to focus. Clock and power button stay visible in both modes
- **Window switcher** — `Mod+Shift+A` drops down a list of every open window across all workspaces; click one to focus it
- **Active window title** — per-monitor, shows the title of whichever window is focused on that specific screen
- **System tray** — StatusNotifierItem icons with left-click activate / right-click context menu
- **CPU / RAM / disk / GPU** — live stats pills with hover tooltips (per-core CPU breakdown, load average, memory/disk usage, GPU temperature + VRAM); click the CPU pill to toggle it between usage % and temperature
- **Volume** — click opens the mixer, right-click mutes, scroll adjusts volume (via `wpctl`)
- **Network** — shows the active connection (Wi-Fi SSID or wired); hover shows the local IP, click toggles to the public IP
- **Clock** — hover for the full date + ISO week number, click opens a small month calendar
- **Notification panel** — the bell button (with an unread badge) opens a panel down the right screen edge, top to bottom, listing recent notifications from mako's history. Click a notification (or “Mark all read”) to mark it read and drop it from the list. mako can't delete single history entries, so read state is kept by `scripts/notifs.py` in `~/.local/state/quickshell/notifs-read`
- **Power menu** — restart / shutdown / logout dropdown

All the stats are pulled by small shell scripts in `quickshell/default/scripts/` rather than baked into the QML.

Hyprland itself is configured via [`hypr/hyprland.lua`](hypr/hyprland.lua) (Hyprland's Lua config API) — that's the active config; `hyprland.conf` is kept around for reference but is no longer loaded. One consequence: `hyprctl dispatch` (and anything sending it a raw dispatch string, like this bar's workspace/window-switcher clicks) needs the new `hl.dsp.*` Lua-expression syntax instead of the classic one, e.g. `hl.dsp.focus({workspace = 1})` rather than `workspace 1`.

## Cursor

The mouse cursor is a custom theme, `ArchLogo`, with every shape redrawn in the rice style instead of only the arrow:

- **Default pointer** — the Arch logo, rotated like a classic arrow, plain accent blue without an outline. Copy / context-menu / alias / help / no-drop are the same arrow with a small badge, and the link pointer is the logo upright
- **Everything else** — text I-beam, resize arrows (edges, corners, column/row, all-direction), crosshair, cell, grab/grabbing hand, zoom, X, and a red not-allowed sign. These have a dark outline plus a light rim so they stay visible on blue or dark backgrounds
- **Animated** — `wait` is a spinning ring, `progress` is the arrow with a small spinner badge

The artwork is drawn procedurally in [`hypr/cursor/shapes.py`](hypr/cursor/shapes.py); [`hypr/cursor/build.py`](hypr/cursor/build.py) renders it (needs `rsvg-convert` and `hyprcursor-util`) into a Hyprcursor theme for Hyprland and an XCursor theme for GTK/Qt/XWayland apps, both installed to `~/.local/share/icons/ArchLogo`. Adwaita is only used as the shape/alias list and fallback. It also writes `~/.local/share/icons/default/index.theme` (`Inherits=ArchLogo`), Xcursor's fallback theme, so apps that never see `XCURSOR_THEME` (Steam and Proton games started before the env was set) get the cursor too — restart Steam once after installing. After editing `shapes.py`, run `python3 hypr/cursor/build.py` and `hyprctl setcursor ArchLogo 24`. `hyprland.lua` sets the theme via `XCURSOR_THEME` / `HYPRCURSOR_THEME` and gsettings.

## Theming (aether)

The color palette lives in [`aether/`](aether/) and is the single source of truth — [`aether/theme/colors.toml`](aether/theme/colors.toml) defines the palette, and aether renders it out into per-app configs (Hyprland, Kitty, Rofi, Waybar-era CSS, btop, Zed, etc.), most of which get `@import`ed or sourced by that app's real config rather than edited directly. The bar's own colors in `Bar.qml` are hand-matched to this palette rather than generated, since Quickshell reads QML, not CSS.

mako's per-urgency border colors (normal = accent, low = muted, critical = red) work the same way as Hyprland's border colors: a template at [`aether/custom/mako/colors.ini`](aether/custom/mako/colors.ini) gets rendered by aether into `mako/colors.ini`, which the real `mako/config` pulls in via `include=`. Edit the template, not the generated file — it gets overwritten on the next theme switch.

It's a blue theme (`#1793d1` accent on a dark `#1a1b26` background) built around the stock default Hyprland wallpaper — the anime girl waiting at the train stop with the glowing blue Hyprland-logo cats. Every accent color across the bar, Rofi, Kitty, and the rest was picked to match that wallpaper's palette rather than the other way around. The wallpaper itself is tracked at [`hypr/wallpaper.png`](hypr/wallpaper.png) and set via `swaybg` in `hyprland.lua`.

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
hypr/        Hyprland config (hyprland.lua is active, .conf kept for reference) + wallpaper.png + cursor/ (cursor theme source)
quickshell/  The bar (Bar.qml + helper QML components + scripts/)
rofi/        Launcher config + theme
kitty/       Terminal config + theme
mako/        Notification daemon config (colors.ini generated by aether)
aether/      Palette source + generated per-app theme files
btop/        System monitor config
qt5ct/ qt6ct/ nwg-look/ gtk-3.0/   Qt/GTK theming
```
