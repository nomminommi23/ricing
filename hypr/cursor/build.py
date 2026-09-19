#!/usr/bin/env python3
"""Build the "ArchLogo" cursor theme: every Adwaita cursor shape redrawn in the
rice style (artwork in shapes.py: Arch-logo pointer, blue + dark outline).

Produces both formats into ~/.local/share/icons/ArchLogo:
  - hyprcursor (compiled with hyprcursor-util) for Hyprland itself
  - XCursor (written directly, no xcursorgen needed) for GTK/Qt/XWayland apps
Adwaita is only used as the shape list / alias map and as the fallback theme.

Needs: rsvg-convert, hyprcursor-util, and Adwaita cursors in /usr/share/icons.
"""
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from shapes import SHAPES, DELAY_MS  # noqa: E402

BASE = "/usr/share/icons/Adwaita"
NAME = "ArchLogo"
DEST = os.path.expanduser(f"~/.local/share/icons/{NAME}")
DESC = "Arch-logo cursor set in the rice palette"

# Same sizes Adwaita's hyprcursor extraction uses, plus a few X11 favourites.
HYPR_SIZES = [24, 30, 36, 48, 72, 96]
XCURSOR_SIZES = [24, 30, 32, 36, 48, 64, 72, 96]

_cache = {}


def render(svg, size):
    """SVG string -> (w, h, rows of RGBA bytes), cached (hypr and X sizes overlap)."""
    key = (svg, size)
    if key not in _cache:
        png = subprocess.run(["rsvg-convert", "-f", "png", "-w", str(size), "-h", str(size)],
                             input=svg.encode(), capture_output=True, check=True).stdout
        _cache[key] = (png, read_png(png))
    return _cache[key]


def read_png(d):
    """Minimal decoder for the 8-bit RGBA non-interlaced PNGs rsvg-convert writes."""
    p, idat = 8, b""
    while p < len(d):
        ln, typ = struct.unpack(">I4s", d[p:p + 8])
        body = d[p + 8:p + 8 + ln]
        p += 12 + ln
        if typ == b"IHDR":
            w, h, bd, ct, _, _, il = struct.unpack(">IIBBBBB", body)
            assert (bd, ct, il) == (8, 6, 0), "expected 8-bit RGBA, non-interlaced"
        elif typ == b"IDAT":
            idat += body
    raw, stride, prev, i, rows = zlib.decompress(idat), w * 4, bytearray(w * 4), 0, []
    for _ in range(h):
        f, line = raw[i], bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - 4] if x >= 4 else 0
            b = prev[x]
            c = prev[x - 4] if x >= 4 else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        rows.append(line)
        prev = line
    return w, h, rows


