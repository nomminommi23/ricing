#!/usr/bin/env python3
"""Notification panel backend: mako's list + history minus what was marked read.

  notifs.py             print the unread notifications as JSON, newest first
  notifs.py read KEY..  mark those keys as read
  notifs.py readall     mark everything currently listed as read

mako can't delete single history entries, so "read" lives in our own state file.
A key hashes id + app + text, so ids restarting from 1 after a mako restart
don't hide new notifications.
"""
import hashlib
import json
import os
import subprocess
import sys

STATE = os.path.join(os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")), "quickshell", "notifs-read")
KEEP = 500


def mako(cmd):
    try:
        out = subprocess.run(["makoctl", cmd, "-j"], capture_output=True, text=True, timeout=3).stdout
        return json.loads(out or "[]")
    except Exception:
        return []


def all_notifs():
    seen, items = set(), []
    for n in mako("list") + mako("history"):
        if n["id"] in seen:
            continue
        seen.add(n["id"])
        raw = f'{n["id"]}\0{n.get("app_name")}\0{n.get("summary")}\0{n.get("body")}'
        items.append({
            "key": hashlib.sha1(raw.encode()).hexdigest()[:16],
            "id": n["id"],
            "app": n.get("app_name") or "",
            "summary": n.get("summary") or "",
            "body": n.get("body") or "",
            "urgency": n.get("urgency") or "normal",
        })
    return sorted(items, key=lambda n: -n["id"])


def read_keys():
    try:
        return [l.strip() for l in open(STATE) if l.strip()]
    except OSError:
        return []


def mark(keys):
    old = read_keys()
    merged = old + [k for k in keys if k not in old]
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        f.write("\n".join(merged[-KEEP:]) + "\n")


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "read":
        mark(sys.argv[2:])
    elif len(sys.argv) > 1 and sys.argv[1] == "readall":
        mark([n["key"] for n in all_notifs()])
    else:
        done = set(read_keys())
        print(json.dumps([n for n in all_notifs() if n["key"] not in done]))
