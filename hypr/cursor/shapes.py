"""Cursor artwork for the ArchLogo theme, drawn procedurally as SVG.

Everything lives in a 256x256 box. Style: accent-blue shapes with a dark outline,
the Arch logo as the pointer, red only for "forbidden". SHAPES maps each XCursor
name to (hotspot in that box, [svg frames]); more than one frame = animated.
"""

OUT = "#0b1a26"    # outline
BLUE = "#1793d1"   # accent (aether color for the rice)
LIGHT = "#e6f1f8"
TRACK = "#2a4a63"
RED = "#e5546b"

ARCH = ("m127.98 12.07c-10.316 25.309-16.543 41.855-28.031 66.41 7.043 7.4609 15.691 16.156 29.734 25.977-15.098-6.207-25.395-12.445-33.094-18.918-14.703 30.68-37.742 74.391-84.492 158.39 36.746-21.219 65.23-34.293 91.773-39.289-1.1406-4.8945-1.7852-10.195-1.7422-15.734l0.042969-1.1719c0.58203-23.551 12.828-41.645 27.336-40.418 14.508 1.2266 25.781 21.316 25.199 44.867-0.10938 4.4219-0.60938 8.6914-1.4805 12.641 26.258 5.1328 54.438 18.18 90.684 39.105-7.1484-13.156-13.527-25.016-19.621-36.316-9.5938-7.4336-19.605-17.117-40.023-27.594 14.035 3.6406 24.082 7.8516 31.914 12.555-61.941-115.32-66.957-130.66-88.199-180.5z")

DEFS = f'<defs><path id="arch" fill-rule="evenodd" d="{ARCH}"/></defs>'
FRAMES = 20
DELAY_MS = 50


def svg(body):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256">{DEFS}{body}</svg>'


# --- primitives: F = filled shape, S = stroked line; lay() draws outlines first, then colours ---
def F(markup, color=BLUE):
    return ("f", markup, 0, color)


def S(markup, w, color=BLUE):
    return ("s", markup, w, color)


HALO = 16  # extra light rim outside the dark outline, so the cursor also reads on blue/dark backgrounds


def lay(items, ow=18):
    halo, dark, top = [], [], []
    for kind, m, w, c in items:
        if kind == "f":
            halo.append(f'<g fill="{LIGHT}" stroke="{LIGHT}" stroke-width="{ow + HALO}" stroke-linejoin="round">{m}</g>')
            dark.append(f'<g fill="{OUT}" stroke="{OUT}" stroke-width="{ow}" stroke-linejoin="round">{m}</g>')
            top.append(f'<g fill="{c}">{m}</g>')
        else:
            cap = 'stroke-linecap="round" stroke-linejoin="round"'
            halo.append(f'<g fill="none" stroke="{LIGHT}" stroke-width="{w + ow + HALO}" {cap}>{m}</g>')
            dark.append(f'<g fill="none" stroke="{OUT}" stroke-width="{w + ow}" {cap}>{m}</g>')
            top.append(f'<g fill="none" stroke="{c}" stroke-width="{w}" {cap}>{m}</g>')
    return "".join(halo + dark + top)


def poly(pts):
    return f'<polygon points="{" ".join(f"{x},{y}" for x, y in pts)}"/>'


def line(x1, y1, x2, y2):
    return f'<path d="M{x1} {y1}L{x2} {y2}"/>'


def rot(body, deg):
    return f'<g transform="rotate({deg} 128 128)">{body}</g>'


def glyph(d, w, color=OUT):
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>'


# --- pointers -------------------------------------------------------------------------------
def arrow(scale=1.0, outline=True):
    if not outline:
        return f'<g transform="translate(14 14) rotate(-26.565) scale(0.88) translate(-127.98 -12.07)"><use href="#arch" fill="{BLUE}"/></g>'
    g = ('<g transform="translate(14 14) rotate(-26.565) scale(0.88) translate(-127.98 -12.07)">'
         f'<use href="#arch" fill="{LIGHT}" stroke="{LIGHT}" stroke-width="{(18 + HALO) / 0.88:.1f}" stroke-linejoin="round"/>'
         f'<use href="#arch" fill="{OUT}" stroke="{OUT}" stroke-width="{18 / 0.88:.1f}" stroke-linejoin="round"/>'
         f'<use href="#arch" fill="{BLUE}"/></g>')
    if scale != 1.0:
        g = f'<g transform="translate(14 14) scale({scale}) translate(-14 -14)">{g}</g>'
    return g


def badge(items):
    return lay(items)


BX, BY = 194, 194  # badge centre next to the small arrow


def badged(inner):
    return svg(arrow(0.72) + inner)


def light_badge(glyphs):
    return lay([F(f'<circle cx="{BX}" cy="{BY}" r="44"/>', LIGHT)]) + glyphs


UPRIGHT = ('<g transform="translate(128 30) scale(0.8) translate(-127.98 -12.07)">'
           f'<use href="#arch" fill="{LIGHT}" stroke="{LIGHT}" stroke-width="{(18 + HALO) / 0.8:.1f}" stroke-linejoin="round"/>'
           f'<use href="#arch" fill="{OUT}" stroke="{OUT}" stroke-width="{18 / 0.8:.1f}" stroke-linejoin="round"/>'
           f'<use href="#arch" fill="{BLUE}"/></g>')


# --- resize family --------------------------------------------------------------------------
DOUBLE = poly([(24, 128), (80, 80), (80, 112), (176, 112), (176, 80), (232, 128),
               (176, 176), (176, 144), (80, 144), (80, 176)])
COL = (poly([(24, 128), (72, 84), (72, 112), (104, 112), (104, 144), (72, 144), (72, 172)])
       + poly([(232, 128), (184, 84), (184, 112), (152, 112), (152, 144), (184, 144), (184, 172)]))