def xcursor_image(svg, size, hot, delay):
    png, (w, h, rows) = render(svg, size)
    pix = bytearray()
    for r in rows:
        for x in range(w):
            R, G, B, A = r[x * 4:x * 4 + 4]
            # XCursor stores premultiplied ARGB, little-endian
            pix += struct.pack("<I", (A << 24) | ((R * A // 255) << 16) | ((G * A // 255) << 8) | (B * A // 255))
    xh, yh = round(hot[0] / 256 * size), round(hot[1] / 256 * size)
    return struct.pack("<9I", 36, 0xFFFD0002, size, 1, w, h, xh, yh, delay) + bytes(pix), size


def write_xcursor(path, hot, frames):
    delay = DELAY_MS if len(frames) > 1 else 0
    # a reader picks the best size, then plays every chunk of that size in TOC order
    chunks = [xcursor_image(f, s, hot, delay) for s in XCURSOR_SIZES for f in frames]
    off = 16 + 12 * len(chunks)
    toc, body = b"", b""
    for data, size in chunks:
        toc += struct.pack("<3I", 0xFFFD0002, size, off + len(body))
        body += data
    with open(path, "wb") as f:
        f.write(struct.pack("<4s3I", b"Xcur", 16, 0x10000, len(chunks)) + toc + body)


def write_hypr_shape(shape_dir, name, hot, frames):
    """Replace one extracted Adwaita shape (PNGs + meta.hl), keeping its define_override aliases."""
    meta_path = os.path.join(shape_dir, "meta.hl")
    overrides = re.findall(r"^define_override.*$", open(meta_path).read(), re.M)
    for f in os.listdir(shape_dir):
        if f.endswith(".png"):
            os.remove(os.path.join(shape_dir, f))
    lines = ["resize_algorithm = none", f"hotspot_x = {hot[0] / 256:.4f}", f"hotspot_y = {hot[1] / 256:.4f}", ""]
    n = 0
    for f in frames:
        for s in HYPR_SIZES:
            fn = f"{name}_{n:03d}.png"
            open(os.path.join(shape_dir, fn), "wb").write(render(f, s)[0])
            lines.append(f"define_size = {s}, {fn}, {DELAY_MS if len(frames) > 1 else 50}")
            n += 1
    open(meta_path, "w").write("\n".join(lines + [""] + overrides) + "\n")


def main():
    for tool in ("rsvg-convert", "hyprcursor-util"):
        if not shutil.which(tool):
            sys.exit(f"missing dependency: {tool}")
    cur_base = os.path.join(BASE, "cursors")
    if not os.path.isdir(cur_base):
        sys.exit(f"base cursor theme not found: {BASE}")

    tmp = tempfile.mkdtemp(prefix="archcursor-")
    try:
        # --- hyprcursor: extract Adwaita, swap every shape, recompile ---
        subprocess.run(["hyprcursor-util", "--extract", BASE, "--output", tmp], check=True, stdout=subprocess.DEVNULL)
        src = os.path.join(tmp, "extracted_" + os.path.basename(BASE))
        hdir = os.path.join(src, "hyprcursors")
        for name in sorted(os.listdir(hdir)):
            if name not in SHAPES:
                sys.exit(f"no artwork for cursor shape '{name}'")
            write_hypr_shape(os.path.join(hdir, name), name, *SHAPES[name])
        manifest = os.path.join(src, "manifest.hl")
        text = open(manifest).read()
        text = re.sub(r"name = .*", f"name = {NAME}", text)
        text = re.sub(r"description = .*", f"description = {DESC}", text)
        open(manifest, "w").write(text)

        out = os.path.join(tmp, "out")
        os.makedirs(out)
        subprocess.run(["hyprcursor-util", "--create", src, "--output", out], check=True, stdout=subprocess.DEVNULL)
        built = [d for d in os.listdir(out) if os.path.exists(os.path.join(out, d, "manifest.hl"))]
        if len(built) != 1:
            sys.exit(f"unexpected hyprcursor-util output: {os.listdir(out)}")

        shutil.rmtree(DEST, ignore_errors=True)
        shutil.copytree(os.path.join(out, built[0]), DEST)

        # --- XCursor: one file per real shape, Adwaita's alias names symlinked to them ---
        cur = os.path.join(DEST, "cursors")
        os.makedirs(cur, exist_ok=True)
        for n in sorted(os.listdir(cur_base)):
            p = os.path.join(cur_base, n)
            if os.path.islink(p):
                os.symlink(os.path.basename(os.path.realpath(p)), os.path.join(cur, n))
            elif n in SHAPES:
                write_xcursor(os.path.join(cur, n), *SHAPES[n])
            else:
                sys.exit(f"no artwork for cursor shape '{n}'")
        with open(os.path.join(DEST, "index.theme"), "w") as f:
            f.write(f"[Icon Theme]\nName={NAME}\nComment={DESC}\nInherits={os.path.basename(BASE)}\n")
        # Xcursor's fallback theme is "default": apps that never see XCURSOR_THEME (Steam, Proton
        # containers, anything started before the env was set) land here and get ours too.
        fallback = os.path.join(os.path.dirname(DEST), "default", "index.theme")
        if not os.path.exists(fallback) or NAME in open(fallback).read():
            os.makedirs(os.path.dirname(fallback), exist_ok=True)
            with open(fallback, "w") as f:
                f.write(f"[Icon Theme]\nName=Default\nComment=Points at {NAME}\nInherits={NAME}\n")
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f"installed {NAME} -> {DEST}")


if __name__ == "__main__":
    main()
