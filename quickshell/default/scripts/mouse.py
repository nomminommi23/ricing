#!/usr/bin/env python3
"""Reads/controls the Razer mouse via openrazer.

  mouse.py status                     JSON: battery + dpi + poll rate + idle time +
                                       low-battery threshold, or {"available": false}
  mouse.py set-dpi-stage N            apply stored DPI stage N (0-4)
  mouse.py set-poll-rate HZ           one of status's supported_poll_rates
  mouse.py set-idle-time SECONDS      wireless sleep timeout, 60-900
  mouse.py set-low-battery-threshold PCT

Every command prints the same shape "status" does (the new state, after applying any
change) - deliberately never raises, since a traceback on stdout would break the bar's
JSON.parse of this output. {"available": false} covers openrazer not being installed,
its daemon not being reachable, and no device being connected, alike.

openrazer-daemon only scans for devices at its own startup, not on USB hotplug - once
it's running, switching the mouse between its USB cable and its wireless dongle (each
a different USB product ID) goes completely unnoticed until something restarts it. So
an empty device list gets one retry after doing exactly that, instead of just reporting
unavailable until the next full daemon restart for an unrelated reason.
"""
import json
import subprocess
import sys
import time


def get_device():
    from openrazer.client import DeviceManager

    def devices():
        return DeviceManager().devices

    found = devices()
    if not found:
        subprocess.run(["systemctl", "--user", "restart", "openrazer-daemon"],
                        check=False, capture_output=True, timeout=5)
        time.sleep(1.5)
        found = devices()
    if not found:
        raise RuntimeError("no device")
    return found[0]


def status_json(d):
    stage_index, stages = d.dpi_stages
    return {
        "available": True,
        "name": d.name,
        "pct": d.battery_level,
        "charging": d.is_charging,
        "dpi": d.dpi[0],
        "dpi_stage": stage_index,
        "dpi_stages": [s[0] for s in stages],
        "poll_rate": d.poll_rate,
        "supported_poll_rates": d.supported_poll_rates,
        "idle_time": d.get_idle_time(),
        "low_battery_threshold": d.get_low_battery_threshold(),
    }


def main():
    args = sys.argv[1:]
    try:
        d = get_device()
        if args[:1] == ["set-dpi-stage"]:
            _, stages = d.dpi_stages
            n = int(args[1])
            d.dpi = stages[n]
        elif args[:1] == ["set-poll-rate"]:
            d.poll_rate = int(args[1])
        elif args[:1] == ["set-idle-time"]:
            d.set_idle_time(int(args[1]))
        elif args[:1] == ["set-low-battery-threshold"]:
            d.set_low_battery_threshold(int(args[1]))
        elif args[:1] != ["status"] and args:
            sys.exit(__doc__)
        print(json.dumps(status_json(d)))
    except Exception:
        print(json.dumps({"available": False}))


if __name__ == "__main__":
    main()
