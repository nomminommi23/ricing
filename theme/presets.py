#!/usr/bin/env python3
"""Named snapshots of the whole palette (theme/colors.toml) - save, load, delete.

  presets.py list             JSON array of saved presets: [{name, current}, ...]
  presets.py default          JSON of the built-in Default baseline + whether it's active
  presets.py save <name>      snapshot the current palette under <name> (overwrites if it exists)
  presets.py load <name>      apply a saved preset (or "Default") as the active palette,
                               re-render every themed app's config and reload it
  presets.py delete <name>    remove a saved preset ("Default" can't be deleted)

Presets are per-machine user data, not project config, so - like the wallpaper history -
they live outside the dotfiles repo, in ~/.local/share/quickshell/theme-presets/.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render  # noqa: E402 - theme/render.py: load_colors, render_all, reload_apps, COLORS

STORE = os.path.expanduser("~/.local/share/quickshell/theme-presets")
NAME_RE = re.compile(r"^[A-Za-z0-9 _-]{1,40}$")

DEFAULT_NAME = "Default"
DEFAULT_PALETTE = {
    "accent": "#1793d1", "cursor": "#c0caf5",
    "foreground": "#c0caf5", "background": "#1a1b26",
    "selection_foreground": "#1a1b26", "selection_background": "#c0caf5",
    "color0": "#1a1b26", "color1": "#f7768e", "color2": "#a6e3a1", "color3": "#f9e2af",
    "color4": "#1793d1", "color5": "#cba6f7", "color6": "#89dceb", "color7": "#c0caf5",
    "color8": "#565f89", "color9": "#f7768e", "color10": "#a6e3a1", "color11": "#f9e2af",
    "color12": "#7aa2f7", "color13": "#cba6f7", "color14": "#89dceb", "color15": "#ffffff",
    "bar_color": "#12131b", "pill_color": "#1a1b26", "popup_color": "#1a1b26",
    "bar_opacity": 0.18, "pill_opacity": 0.85, "popup_opacity": 0.90, "terminal_opacity": 0.85,
}


def validate_name(name):
    if name == DEFAULT_NAME:
        sys.exit("presets.py: 'Default' is built in, can't save/delete over it")
    if not NAME_RE.match(name):
        sys.exit("presets.py: preset names may only use letters, digits, spaces, '-' and '_' "
                 "(max 40 characters)")


def path_for(name):
    return os.path.join(STORE, f"{name}.json")


def list_names():
    if not os.path.isdir(STORE):
        return []
    return sorted(f[:-5] for f in os.listdir(STORE) if f.endswith(".json"))


def load_preset(name):
    try:
        return json.load(open(path_for(name)))
    except OSError:
        sys.exit(f"presets.py: no preset named '{name}'")


def cmd_list():
    current = render.load_colors()
    out = [{"name": n, "current": load_preset(n) == current} for n in list_names()]
    print(json.dumps(out))


def cmd_default():
    current = render.load_colors()
    print(json.dumps({"name": DEFAULT_NAME, "current": DEFAULT_PALETTE == current}))


def cmd_save(name):
    validate_name(name)
    os.makedirs(STORE, exist_ok=True)
    json.dump(render.load_colors(), open(path_for(name), "w"), indent=1)


def cmd_load(name):
    palette = DEFAULT_PALETTE if name == DEFAULT_NAME else load_preset(name)
    current = render.load_colors()
    if palette.keys() - current.keys():
        sys.exit(f"presets.py: '{name}' has keys colors.toml doesn't know about "
                 f"({', '.join(sorted(palette.keys() - current.keys()))})")
    # Reuses colors.toml's own regex-substitution updater (same one --set uses) instead of
    # rewriting the file, so the comments/section headers a human wrote stay intact.
    render.set_colors([(k, str(v)) for k, v in palette.items()])
    render.render_all(render.load_colors())
    render.reload_apps()


def cmd_delete(name):
    validate_name(name)
    path = path_for(name)
    if not os.path.isfile(path):
        sys.exit(f"presets.py: no preset named '{name}'")
    os.remove(path)


def main():
    args = sys.argv[1:]
    if args[:1] == ["list"] and len(args) == 1:
        cmd_list()
    elif args[:1] == ["default"] and len(args) == 1:
        cmd_default()
    elif args[:1] == ["save"] and len(args) == 2:
        cmd_save(args[1])
    elif args[:1] == ["load"] and len(args) == 2:
        cmd_load(args[1])
    elif args[:1] == ["delete"] and len(args) == 2:
        cmd_delete(args[1])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
