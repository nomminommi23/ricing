# ricing

My personal dotfiles for a [Hyprland](https://hyprland.org/) desktop on Arch Linux. This repo tracks only the rice-relevant configs out of `~/.config` (see [`.gitignore`](.gitignore)) — everything else in the home config directory is left untouched.

**Heads up:** the majority of this configuration — especially the entire Quickshell bar — was built with [Claude Code](https://claude.com/claude-code). I described what I wanted, reviewed the results, and iterated from there rather than hand-writing most of the QML/config myself. If you're browsing this repo for ideas, keep that in mind: it's an AI-assisted rice, not a from-scratch hand-tuned one.

## Installing

```bash
curl -o /tmp/install.sh https://raw.githubusercontent.com/nomminommi23/ricing/main/install.sh
bash /tmp/install.sh          # clones the repo and drops its files into ~/.config
bash /tmp/install.sh --deps   # same, plus installs dependencies via pacman (Arch only)
```

[`install.sh`](install.sh) never runs a plain `git clone` straight into `~/.config` — that directory already has other apps' configs in it (and `git clone` refuses a non-empty target anyway). Instead it clones into a temp dir first, then moves only the paths this repo actually tracks into `~/.config` one by one; anything already there under the same name gets backed up to `~/.config-backup-<timestamp>/` rather than silently overwritten, and everything else in `~/.config` is left untouched. Re-running it later (e.g. on a machine that already has the rice) detects the existing checkout and just does a `git pull` instead. Pass `--dry-run` to see what it would do without changing anything, or `--repo=<url>` to install from a fork.

`--deps` only knows `pacman` — see [Requirements](#requirements) below for `apt`/`dnf` package lists to install by hand on other distros. Either way, log out and back into Hyprland/SDDM (or reboot) afterward.

## Stack

| Piece | Tool |
|---|---|
| Compositor | [Hyprland](https://hyprland.org/) |
| Login screen | SDDM — stock theme, not customized/tracked here (config lives under `/etc`, outside this repo's scope) |
| Bar | Custom [Quickshell](https://quickshell.org/) shell (`quickshell/default/`) — replaces Waybar entirely |
| Launcher | Rofi |
| Terminal | Kitty |
| Cursor | Custom Arch-logo cursor set (pointer, text, resize, wait spinner, …) in the rice palette — artwork in [`shapes.py`](hypr/cursor/shapes.py), [`build.py`](hypr/cursor/build.py) installs a Hyprcursor and an XCursor theme to `~/.local/share/icons/ArchLogo` |
| Notifications | [mako](mako/) — themed from the palette, same as the rest |
| Theming | [`theme/`](theme/) — homegrown palette-driven theme generator (`render.py`), controlled from the Quickshell desktop widget or the CLI |
| Qt/GTK theming | qt5ct, qt6ct, nwg-look |
| File manager | Dolphin (`kdeglobals`, `dolphinrc`) |

## The bar

Waybar has been fully retired. The whole top bar is one Quickshell shell (`quickshell/default/Bar.qml`), instantiated per monitor, laid out with real QML layouts instead of a mix of two independent renderers guessing at each other's positions. It includes:

- **Logo + workspaces** — per-monitor workspace pills (Hyprland IPC), click to switch. Click the logo itself to toggle taskbar mode (below)
- **Taskbar mode** — clicking the logo swaps the workspace pills, window title, and stat pills for a compact Windows-style taskbar of every open window, shown as icon buttons (resolved via `DesktopEntries.heuristicLookup()`, the same mechanism app launchers use, falling back to the title's first letter if no icon is found). Hover a button for the full title, click to focus. Clock and power button stay visible in both modes
- **Window switcher** — `Mod+Shift+A` drops down a list of every open window across all workspaces; click one to focus it
- **Active window title** — per-monitor, shows the title of whichever window is focused on that specific screen
- **System tray** — StatusNotifierItem icons with left-click activate / right-click context menu
- **CPU / RAM / disk / GPU** — live stats pills, each with a titled hover tooltip; click the CPU or GPU pill to toggle it between usage % and temperature (the icon stays put, only the color/value change). The disk pill defaults to `/`; click it to cycle through every real mounted filesystem (a USB stick, `/boot`, …), hovering always lists all of them with their device name (e.g. `nvme0n1p2`), used/free space and live read/write speed
- **Volume** — click opens the mixer, right-click mutes, scroll adjusts volume (via `wpctl`)
- **Network** — shows the active connection (Wi-Fi SSID or wired); hover shows the local IP (click toggles to the public IP), the network device (e.g. `enp7s0`) and the live up/download rate in decimal bit units (Kbit/Mbit/Gbit/s, like a speedtest), refreshed every second independently of the slower connection/SSID lookup
- **Clock** — hover for the full date + ISO week number, click opens a small month calendar
- **Notification panel** — the bell button (with an unread badge) opens a panel down the right screen edge, top to bottom, listing recent notifications from mako's history. Click a notification (or “Mark all read”) to mark it read and drop it from the list. mako can't delete single history entries, so read state is kept by `scripts/notifs.py` in `~/.local/state/quickshell/notifs-read`
- **Keybinds help** — in taskbar mode, a `?` button next to the clock (hover: hints what it does; click: opens a centered cheatsheet of every keybind, grouped by category). Also reachable from either mode via `Mod+Shift+H`. The list is hand-kept in sync with the Hotkeys section below — Hyprland's Lua config binds everything through one opaque `__lua` dispatcher, so `hyprctl binds` can't recover a human-readable action to auto-generate it from
- **Power menu** — restart / shutdown / logout dropdown

All the stats are pulled by small shell scripts in `quickshell/default/scripts/` rather than baked into the QML.

Hyprland itself is configured via [`hypr/hyprland.lua`](hypr/hyprland.lua) (Hyprland's Lua config API) — that's the active config; `hyprland.conf` is kept around for reference but is no longer loaded. One consequence: `hyprctl dispatch` (and anything sending it a raw dispatch string, like this bar's workspace/window-switcher clicks) needs the new `hl.dsp.*` Lua-expression syntax instead of the classic one, e.g. `hl.dsp.focus({workspace = 1})` rather than `workspace 1`.

There's also a `no_fullscreen_kitty` window rule in there working around a real Hyprland quirk: newly opened kitty windows were coming up in genuine fullscreen (`hasfullscreen: true`, not just a full-size tile) regardless of workspace, needing `fullscreen()` dispatched twice to clear. Root cause not found (no rule/config was causing it); `fullscreen_state = "0 0"` on kitty forces both the internal and client-requested state off on open. Plain `fullscreen = false` is a no-op — that's just the default, it doesn't override anything.

## Cursor

The mouse cursor is a custom theme, `ArchLogo`, with every shape redrawn in the rice style instead of only the arrow:

- **Default pointer** — the Arch logo, rotated like a classic arrow, plain accent blue without an outline. Copy / context-menu / alias / help / no-drop are the same arrow with a small badge, and the link pointer is the logo upright
- **Everything else** — text I-beam, resize arrows (edges, corners, column/row, all-direction), crosshair, cell, grab/grabbing hand, zoom, X, and a red not-allowed sign. These have a dark outline plus a light rim so they stay visible on blue or dark backgrounds
- **Animated** — `wait` is a spinning ring, `progress` is the arrow with a small spinner badge

The artwork is drawn procedurally in [`hypr/cursor/shapes.py`](hypr/cursor/shapes.py); [`hypr/cursor/build.py`](hypr/cursor/build.py) renders it (needs `rsvg-convert` and `hyprcursor-util`) into a Hyprcursor theme for Hyprland and an XCursor theme for GTK/Qt/XWayland apps, both installed to `~/.local/share/icons/ArchLogo`. Adwaita is only used as the shape/alias list and fallback. It also writes `~/.local/share/icons/default/index.theme` (`Inherits=ArchLogo`), Xcursor's fallback theme, so apps that never see `XCURSOR_THEME` (Steam and Proton games started before the env was set) get the cursor too — restart Steam once after installing. After editing `shapes.py`, run `python3 hypr/cursor/build.py` and `hyprctl setcursor ArchLogo 24`. `hyprland.lua` sets the theme via `XCURSOR_THEME` / `HYPRCURSOR_THEME` and gsettings.

## Theming

Theming used to go through a third-party app called aether; it's gone now (it didn't work reliably), replaced with a small homegrown system in [`theme/`](theme/):

- [`theme/colors.toml`](theme/colors.toml) is the single source of truth for the palette (accent, cursor, foreground/background, 16 ANSI colors)
- [`theme/templates/<app>/`](theme/templates/) holds one `{config.json, template}` pair per themed app (Hyprland, Kitty, Rofi, mako). `config.json` names the destination file; the template uses `{key}` placeholders (`{color4}`, `{background}`, `{accent}`, …), `{key.strip}` for the hex without `#`, or `{key.rgba:ALPHA}` for a `rgba(r, g, b, ALPHA)` string
- [`theme/render.py`](theme/render.py) renders every template to its destination and reloads the affected apps (`hyprctl reload`, `makoctl reload`, kitty via `SIGUSR1`). Run it after editing a template by hand, or use `--set KEY '#rrggbb'` to change one color from a terminal, `--get KEY` / `--dump` to read the palette back out
- [`theme/wallpaper.py`](theme/wallpaper.py) swaps the wallpaper: `apply <path>` archives the current one (deduped by hash) into `~/.local/share/quickshell/wallpapers/` and copies the new one to [`hypr/wallpaper.png`](hypr/wallpaper.png) (loaded via `swaybg` in `hyprland.lua`), `pick` does the same via a native file picker, `list` feeds the widget's gallery of past wallpapers

mako's per-urgency border colors (normal = accent, low = muted, critical = red) work the same way as Hyprland's border colors: edit the template at `theme/templates/mako/colors.ini`, not `mako/colors.ini` itself — that gets overwritten on the next render.

Day to day, neither script needs to be run by hand — the **theme widget**, a small standalone Quickshell window pinned to the top-left corner of the main monitor (independent of the bar), has two buttons: a picture icon opens the wallpaper gallery/picker, a paintbrush icon opens a menu to pick which color role to change and then a palette (plus a hex field) to change it to. Both call straight into the scripts above.

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
| `Mod + Shift + H` | Toggle the keybinds panel (also reachable via the taskbar-mode help button) |

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

Beyond Hyprland itself, the bar's scripts expect: `quickshell`, `nmcli`, `wpctl`, `nvidia-smi` (GPU stats — no-ops gracefully if absent), `sensors` (lm_sensors, for CPU temperature), `python3`, and `curl` (for the network widget's public-IP lookup). The theme widget's wallpaper picker additionally needs `zenity` (native file picker) and `swaybg`.

This is an Arch + Hyprland rice through and through, so the list below is Arch-authoritative — everything in the pacman column is a plain `extra`/`multilib` package on current Arch, nothing needs an AUR helper. `apt`/`dnf` columns are best-effort: Hyprland and its ecosystem (Hyprland itself, `quickshell`, `hyprcursor`) move fast and generally aren't in Debian/Ubuntu's or Fedora's stock repos, so those need a third-party repo (Fedora: the [`solopasha/hyprland` COPR](https://copr.fedorainfracloud.org/coprs/solopasha/hyprland/) covers most of it) or building from source — a blank cell means "no known repo package, check the project's own install docs". Snap has essentially no coverage here (this is all system/Wayland-level tooling, not the kind of app snap packages); where an optional app happens to have one, it's noted below the table instead.

| Program | What it's for | pacman | apt | dnf |
|---|---|---|---|---|
| `hyprland` | Compositor | `hyprland` | — (COPR/build) | `hyprland` (COPR) |
| `sddm` | Login screen | `sddm` | `sddm` | `sddm` |
| `xdg-desktop-portal-hyprland` | Screen share / portals | `xdg-desktop-portal-hyprland` | — | `xdg-desktop-portal-hyprland` (COPR) |
| `quickshell` | The bar + widgets | `quickshell` | — (build) | — (build) |
| `kitty` | Terminal | `kitty` | `kitty` | `kitty` |
| `rofi` | Launcher | `rofi` | `rofi` | `rofi` |
| `mako` | Notifications | `mako` | `mako-notifier` | `mako` |
| `dolphin` | File manager | `dolphin` | `dolphin` | `dolphin` |
| `swaybg` | Wallpaper | `swaybg` | `swaybg` | `swaybg` |
| `hyprcursor` (`hyprcursor-util`) | Cursor theme build | `hyprcursor` | — | `hyprcursor` (COPR) |
| `librsvg` (`rsvg-convert`) | Cursor theme build | `librsvg` | `librsvg2-bin` | `librsvg2-tools` |
| `grim` + `slurp` | Screenshots | `grim slurp` | `grim slurp` | `grim slurp` |
| `wl-clipboard` | Clipboard (copy/paste) | `wl-clipboard` | `wl-clipboard` | `wl-clipboard` |
| `cliphist` | Clipboard history | `cliphist` | — | — (build) |
| `zenity` | Native file picker (theme widget) | `zenity` | `zenity` | `zenity` |
| NetworkManager (`nmcli`) | Network widget/pill | `networkmanager` | `network-manager` | `NetworkManager` |
| `network-manager-applet` (`nm-applet`, `nm-connection-editor`) | Network tray/settings | `network-manager-applet` | `network-manager-gnome` | `network-manager-applet` |
| WirePlumber (`wpctl`) | Volume pill | `wireplumber` | `wireplumber` | `wireplumber` |
| `pavucontrol` | Volume mixer (opened by the volume pill) | `pavucontrol` | `pavucontrol` | `pavucontrol` |
| `blueman` (`blueman-manager`) | Bluetooth manager (window rule) | `blueman` | `blueman` | `blueman` |
| `brightnessctl` | Brightness keys | `brightnessctl` | `brightnessctl` | `brightnessctl` |
| `playerctl` | Media keys | `playerctl` | `playerctl` | `playerctl` |
| `lm_sensors` (`sensors`) | CPU temperature | `lm_sensors` | `lm-sensors` | `lm_sensors` |
| `nvidia-utils` (`nvidia-smi`) | GPU stats — optional, no-ops gracefully if absent | `nvidia-utils` | `nvidia-utils-*` | `xorg-x11-drv-nvidia-cuda` |
| `curl` | Network widget's public-IP lookup | `curl` | `curl` | `curl` |
| `python3` | Bar scripts, cursor build, theme system | `python` | `python3` | `python3` |
| `qt5ct` / `qt6ct` / `nwg-look` | Qt/GTK theming | `qt5ct qt6ct nwg-look` | `qt5ct qt6ct` (nwg-look: build) | `qt5ct qt6ct` (nwg-look: build) |
| `materia-gtk-theme` | GTK theme | `materia-gtk-theme` | `materia-gtk-theme` | — (build) |
| `papirus-icon-theme` | Icon theme | `papirus-icon-theme` | `papirus-icon-theme` | `papirus-icon-theme` |
| `ttf-jetbrains-mono-nerd` | Bar/UI font | `ttf-jetbrains-mono-nerd` | — (manual install from [Nerd Fonts](https://www.nerdfonts.com/)) | — (manual install) |

```bash
# Arch (pacman - every package below is in the extra/multilib repos already
# enabled by default, no AUR helper needed)
sudo pacman -S --needed hyprland sddm xdg-desktop-portal-hyprland quickshell kitty rofi \
    mako dolphin swaybg hyprcursor librsvg grim slurp wl-clipboard cliphist zenity \
    networkmanager network-manager-applet wireplumber pavucontrol blueman brightnessctl \
    playerctl lm_sensors nvidia-utils curl python qt5ct qt6ct nwg-look materia-gtk-theme \
    papirus-icon-theme ttf-jetbrains-mono-nerd

# Debian/Ubuntu (apt) - covers everything except Hyprland/quickshell/hyprcursor/
# cliphist, which need a third-party repo or a source build on this base
sudo apt install kitty rofi mako-notifier dolphin swaybg librsvg2-bin grim slurp \
    wl-clipboard zenity network-manager network-manager-gnome wireplumber pavucontrol \
    blueman brightnessctl playerctl lm-sensors nvidia-utils-535 curl python3 \
    qt5ct qt6ct materia-gtk-theme papirus-icon-theme sddm

# Fedora (dnf) - add the solopasha/hyprland COPR first for Hyprland/hyprcursor/
# xdg-desktop-portal-hyprland; quickshell/cliphist/nwg-look/materia-gtk-theme still need a build
sudo dnf copr enable solopasha/hyprland
sudo dnf install hyprland xdg-desktop-portal-hyprland hyprcursor kitty rofi mako dolphin \
    swaybg librsvg2-tools grim slurp wl-clipboard zenity NetworkManager \
    network-manager-applet wireplumber pavucontrol blueman brightnessctl playerctl \
    lm_sensors xorg-x11-drv-nvidia-cuda curl python3 qt5ct qt6ct papirus-icon-theme sddm
```

**Anything not covered by a system package manager** (`quickshell`/`hyprcursor`/`cliphist` off-Arch, `nwg-look`/`materia-gtk-theme` off-Arch on Fedora): build from source per the project's own README, or check if the distro has an unofficial binary repo for it (Fedora COPR, a Debian PPA-equivalent, `chaotic-aur`-style prebuilt repos). Flatpak/Nix are worth a look for the optional apps below, but the bar/theming stack itself is system-level Wayland tooling that neither packages well.

Optional apps this config's hotkeys point at — swap the `hl.bind` targets in `hyprland.lua` for whatever you actually use instead of installing these: `zen-browser` (`Mod+W`, AUR `zen-browser-bin` on Arch; also on Flatpak as `io.github.zen_browser.zen`), `discord` (`Mod+Shift+C`, in most repos, incl. Arch `extra`; also Flatpak `com.discordapp.Discord`), `spotify` (`Mod+Shift+P`, AUR on Arch; also Flatpak `com.spotify.Client` or a Snap), `steam` (`Mod+Shift+S`, `multilib/steam` on Arch, `steam` on apt/dnf with the right repo enabled), `btop` (`Mod+Shift+T`, in most repos), `qalculate-gtk` (`Mod+Alt+C`, in most repos).

## Layout

```
hypr/        Hyprland config (hyprland.lua is active, .conf kept for reference) + wallpaper.png + cursor/ (cursor theme source)
quickshell/  The bar (Bar.qml + helper QML components + scripts/) + ThemeWidget.qml (theming widget)
rofi/        Launcher config + theme
kitty/       Terminal config + theme
mako/        Notification daemon config (colors.ini generated by theme/render.py)
theme/       Palette source (colors.toml), per-app templates, render.py + wallpaper.py
btop/        System monitor config
qt5ct/ qt6ct/ nwg-look/ gtk-3.0/   Qt/GTK theming
```
