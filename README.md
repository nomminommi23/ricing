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
| Qt/GTK theming | qt6ct, nwg-look |
| File manager | Thunar (GTK3; themed via the same pipeline — see Theming below). Was Dolphin, dropped over an [unfixed upstream bug](https://discuss.kde.org/t/dolphin-how-can-i-override-the-new-highlight-color/38640) forcing Breeze's stock blue for selection outside a full Plasma session |

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

- [`theme/colors.toml`](theme/colors.toml) is the single source of truth for the palette: accent, cursor, foreground/background, 16 ANSI colors, four extra `*_color` fields (`bar_color`, `pill_color`, `popup_color`, `gtk_selection_color` — the terminal reuses `background`, already shared with mako), and five matching `*_opacity` floats (`bar_opacity`, `pill_opacity`, `popup_opacity`, `terminal_opacity`, `gtk_selection_opacity`, each 0-1)
- [`theme/templates/<app>/`](theme/templates/) holds one `{config.json, template}` pair per themed app (Hyprland, Kitty, Rofi, mako, `gtk3`, `kde`, `kde-colorscheme`, `qt6ct`). `config.json` names the destination file; the template uses `{key}` placeholders (`{color4}`, `{background}`, `{accent}`, …), `{key.strip}` for the hex without `#`, `{key.rgb}` for `r,g,b` decimal with no alpha (what `kdeglobals` uses), or `{key.rgba:ALPHA}` for a `rgba(r, g, b, ALPHA)` string. Adding a new themed app is just adding one more folder here — no code changes
- **`qt6ct` vs. `kdeglobals` vs. `kde-colorscheme`** — three templates that sound redundant but each theme a different layer, found the hard way while chasing why Dolphin's colors wouldn't take:
  - `qt6ct` (`theme/templates/qt6ct/` → `~/.config/qt6ct/colors/aether-rice.conf`, a serialized `QPalette` — see the comment at the top of that template for the role-by-role mapping) is what a plain Qt6 app's own background/text/highlight colors actually come from, since `hyprland.lua` sets `QT_QPA_PLATFORMTHEME=qt6ct`
  - `kde` (`~/.config/kdeglobals`) matters for KDE/Plasma-integration bits, and for apps that read their own palette straight from it
  - `kde-colorscheme` (`~/.local/share/color-schemes/AetherRice.colors`) is the scheme `kdeglobals`'s `ColorScheme=AetherRice` line names — without an actual file there, KColorSchemeManager silently falls back to a stock scheme, and if the app's style happens to be Breeze (it loads alongside whatever `qt6ct.conf` says the style is; you can't assume it's off), some of *its* colors (e.g. item-view selection) come from here instead of `qt6ct`
  - Even with all three right, a real, currently-unresolved Dolphin regression ([KDE Discuss thread](https://discuss.kde.org/t/dolphin-how-can-i-override-the-new-highlight-color/38640)) hardcodes its selection color outside a full Plasma session no matter what — confirmed with `strace`, a known-good bundled qt6ct scheme, `QT_STYLE_OVERRIDE=Fusion`, and a `kbuildsycoca6` rebuild, none of which changed it. That's the actual reason Thunar replaced Dolphin here, not just a styling preference
- **GTK3 (Thunar) has its own set of gotchas**, also found the hard way:
  - `!important` isn't just lower-priority in GTK3's CSS parser, it's rejected outright — every declaration using it gets dropped entirely ("Junk at end of value" under `GTK_DEBUG=interactive`). [`theme/templates/gtk3/gtk.css`](theme/templates/gtk3/gtk.css) has none; it doesn't need any, since `~/.config/gtk-3.0/gtk.css` already loads at `GTK_STYLE_PROVIDER_PRIORITY_USER`, above any theme's own CSS
  - The GTK3 *widget* theme (`gtk-theme-name`) and *icon* theme (`icon-theme`) resolve completely differently under Hyprland (no XSETTINGS daemon here). The widget theme needs [`gtk-3.0/settings.ini`](gtk-3.0/settings.ini) set directly; the icon theme is read straight from `gsettings`/dconf regardless (set in `hyprland.lua`'s `config.reloaded` hook) — putting it in `settings.ini` too does nothing, confirmed with `strace` showing which `folder.svg` actually got opened
  - Thunar's grid is `ExoIconView`, an old widget that fetches its selection color as a named symbolic color (`gtk_style_context_lookup_color("theme_selected_bg_color")`) instead of through normal `:selected` CSS matching — `.view:selected` and even a blanket `*:selected` do nothing for it. The fix is redefining `@define-color theme_selected_bg_color`/`theme_selected_fg_color` (+ the `unfocused_` pair) in `gtk.css`, which is what `gtk_selection_color`/`gtk_selection_opacity` actually drive
  - Folder icon *colors* aren't CSS at all — they're baked into the icon theme's SVGs. [`theme/icon_theme.py`](theme/icon_theme.py) generates a small icon theme at `~/.local/share/icons/AetherRice` (inheriting Papirus-Dark for everything else) by taking Papirus-Dark's own "blue" folder SVGs and substituting their two fixed colors for the accent and a darkened variant — no sudo needed, and it matches the accent exactly rather than snapping to one of `papirus-folders`' fixed presets
- [`theme/render.py`](theme/render.py) renders every template to its destination and reloads the affected apps (`hyprctl reload`, `makoctl reload`, kitty via `SIGUSR1`, a best-effort `dbus-send` KGlobalSettings ping for KDE apps). Qt/GTK apps only read their palette/CSS at startup, and not every app listens for the `dbus-send` ping either — an already-open window generally keeps its old colors until it's restarted, a freshly launched one picks up a palette change immediately. It also pings the running shell over Quickshell's two IPC targets (`theme` for the bar, `theme-widget` for the widget itself — two separate top-level QML components) so the bar's own accent/border/pill colors and all four opacities, which live in QML rather than a config file another app reads, pick up changes immediately too — no restart. Run it after editing a template by hand, or use `--set KEY VALUE` to change one color (`#rrggbb`) or opacity (`0`-`1`) from a terminal, `--get KEY` / `--dump` to read the palette back out
- [`theme/wallpaper.py`](theme/wallpaper.py) swaps the wallpaper: `apply <path>` archives the current one (deduped by hash) into `~/.local/share/quickshell/wallpapers/` and copies the new one to [`hypr/wallpaper.png`](hypr/wallpaper.png) (still that filename regardless of the real format inside - `swaybg`/Qt image loading both sniff content, not the extension), `pick` does the same via a native file picker, `list` feeds the widget's gallery of past wallpapers, `start` (re)starts whichever backend the current wallpaper needs without touching it (called on Hyprland startup). A static image goes through `swaybg` as before; an animated GIF (detected by its magic bytes, not `.gif`) goes through [`awww`](https://codeberg.org/LGFae/awww) instead, since `swaybg` only ever shows one frame - `awww img`'s `--transition-type none` looked like the right flag for an instant switch but silently kills the render loop that also drives GIF frame advancement, so `--transition-step 255` is used instead for the same effect
- [`theme/presets.py`](theme/presets.py) saves/loads/deletes named snapshots of the *entire* palette (every color and opacity value) as JSON files in `~/.local/share/quickshell/theme-presets/` — per-machine user data, not project config, so it's never tracked by this repo, same reasoning as the wallpaper history above. A built-in `Default` entry (the palette below) is always available, can't be saved over or deleted, and doesn't live in that folder — it's hardcoded in both `presets.py` and the widget

mako's per-urgency border colors (normal = accent, low = muted, critical = red) work the same way as Hyprland's border colors: edit the template at `theme/templates/mako/colors.ini`, not `mako/colors.ini` itself — that gets overwritten on the next render.

**The SDDM login screen** ([`sddm/aether-rice/`](sddm/aether-rice/)) is a custom theme matching the rest of the rice, palette-driven the same way as everything else - but it needs a one-time root setup that isn't part of `install.sh --deps`, since the greeter runs as its own `sddm` user and can't read anything under `~/.config` ($HOME is `700`):

```bash
sudo mkdir -p /usr/share/sddm/themes/aether-rice
sudo chown "$USER":"$USER" /usr/share/sddm/themes/aether-rice   # so render.py can sync it without sudo from here on
sudo mkdir -p /etc/sddm.conf.d
printf '[Theme]\nCurrent=aether-rice\n\n[X11]\nDisplayCommand=/usr/share/sddm/themes/aether-rice/Xsetup\n' | sudo tee /etc/sddm.conf.d/theme.conf
```

After that, `theme/render.py` (called by the widget on every palette change, same as everything else) copies the current wallpaper and re-renders [`theme/templates/sddm/theme.conf`](theme/templates/sddm/theme.conf) straight into that system path (`sync_sddm_theme()` in `render.py`) - no further sudo needed, and it's a silent no-op if the system dir doesn't exist yet or isn't writable, so a machine that skips this setup just doesn't get a themed login screen instead of erroring.

Wallpaper changes need the same sync: `theme/wallpaper.py` doesn't go through `render.py` at all normally, so it calls `render.sync_sddm_theme()` itself directly at the end of `restart_wallpaper_daemon()` - without that, picking a new wallpaper in the widget would silently leave the login screen on the old one.

Things specific to SDDM that don't come up anywhere else in this rice:
- **Each connected monitor gets its own separate `Main.qml` instance** (confirmed with `sddm-greeter --test-mode`, two monitors, two windows) with its own local coordinate space - a `screenModel`-with-manual-geometry-offset approach (the pattern used in SDDM's own bundled `maya` theme) would push each screen's background out of that screen's own view. Plain `anchors.fill: parent` is what actually works here. The login card itself is only shown where the `primaryScreen` context property is true, so a dual-monitor setup gets exactly one card, not one per screen.
- **Which monitor SDDM considers primary defaults to whichever it enumerates first, not the biggest one.** `sddm/aether-rice/Xsetup` (wired up as `DisplayCommand` above) runs `xrandr --output <output> --primary` before the greeter starts to fix that - `<output>` is picked dynamically as whichever connected output has the largest resolution, not hardcoded, since Xorg (particularly with the nvidia driver, in use here) often names outputs differently than Wayland/DRM does (e.g. `DP-0` vs. Hyprland's `DP-1`) - a name copied from `hyprctl monitors` can silently match nothing in the greeter's own X server. It logs what it found and did to `/tmp/aether-rice-xsetup.log` for the next login if it ever needs re-diagnosing.
- **`SddmComponents`' `ComboBox`/`LayoutBox` open their dropdown as a plain child `Rectangle` anchored below themselves, not an actual popup** - it paints under whatever comes later in the same `Column`, not over it. The session/layout row is the last thing in the card for exactly this reason; putting it anywhere earlier (e.g. above the Login button, as originally built) gets its dropdown list rendered underneath - technically open, but invisible and unclickable behind the buttons below it.
- **`SddmComponents`' own `Button` can get its background stuck on the wrong color** (e.g. hover) instead of reverting to idle - it drives color through named QML `states`, and once something sets `color` outside that state machine, the idle state has nothing correct left to revert to. `Main.qml`'s Login/Shutdown/Reboot buttons are plain `Rectangle` + `MouseArea` instead, with color bound directly to `containsMouse` - no state machine, nothing to get stuck.
- **The keyboard layout shows/applies as the wrong one until the first keypress, every time.** This is a confirmed, still-open upstream SDDM 0.21 bug ([sddm/sddm#1845](https://github.com/sddm/sddm/issues/1845)), reproducible with every theme including SDDM's own bundled ones (the maintainer asked reporters to test other themes - same result on all of them). Nothing in a theme's QML can fix a backend bug; two different `keyboard.currentLayout` reassignment workarounds were tried here and removed again since neither helped.

`sddm-greeter --test-mode --theme <path>` can't verify everything: `sddm.hostName` comes back empty in test mode (no real greeter daemon behind it), so the heading shows "Welcome to" with nothing after it there specifically - expected to resolve once it's actually running as the login screen. Multi-monitor primary selection and the keyboard layout bug above need an actual logout to check, since test-mode doesn't run a real X server per screen or a real XKB backend.

Day to day, none of those scripts need to be run by hand — the **theme widget**, a small standalone Quickshell window pinned to the top-left corner of the main monitor (independent of the bar, and deliberately on the Bottom wlr layer so normal windows cover it instead of sitting over everything), has three buttons: a picture icon opens the wallpaper gallery/picker; a paintbrush icon opens a menu to pick which color role to change and then a palette (plus a hex field) to change it to, with an Opacity section below the role list — a slider per surface (Bar/Pills/Popups/Terminal) with its own small color swatch right next to it, since each of those pairs a `*_color` with a `*_opacity`; and a bookmark icon opens the preset list — a name field + Save button at the top, `Default` and every saved preset below it (click to load, trash icon to delete a saved one), with a checkmark on whichever one matches the palette currently live. All three call straight into the scripts above and reflect changes instantly — dragging a slider updates its own live preview continuously but only actually calls `render.py --set` (which reloads everything) on release, not on every pixel of movement.

A few icon colors in the bar are deliberately hardcoded rather than bound to the palette, where they happened to reuse the exact hex value of an unrelated role (e.g. the CPU pill's icon used to share `color12` with the help icon and every popup's detail text — recoloring one recolored the other) — see the comments at each spot in `Bar.qml` if a bar icon doesn't seem to follow a color change.

It's a blue theme (`#1793d1` accent on a dark `#1a1b26` background) built around the stock default Hyprland wallpaper — the anime girl waiting at the train stop with the glowing blue Hyprland-logo cats. Every accent color across the bar, Rofi, Kitty, and the rest was picked to match that wallpaper's palette rather than the other way around.

## Hotkeys

`Mod` = <kbd>Super</kbd>.

### Apps

| Key | Action |
|---|---|
| `Mod + Return` | Terminal (Kitty) |
| `Mod + W` | Browser (Zen) |
| `Mod + N` | File manager (Thunar) |
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

Beyond Hyprland itself, the bar's scripts expect: `quickshell`, `nmcli`, `wpctl`, `nvidia-smi` (GPU stats — no-ops gracefully if absent), `sensors` (lm_sensors, for CPU temperature), `python3`, and `curl` (for the network widget's public-IP lookup). The theme widget's wallpaper picker additionally needs `zenity` (native file picker) and `swaybg`; an animated GIF wallpaper additionally needs `awww` (optional - only touched when the active wallpaper is a GIF).

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
| `thunar` (+ `thunar-volman`, `thunar-archive-plugin`, `tumbler`, `gvfs`) | File manager, mounting, archives, thumbnails | `thunar thunar-volman thunar-archive-plugin tumbler gvfs` | `thunar thunar-volman thunar-archive-plugin tumbler gvfs` | `thunar thunar-volman thunar-archive-plugin tumbler gvfs` |
| `swaybg` | Wallpaper (static) | `swaybg` | `swaybg` | `swaybg` |
| `awww` | Wallpaper (animated GIF only, optional) | `awww` | build from [source](https://codeberg.org/LGFae/awww) | build from [source](https://codeberg.org/LGFae/awww) |
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
| `qt6ct` / `nwg-look` | Qt/GTK theming | `qt6ct nwg-look` | `qt6ct` (nwg-look: build) | `qt6ct` (nwg-look: build) |
| `materia-gtk-theme` | GTK theme | `materia-gtk-theme` | `materia-gtk-theme` | — (build) |
| `papirus-icon-theme` | Icon theme | `papirus-icon-theme` | `papirus-icon-theme` | `papirus-icon-theme` |
| `ttf-jetbrains-mono-nerd` | Bar/UI font | `ttf-jetbrains-mono-nerd` | — (manual install from [Nerd Fonts](https://www.nerdfonts.com/)) | — (manual install) |

```bash
# Arch (pacman - every package below is in the extra/multilib repos already
# enabled by default, no AUR helper needed)
sudo pacman -S --needed hyprland sddm xdg-desktop-portal-hyprland quickshell kitty rofi \
    mako thunar thunar-volman thunar-archive-plugin tumbler gvfs gvfs-mtp gvfs-smb \
    xarchiver swaybg awww hyprcursor librsvg grim slurp wl-clipboard cliphist zenity \
    networkmanager network-manager-applet wireplumber pavucontrol blueman brightnessctl \
    playerctl lm_sensors nvidia-utils curl python qt6ct nwg-look materia-gtk-theme \
    papirus-icon-theme ttf-jetbrains-mono-nerd

# Debian/Ubuntu (apt) - covers everything except Hyprland/quickshell/hyprcursor/
# cliphist, which need a third-party repo or a source build on this base
sudo apt install kitty rofi mako-notifier thunar thunar-volman thunar-archive-plugin \
    tumbler gvfs xarchiver swaybg librsvg2-bin grim slurp \
    wl-clipboard zenity network-manager network-manager-gnome wireplumber pavucontrol \
    blueman brightnessctl playerctl lm-sensors nvidia-utils-535 curl python3 \
    qt6ct materia-gtk-theme papirus-icon-theme sddm

# Fedora (dnf) - add the solopasha/hyprland COPR first for Hyprland/hyprcursor/
# xdg-desktop-portal-hyprland; quickshell/cliphist/nwg-look/materia-gtk-theme still need a build
sudo dnf copr enable solopasha/hyprland
sudo dnf install hyprland xdg-desktop-portal-hyprland hyprcursor kitty rofi mako thunar \
    thunar-volman thunar-archive-plugin tumbler gvfs gvfs-mtp gvfs-smb xarchiver \
    swaybg librsvg2-tools grim slurp wl-clipboard zenity NetworkManager \
    network-manager-applet wireplumber pavucontrol blueman brightnessctl playerctl \
    lm_sensors xorg-x11-drv-nvidia-cuda curl python3 qt6ct papirus-icon-theme sddm
```

**Anything not covered by a system package manager** (`quickshell`/`hyprcursor`/`cliphist` off-Arch, `nwg-look`/`materia-gtk-theme` off-Arch on Fedora): build from source per the project's own README, or check if the distro has an unofficial binary repo for it (Fedora COPR, a Debian PPA-equivalent, `chaotic-aur`-style prebuilt repos). Flatpak/Nix are worth a look for the optional apps below, but the bar/theming stack itself is system-level Wayland tooling that neither packages well.

Optional apps this config's hotkeys point at — swap the `hl.bind` targets in `hyprland.lua` for whatever you actually use instead of installing these: `zen-browser` (`Mod+W`, AUR `zen-browser-bin` on Arch; also on Flatpak as `io.github.zen_browser.zen`), `discord` (`Mod+Shift+C`, in most repos, incl. Arch `extra`; also Flatpak `com.discordapp.Discord`), `spotify` (`Mod+Shift+P`, AUR on Arch; also Flatpak `com.spotify.Client` or a Snap), `steam` (`Mod+Shift+S`, `multilib/steam` on Arch, `steam` on apt/dnf with the right repo enabled), `btop` (`Mod+Shift+T`, in most repos), `qalculate-gtk` (`Mod+Alt+C`, in most repos).

## Hardware

This config's software requirements (above) run on anything; a few specific settings inside it, though, are hardcoded to *my* hardware and will need editing — not just installing a package — to work on different hardware:

| Component | Mine | Where it's hardcoded | What happens on different hardware |
|---|---|---|---|
| CPU | AMD Ryzen 5 5600X | `quickshell/default/scripts/stats.sh` reads the `k10temp-pci-00c3` sensor chip by name for CPU temperature | On an Intel CPU (or any chip lm_sensors doesn't expose as `k10temp`) that lookup fails and the CPU pill's temperature/`Mod`-click toggle just shows `NA` — everything else in the script (usage %, per-core, load average) is chip-agnostic and keeps working |
| GPU | NVIDIA GeForce RTX 3060 | Same script shells out to `nvidia-smi` for the GPU pill | No `nvidia-smi` (AMD/Intel GPU, or no dGPU) → the GPU pill hides itself entirely (`gpuAvailable` goes false); it doesn't error, it just won't show |
| Monitors | 27" 2560×1440@144Hz (`DP-1`, desc `HKC OVERSEAS LIMITED 27E6QC`) + 23" 1680×1050@60Hz (`HDMI-A-1`, desc `LG Electronics L226W`) | `hl.monitor({...})` blocks and every `hl.workspace_rule({...})` in `hyprland.lua` match monitors by their exact EDID `desc:` string (find yours with `hyprctl monitors`) | With different monitors (or even the same models in a different plug order) these rules simply won't match anything — Hyprland falls back to its own defaults, so resolution/refresh-rate/position and the fixed per-monitor workspace assignments (1–4/9 on the main monitor, 5–8 on the second) silently stop applying. Update the `desc:` strings and positions to match `hyprctl monitors` output on the new setup |
| Keyboard layout | German (`de`) | `kb_layout = "de"` in `hyprland.lua` | Not a crash, just the wrong layout — change it to your own (`kb_layout = "us"`, etc.) |
| Motherboard / RAM / storage | ASUS ROG STRIX B550-F, 32 GB, NVMe SSDs (+ a USB stick) | Nothing — the disk pill enumerates real mounted filesystems and their device names live, nothing about specific drives is hardcoded | No changes needed regardless of storage layout |

None of this stops the config from *loading* on other hardware — Hyprland just silently falls back to sane defaults for anything that doesn't match, and the bar degrades gracefully (missing pills, `NA` values) rather than erroring. But if a monitor is misplaced/wrong-resolution, workspaces land on the wrong screen, or the GPU/CPU pill acts oddly, this table is where to look first before assuming something's broken.

## Layout

```
hypr/        Hyprland config (hyprland.lua is active, .conf kept for reference) + wallpaper.png + cursor/ (cursor theme source)
quickshell/  The bar (Bar.qml + helper QML components + scripts/) + ThemeWidget.qml (theming widget)
rofi/        Launcher config + theme
kitty/       Terminal config + theme
mako/        Notification daemon config (colors.ini generated by theme/render.py)
theme/       Palette source (colors.toml), per-app templates, render.py + wallpaper.py + presets.py
btop/        System monitor config
qt6ct/ nwg-look/ gtk-3.0/   Qt/GTK theming
sddm/        Login screen theme (Main.qml, theme.conf generated by theme/render.py) - see Theming
```
