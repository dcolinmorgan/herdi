#!/usr/bin/env python3
"""Mosshy relay daemon - polls herdr, exposes WebSocket on port 8375, advertises via mDNS."""
import asyncio, json, os, re, signal, socket, subprocess
from websockets.server import serve

HERDR = os.environ.get("HERDR_BIN", "/opt/homebrew/bin/herdr")
WS_PORT = 8375
POLL_INTERVAL = 2

TOOL_OPTIONS = ["yes, single permission", "trust, always allow", "no (tab to edit)"]
SUBAGENT_OPTIONS = ["approve all pending", "configure individually", "exit (cancel subagents)"]
CHROME_RE = re.compile(
    r"^[\s─━═_—│|◔◑◕●\s]+$"
    r"|Kiro\s[·•]"
    r"|esc to cancel"
    r"|type to queue"
    r"|^\s*[◔◑◕●]\s+(Shell|Bash)"
)

clients = set()
last_statuses = {}
event_queue = asyncio.Queue()


def run_herdr(*args):
    try:
        r = subprocess.run([HERDR, *args], capture_output=True, text=True, timeout=10)
        return r.stdout.strip()
    except Exception:
        return ""


def get_agents():
    raw = run_herdr("pane", "list")
    try:
        data = json.loads(raw)
        panes = data.get("result", {}).get("panes", [])
        return [
            {"pane_id": p["pane_id"], "agent": p.get("agent", ""),
             "status": p.get("agent_status", "unknown"),
             "cwd": p.get("cwd", ""), "project": os.path.basename(p.get("cwd", ""))}
            for p in panes if p.get("agent")
        ]
    except (json.JSONDecodeError, KeyError):
        return []


def read_pane(pane_id):
    raw = run_herdr("pane", "read", pane_id, "--lines", "20", "--source", "recent")
    lines = [l for l in raw.splitlines() if l.strip() and not CHROME_RE.search(l)]
    return "\n".join(lines[-6:])


def detect_options(text):
    lower = text.lower()
    if "yes, single permission" in lower:
        return TOOL_OPTIONS
    if "approve all pending" in lower:
        return SUBAGENT_OPTIONS
    return None


async def broadcast(msg):
    data = json.dumps(msg)
    dead = set()
    for ws in clients:
        try:
            await ws.send(data)
        except Exception:
            dead.add(ws)
    clients -= dead


async def poll_loop():
    while True:
        agents = get_agents()
        if agents:
            await broadcast({"type": "agents", "agents": agents})
            for a in agents:
                pid, status = a["pane_id"], a["status"]
                if status == "blocked" and last_statuses.get(pid) != "blocked":
                    content = read_pane(pid)
                    options = detect_options(content)
                    await broadcast({
                        "type": "blocked", "pane_id": pid,
                        "agent": a["agent"], "project": a["project"],
                        "prompt": content[:500],
                        "options": options or TOOL_OPTIONS
                    })
                last_statuses[pid] = status
        await asyncio.sleep(POLL_INTERVAL)


async def event_push():
    while True:
        event = await event_queue.get()
        pane_id = event.get("pane_id", "")
        status = event.get("status", "")
        if status == "blocked" and pane_id:
            content = read_pane(pane_id)
            options = detect_options(content)
            await broadcast({
                "type": "blocked", "pane_id": pane_id,
                "agent": event.get("agent", ""),
                "project": event.get("project", ""),
                "prompt": content[:500],
                "options": options or TOOL_OPTIONS
            })


async def handle_client(ws):
    clients.add(ws)
    try:
        async for raw in ws:
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue
            if msg.get("type") == "respond":
                run_herdr("pane", "send-text", msg["pane_id"], msg["text"] + "\n")
    finally:
        clients.discard(ws)


class UDPPlugin(asyncio.DatagramProtocol):
    def datagram_received(self, data, addr):
        try:
            event_queue.put_nowait(json.loads(data.decode()))
        except Exception:
            pass


def start_mdns():
    try:
        from zeroconf import Zeroconf, ServiceInfo
        info = ServiceInfo(
            "_mosshy._tcp.local.", "Mosshy._mosshy._tcp.local.",
            addresses=[socket.inet_aton(socket.gethostbyname(socket.gethostname()))],
            port=WS_PORT,
        )
        zc = Zeroconf()
        zc.register_service(info)
        return zc, info
    except ImportError:
        print("zeroconf not installed, skipping mDNS")
        return None, None


async def main():
    zc, info = start_mdns()
    loop = asyncio.get_event_loop()
    await loop.create_datagram_endpoint(UDPPlugin, local_addr=("127.0.0.1", 8376))
    asyncio.create_task(poll_loop())
    asyncio.create_task(event_push())
    print(f"mosshy relay listening on ws://0.0.0.0:{WS_PORT}")
    async with serve(handle_client, "0.0.0.0", WS_PORT):
        stop = loop.create_future()
        for sig in (signal.SIGINT, signal.SIGTERM):
            loop.add_signal_handler(sig, stop.set_result, None)
        await stop
    if zc and info:
        zc.unregister_service(info)
        zc.close()


if __name__ == "__main__":
    asyncio.run(main())
