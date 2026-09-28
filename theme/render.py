#!/usr/bin/env python3
"""Renders theme/colors.toml into every app's real config, replacing the aether GUI app.

  render.py            re-render every template from the current palette and reload apps
  render.py --no-reload  same, but skip reloading apps (used right after --set, which reloads itself)
  render.py --dump      print every color as JSON (used by ThemeWidget.qml)
  render.py --get KEY   print one color (e.g. for shell scripts)
  render.py --set KEY VALUE [KEY VALUE ...]   change one or more colors/opacities in colors.toml, re-render, reload

Templates live in theme/templates/<app>/{config.json,template}: config.json names the
template file and the destination it gets rendered to (~ expanded). Placeholders in a
template are {key}, {key.strip} (hex without '#'), {key.rgb} ("r,g,b" decimal, no
alpha - what KDE's kdeglobals/*.colors files use), or {key.rgba:ALPHA}.
"""
import json
import os
import re
import subprocess
import sys
import tomllib

HERE = os.path.dirname(os.path.abspath(__file__))
COLORS = os.path.join(HERE, "colors.toml")
TEMPLATES = os.path.join(HERE, "templates")

PLACEHOLDER = re.compile(r"\{([a-zA-Z0-9_]+)(?:\.([a-zA-Z0-9_]+))?(?::([^}]+))?\}")


def load_colors():
    with open(COLORS, "rb") as f:
        return tomllib.load(f)


def hex_to_rgb(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def substitute(text, colors):
    def repl(m):
        key, fmt, arg = m.group(1), m.group(2), m.group(3)
        if key not in colors:
            sys.exit(f"render.py: unknown color key '{key}' in template")
        value = colors[key]
        if fmt is None:
            return str(value)
        if not isinstance(value, str):
            sys.exit(f"render.py: '.{fmt}' needs a #rrggbb color, '{key}' is {value!r}")
        if fmt == "strip":
            return value.lstrip("#")
        if fmt == "rgba":
            r, g, b = hex_to_rgb(value)
            return f"rgba({r}, {g}, {b}, {arg})"
        if fmt == "rgb":
            r, g, b = hex_to_rgb(value)
            return f"{r},{g},{b}"
        sys.exit(f"render.py: unknown placeholder format '.{fmt}' in template")
    return PLACEHOLDER.sub(repl, text)


def render_all(colors):
    for app in sorted(os.listdir(TEMPLATES)):
        app_dir = os.path.join(TEMPLATES, app)
        cfg_path = os.path.join(app_dir, "config.json")
        if not os.path.isfile(cfg_path):
            continue
        cfg = json.load(open(cfg_path))
        template = open(os.path.join(app_dir, cfg["template"])).read()
        dest = os.path.expanduser(cfg["destination"])
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        open(dest, "w").write(substitute(template, colors))
        print(f"rendered {app} -> {dest}")


def reload_apps():
    subprocess.run(["hyprctl", "reload"], check=False, capture_output=True)
    subprocess.run(["makoctl", "reload"], check=False, capture_output=True)
    subprocess.run(["pkill", "--signal", "USR1", "-x", "kitty"], check=False, capture_output=True)
    # Best-effort: tell the running shell (bar + theme widget, two separate IPC targets
    # since they're two separate top-level QML components) to re-fetch the palette, for
    # the bits of it (pill/popup/bar opacity) that only live in QML, not another app's
    # config file. A no-op if quickshell isn't running.
    for target in ("theme", "theme-widget"):
        subprocess.run(["quickshell", "-c", "default", "ipc", "call", target, "changed"],
                        check=False, capture_output=True, timeout=3)
    # Best-effort: nudge already-running KDE/Qt apps (Dolphin, etc.) to re-read kdeglobals.
    # Not every app listens for this, so a restart is still the reliable way to see it.
    subprocess.run(["dbus-send", "--type=signal", "/KGlobalSettings",
                    "org.kde.KGlobalSettings.notifyChange", "int32:0", "int32:0"],
                    check=False, capture_output=True, timeout=3)


def set_colors(pairs):
    colors = load_colors()
    text = open(COLORS).read()
    for key, value in pairs:
        if key not in colors:
            sys.exit(f"render.py: unknown color key '{key}'")
        if isinstance(colors[key], str):
            if not re.fullmatch(r"#[0-9a-fA-F]{6}", value):
                sys.exit(f"render.py: '{value}' is not a #rrggbb color")
            literal = f'"{value.lower()}"'
            pattern = r'"#[0-9a-fA-F]{6}"'
        else:
            try:
                v = float(value)
            except ValueError:
                sys.exit(f"render.py: '{value}' is not a number (expected 0-1, for '{key}')")
            if not 0 <= v <= 1:
                sys.exit(f"render.py: '{value}' is out of range (expected 0-1, for '{key}')")
            literal = repr(v)
            pattern = r"[0-9]*\.?[0-9]+"
        new_text, n = re.subn(rf"(?m)^{re.escape(key)}\s*=\s*{pattern}",
                              f"{key} = {literal}", text)
        if n != 1:
            sys.exit(f"render.py: could not find a single '{key} = ...' line to replace")
        text = new_text
    open(COLORS, "w").write(text)


def main():
    args = sys.argv[1:]
    if args[:1] == ["--dump"]:
        print(json.dumps(load_colors()))
        return
    if args[:1] == ["--get"]:
        colors = load_colors()
        key = args[1]
        if key not in colors:
            sys.exit(f"render.py: unknown color key '{key}'")
        print(colors[key])
        return
    if args[:1] == ["--set"]:
        rest = args[1:]
        if len(rest) % 2 != 0 or not rest:
            sys.exit("usage: render.py --set KEY VALUE [KEY VALUE ...]")
        pairs = list(zip(rest[0::2], rest[1::2]))
        set_colors(pairs)
        render_all(load_colors())
        reload_apps()
        return
    render_all(load_colors())
    if "--no-reload" not in args:
        reload_apps()


if __name__ == "__main__":
    main()
