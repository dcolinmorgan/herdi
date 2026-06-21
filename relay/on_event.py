#!/usr/bin/env python3
"""herdr plugin hook - pushes event to mosshy relay via UDP."""
import json, os, socket

event_raw = os.environ.get("HERDR_PLUGIN_EVENT_JSON", "{}")
try:
    event = json.loads(event_raw)
    data = event.get("data", {})
    payload = json.dumps({
        "pane_id": data.get("pane_id", ""),
        "status": (data.get("agent_status") or "").lower(),
        "agent": (data.get("agent") or data.get("display_agent") or "").lower(),
        "project": os.path.basename(data.get("cwd", "")),
    }).encode()
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(payload, ("127.0.0.1", 8376))
    sock.close()
except Exception:
    pass
