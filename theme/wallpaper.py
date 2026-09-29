#!/usr/bin/env python3
"""Manages the desktop wallpaper (~/.config/hypr/wallpaper.png, loaded by swaybg/awww).

  wallpaper.py list             JSON array of previously used wallpapers (newest first),
                                 each {id, path, added, current}; "path" is directly usable
                                 as a QML Image source
  wallpaper.py apply <path>     archive the current wallpaper, make <path> the new one
  wallpaper.py pick             open a native file picker, then apply the chosen file
  wallpaper.py remove <id>      delete one archived wallpaper (refuses the current one)
  wallpaper.py start            (re)start whichever daemon the current wallpaper needs,
                                 without touching it - called on Hyprland startup

The picker button in the ThemeWidget calls "list" to fill its gallery of recommendations,
"pick" for "choose a new file", and "apply" again when a gallery entry is clicked.

Static images go through swaybg, same as always. An animated GIF needs an actual
compositing daemon instead - swaybg only ever shows one frame - so those go through
awww (already installed; a swww-like wlroots wallpaper daemon that also does gifs).
Which one applies is decided by sniffing the file's magic bytes, not its extension:
ACTIVE is always literally named wallpaper.png regardless of the real format inside
(pre-existing, swaybg/Qt image loading both sniff content anyway), so a fixed ".gif"
check on that path would never match.
"""
import hashlib
import json
import os
import shutil
import subprocess
import sys
import time

import render

ACTIVE = os.path.expanduser("~/.config/hypr/wallpaper.png")
ARCHIVE = os.path.expanduser("~/.local/share/quickshell/wallpapers")
MANIFEST = os.path.join(ARCHIVE, "manifest.json")


def is_gif(path):
    try:
        with open(path, "rb") as f:
            return f.read(6) in (b"GIF87a", b"GIF89a")
    except OSError:
        return False


def load_manifest():
    try:
        return json.load(open(MANIFEST))
    except (OSError, json.JSONDecodeError):
        return []


def save_manifest(entries):
    os.makedirs(ARCHIVE, exist_ok=True)
    json.dump(entries, open(MANIFEST, "w"), indent=1)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def archive_current(entries):
    """Copies the currently active wallpaper into the archive, if it isn't there already."""
    if not os.path.isfile(ACTIVE):
        return
    digest = sha256(ACTIVE)
    if any(e["sha256"] == digest for e in entries):
        return
    os.makedirs(ARCHIVE, exist_ok=True)
    next_id = max([e["id"] for e in entries], default=0) + 1
    ext = ".gif" if is_gif(ACTIVE) else (os.path.splitext(ACTIVE)[1] or ".png")
    dest = os.path.join(ARCHIVE, f"{next_id:04d}{ext}")
    shutil.copy2(ACTIVE, dest)
    entries.append({"id": next_id, "file": os.path.basename(dest), "sha256": digest,
                    "added": time.strftime("%Y-%m-%d %H:%M")})


def restart_wallpaper_daemon():
    if is_gif(ACTIVE):
        subprocess.run(["pkill", "-x", "swaybg"], check=False, capture_output=True)
        if subprocess.run(["awww", "query"], capture_output=True, timeout=2).returncode != 0:
            subprocess.Popen(["awww-daemon"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                              start_new_session=True)
            for _ in range(20):  # wait for the daemon's socket, up to ~2s
                time.sleep(0.1)
                if subprocess.run(["awww", "query"], capture_output=True, timeout=2).returncode == 0:
                    break
            time.sleep(0.3)  # query succeeding doesn't mean it's ready for `img` yet
        # --transition-step 255 for an instant switch, same end result as
        # --transition-type none - but "none" takes a code path in awww that also kills
        # the render loop driving GIF frame advancement, leaving it stuck on one frame.
        subprocess.run(["awww", "img", ACTIVE, "--resize", "crop", "--transition-step", "255"],
                        check=False, capture_output=True, timeout=10)
    else:
        subprocess.run(["pkill", "-x", "awww-daemon"], check=False, capture_output=True)
        subprocess.run(["pkill", "-x", "swaybg"], check=False, capture_output=True)
        subprocess.Popen(["swaybg", "-i", ACTIVE, "-m", "fill"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                          start_new_session=True)
    render.sync_sddm_theme()  # wallpaper.py never calls render.py, so this doesn't
                              # happen automatically otherwise - the login screen's
                              # background would just keep showing whatever it last was.


def cmd_list():
    entries = load_manifest()
    current = sha256(ACTIVE) if os.path.isfile(ACTIVE) else None
    out = [{"id": e["id"], "path": os.path.join(ARCHIVE, e["file"]), "added": e["added"],
           "current": e["sha256"] == current} for e in entries]
    out.sort(key=lambda e: -e["id"])
    print(json.dumps(out))


def cmd_apply(path):
    path = os.path.expanduser(path)
    if not os.path.isfile(path):
        sys.exit(f"wallpaper.py: no such file: {path}")
    entries = load_manifest()
    archive_current(entries)
    shutil.copy2(path, ACTIVE)
    save_manifest(entries)
    restart_wallpaper_daemon()


def cmd_pick():
    result = subprocess.run(
        ["zenity", "--file-selection", "--title=Wallpaper wählen",
         "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.bmp *.gif"],
        capture_output=True, text=True)
    path = result.stdout.strip()
    if result.returncode != 0 or not path:
        return  # cancelled
    cmd_apply(path)


def cmd_remove(id_str):
    wanted = int(id_str)
    entries = load_manifest()
    current = sha256(ACTIVE) if os.path.isfile(ACTIVE) else None
    match = next((e for e in entries if e["id"] == wanted), None)
    if match is None:
        sys.exit(f"wallpaper.py: no archived wallpaper with id {wanted}")
    if match["sha256"] == current:
        sys.exit("wallpaper.py: refusing to remove the currently active wallpaper")
    os.remove(os.path.join(ARCHIVE, match["file"]))
    save_manifest([e for e in entries if e["id"] != wanted])


def cmd_start():
    if os.path.isfile(ACTIVE):
        restart_wallpaper_daemon()


def main():
    args = sys.argv[1:]
    if args[:1] == ["list"]:
        cmd_list()
    elif args[:1] == ["apply"] and len(args) == 2:
        cmd_apply(args[1])
    elif args[:1] == ["pick"]:
        cmd_pick()
    elif args[:1] == ["remove"] and len(args) == 2:
        cmd_remove(args[1])
    elif args[:1] == ["start"]:
        cmd_start()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
