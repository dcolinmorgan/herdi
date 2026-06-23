# Quick Start

Get mobile notifications + approval for your herdr agents in 60 seconds.

## 1. Start the relay (on your Mac)

```bash
git clone https://github.com/dcolinmorgan/herdr-remote
cd herdr-remote/relay
python3 -m venv .venv && .venv/bin/pip install websockets
.venv/bin/python3 herdr_relay.py
```

## 2. Expose it (pick one)

```bash
# Cloudflare tunnel (free, instant):
cloudflared tunnel --url http://localhost:8375
# → gives you https://something.trycloudflare.com
```

## 3. Install the plugin (on any machine with herdr)

```bash
herdr plugin install dcolinmorgan/herdr-push
export HERDR_RELAY="https://your-tunnel.trycloudflare.com"
launchctl setenv HERDR_RELAY "$HERDR_RELAY"
herdr server reload-config
```

## 4. Monitor

**Menu bar app** (macOS):
Download from [Releases](https://github.com/dcolinmorgan/herdr-remote/releases), open, it connects automatically.

**Telegram bot**:
```bash
export HERDR_TG_TOKEN="your-token" HERDR_TG_CHAT_ID="your-id"
python3 relay/herdr_telegram.py
```

**Terminal TUI**:
```bash
pip install textual websockets
python3 relay/herdr_tui.py
```

## 5. Test

```bash
herdr plugin action invoke herdr.push test
```

You should see a test agent appear on your dashboard.
