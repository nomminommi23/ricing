#!/usr/bin/env python3
"""Prints the Razer mouse's battery as JSON: {"available": bool, "pct": int,
"charging": bool, "name": str}. "available" is false (nothing else meaningful in the
object) if openrazer isn't installed, its daemon isn't reachable, or no device is
connected - deliberately never raises, since a traceback on stdout would break the
bar's JSON.parse of this output.
"""
import json

try:
    from openrazer.client import DeviceManager
    devices = DeviceManager().devices
    if not devices:
        raise RuntimeError("no device")
    d = devices[0]
    print(json.dumps({"available": True, "pct": d.battery_level,
                      "charging": d.is_charging, "name": d.name}))
except Exception:
    print(json.dumps({"available": False}))