QUAD = poly([(128, 24), (172, 68), (144, 68), (144, 112), (188, 112), (188, 84), (232, 128),
             (188, 172), (188, 144), (144, 144), (144, 188), (172, 188), (128, 232),
             (84, 188), (112, 188), (112, 144), (68, 144), (68, 172), (24, 128),
             (68, 84), (68, 112), (112, 112), (112, 68), (84, 68)])

IBEAM = [S(line(128, 56, 128, 200), 18), S(line(92, 56, 164, 56), 18), S(line(92, 200, 164, 200), 18)]
PLUS_FAT = poly([(104, 40), (152, 40), (152, 104), (216, 104), (216, 152), (152, 152),
                 (152, 216), (104, 216), (104, 152), (40, 152), (40, 104), (104, 104)])


def hand(fingers, thumb=True):
    parts = [F('<rect x="72" y="120" width="112" height="88" rx="28"/>')]
    for x, y in fingers:
        parts.append(F(f'<rect x="{x}" y="{y}" width="24" height="{150 - y}" rx="12"/>'))
    if thumb:
        parts.append(F('<rect x="44" y="128" width="34" height="52" rx="17" transform="rotate(-28 60 154)"/>'))
    return svg(lay(parts))


def ring(angle_deg=0, cx=128, cy=128, r=84, w=28, scale=1.0):
    d = f"M{cx} {cy - r} A{r} {r} 0 1 1 {cx - r} {cy}"
    track = f'<circle cx="{cx}" cy="{cy}" r="{r}"/>'
    arc = f'<g transform="rotate({angle_deg} {cx} {cy})"><path d="{d}"/></g>'
    return lay([S(track, w, TRACK), S(arc, w)])


def build():
    one = lambda hot, body: (hot, [svg(body)])
    c = (128, 128)
    a = (14, 14)
    forbidden = lay([S('<circle cx="128" cy="128" r="88"/>', 26, RED), S(line(66, 66, 190, 190), 26, RED)])
    zoom = lambda plus: svg(lay([S('<circle cx="108" cy="108" r="64"/>', 20), S(line(156, 156, 224, 224), 30)]
                                + [S(line(78, 108, 138, 108), 14, LIGHT)]
                                + ([S(line(108, 78, 108, 138), 14, LIGHT)] if plus else [])))

    shapes = {
        "default": one(a, arrow(outline=False)),
        "context-menu": one(a, badged(light_badge(
            glyph("M172 180H216M172 196H216M172 212H216", 9)))),
        "copy": one(a, badged(light_badge(glyph("M194 170V218M170 194H218", 12)))),
        "alias": one(a, badged(light_badge(
            glyph("M172 216C172 190 186 182 208 182", 11)
            + f'<polygon points="222,182 202,166 202,198" fill="{OUT}"/>'))),
        "no-drop": one(a, badged(lay([S(f'<circle cx="{BX}" cy="{BY}" r="34"/>', 14, RED),
                                      S(line(BX - 24, BY - 24, BX + 24, BY + 24), 14, RED)], 10))),
        "help": one(a, badged(light_badge(
            glyph("M176 182C176 166 210 164 212 182C214 198 196 198 196 210", 11)
            + f'<circle cx="196" cy="226" r="6.5" fill="{OUT}"/>'))),
        "not-allowed": one(c, forbidden),
        "pointer": one((128, 30), UPRIGHT),
        "text": one(c, lay(IBEAM)),
        "vertical-text": one(c, rot(lay(IBEAM), 90)),
        "crosshair": one(c, lay([S(line(128, 26, 128, 104), 16), S(line(128, 152, 128, 230), 16),
                                 S(line(26, 128, 104, 128), 16), S(line(152, 128, 230, 128), 16),
                                 F('<circle cx="128" cy="128" r="10"/>')])),
        "cell": one(c, lay([F(PLUS_FAT)])),
        "X_cursor": one(c, lay([S(line(52, 52, 204, 204), 28), S(line(204, 52, 52, 204), 28)])),
        "ew-resize": one(c, lay([F(DOUBLE)])),
        "ns-resize": one(c, rot(lay([F(DOUBLE)]), 90)),
        "nesw-resize": one(c, rot(lay([F(DOUBLE)]), -45)),
        "nwse-resize": one(c, rot(lay([F(DOUBLE)]), 45)),
        "col-resize": one(c, lay([F(COL), S(line(128, 60, 128, 196), 16)])),
        "row-resize": one(c, rot(lay([F(COL), S(line(128, 60, 128, 196), 16)]), 90)),
        "all-resize": one(c, lay([F(QUAD)])),
        "all-scroll": one(c, lay([F(QUAD)])),
        "grab": one((128, 104), hand([(76, 76), (104, 52), (132, 60), (160, 84)])),
        "grabbing": one(c, hand([(76, 104), (104, 100), (132, 102), (160, 108)])),
        "zoom-in": one((108, 108), zoom(True)),
        "zoom-out": one((108, 108), zoom(False)),
        "wait": (c, [svg(ring(i * 360 / FRAMES)) for i in range(FRAMES)]),
        "progress": (a, [svg(arrow(0.72) + ring(i * 360 / FRAMES, BX, BY, 30, 14)) for i in range(FRAMES)]),
    }
    # single-ended resize cursors (the window-edge ones) reuse the double-headed arrows
    for name, src in {"e-resize": "ew-resize", "w-resize": "ew-resize", "n-resize": "ns-resize",
                      "s-resize": "ns-resize", "ne-resize": "nesw-resize", "sw-resize": "nesw-resize",
                      "nw-resize": "nwse-resize", "se-resize": "nwse-resize"}.items():
        shapes[name] = shapes[src]
    return shapes


SHAPES = build()
