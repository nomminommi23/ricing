#!/usr/bin/env python3
"""Controls RAM/GPU/mainboard RGB (Corsair/Gigabyte/ASUS Aura, all via OpenRGB's SDK
server - openrgb --server, autostarted in hyprland.lua) through openrgb-python.

  rgb.py status                       JSON: {"available": bool, "devices": [...]} -
                                       each device is {id, name, type, active_mode,
                                       modes: [{id, name}], color: [r, g, b]}
  rgb.py set-color ID[,ID...] R G B       Direct mode, that color, on every LED of
                                           each device
  rgb.py set-mode ID[,ID...] MODE_ID      switch each device to one of its listed
                                           modes - by id, so this assumes they share
                                           the same mode list (true for same-model
                                           devices like a pair of RAM sticks, nothing
                                           else needs more than one ID here)
  rgb.py set-speed ID[,ID...] VALUE       speed for each device's *currently active*
                                           mode - only if that mode's status has a
                                           non-null speed_min/speed_max (most do,
                                           Direct never does)
  rgb.py set-brightness ID[,ID...] VALUE  same, for brightness
  rgb.py sync-accent                  set-color on every device using the palette's
                                       current accent (theme/colors.toml) - the point of
                                       having this at all: make the whole PC's RGB match
                                       the rest of the rice in one call

Every command prints the same shape "status" does (the new state, after applying any
change) - deliberately never raises, since a traceback on stdout would break the bar's
JSON.parse of this output. {"available": false} covers the SDK server not running and
openrgb-python not being installed alike.

The server (openrgb 1.0-2, Arch extra) doesn't handle openrgb-python's default SDK
protocol version (4) correctly - the plugin-list request it sends during connection
setup just hangs until the socket times out. protocol_version=3 skips that and works.
"""
import json
import os
import sys
import time
import tomllib

COLORS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "theme", "colors.toml")


def get_client():
    from openrgb import OpenRGBClient
    return OpenRGBClient(protocol_version=3)


def device_json(d):
    active = d.modes[d.active_mode]
    return {
        "id": d.id,
        "name": d.name,
        "type": d.type.name,
        "active_mode": d.active_mode,
        "modes": [{"id": m.id, "name": m.name} for m in d.modes],
        "color": [d.colors[0].red, d.colors[0].green, d.colors[0].blue] if d.colors else [0, 0, 0],
        # Only the *active* mode's params matter here - every mode has its own
        # independent speed/brightness, there's no single "device speed".
        "speed": active.speed, "speed_min": active.speed_min, "speed_max": active.speed_max,
        "brightness": active.brightness, "brightness_min": active.brightness_min, "brightness_max": active.brightness_max,
    }


def status_json(c):
    return {"available": True, "devices": [device_json(d) for d in c.devices]}


def set_color(d, r, g, b, _retry=True):
    from openrgb.utils import RGBColor
    # set_color() alone doesn't reliably force Direct first - caught live: a device left
    # on a cycling mode (Rainbow/Color Cycle) kept animating straight through it, so the
    # static color never actually stuck, even though querying it back claimed it had.
    direct = next((m for m in d.modes if m.name == "Direct"), None)
    if direct is not None and d.active_mode != direct.id:
        d.set_mode(direct.id)
        time.sleep(0.3)  # the switch needs a moment before a color set reliably sticks
    d.set_color(RGBColor(r, g, b))
    if not _retry or direct is None:
        return
    # Also caught live, on the GPU specifically (its own i2c adapter, not the mainboard's
    # SMBus one that the RAM/mainboard share): intermittently, the mode switch above
    # silently doesn't take and the device is still cycling a few seconds later, despite
    # reporting Direct/the right color immediately after the calls above return. One
    # retry after actually re-reading the live state catches this without masking a
    # genuine failure as success.
    time.sleep(1.5)
    d.update()
    now = d.colors[0]
    if d.active_mode != direct.id or (now.red, now.green, now.blue) != (r, g, b):
        set_color(d, r, g, b, _retry=False)


def set_param(d, **kwargs):
    # Mutate the *active* mode's ModeData in place, then push it back - set_mode() also
    # doubles as "apply these params to the mode I'm already in", there's no separate
    # set_speed()/set_brightness() in openrgb-python.
    m = d.modes[d.active_mode]
    for k, v in kwargs.items():
        setattr(m, k, v)
    d.set_mode(m)


def main():
    args = sys.argv[1:]
    try:
        c = get_client()
        if args[:1] == ["set-color"]:
            ids, r, g, b = [int(i) for i in args[1].split(",")], int(args[2]), int(args[3]), int(args[4])
            for device_id in ids:
                set_color(c.devices[device_id], r, g, b)
        elif args[:1] == ["set-mode"]:
            ids, mode_id = [int(i) for i in args[1].split(",")], int(args[2])
            for device_id in ids:
                c.devices[device_id].set_mode(mode_id)
        elif args[:1] == ["set-speed"]:
            ids, value = [int(i) for i in args[1].split(",")], int(args[2])
            for device_id in ids:
                set_param(c.devices[device_id], speed=value)
        elif args[:1] == ["set-brightness"]:
            ids, value = [int(i) for i in args[1].split(",")], int(args[2])
            for device_id in ids:
                set_param(c.devices[device_id], brightness=value)
        elif args[:1] == ["sync-accent"]:
            with open(COLORS, "rb") as f:
                accent = tomllib.load(f)["accent"].lstrip("#")
            r, g, b = (int(accent[i:i + 2], 16) for i in (0, 2, 4))
            for d in c.devices:
                set_color(d, r, g, b)
        elif args[:1] != ["status"] and args:
            sys.exit(__doc__)
        c2 = get_client()  # re-fetch: the writes above don't update our local cache
        print(json.dumps(status_json(c2)))
    except Exception:
        print(json.dumps({"available": False}))


if __name__ == "__main__":
    main()
