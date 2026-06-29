# 05 — Operations: Keep it running, update, troubleshoot

> **Audience:** whoever maintains the server. Covers running it permanently,
> deploying updates, restarting, and fixing common problems.

---

## Run it permanently (so it survives disconnects & reboots)

Running `langgraph dev` in an SSH terminal stops the moment you close the window.
To keep it alive 24/7, register it as a **systemd service** (a background service
that auto-starts on boot and auto-restarts if it crashes).

Run this once on the server:

```bash
sudo tee /etc/systemd/system/langgraph.service > /dev/null <<'EOF'
[Unit]
Description=LangGraph dev server
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/LangGraph
EnvironmentFile=/home/ubuntu/LangGraph/.env
ExecStart=/home/ubuntu/LangGraph/.venv/bin/langgraph dev --host 0.0.0.0 --port 8123
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable langgraph     # start automatically on boot
sudo systemctl start langgraph      # start it now
sudo systemctl status langgraph --no-pager
```

A green **`active (running)`** means it's live. Now you can close the terminal
and the server keeps running.

---

## Everyday service commands

```bash
sudo systemctl status langgraph     # is it running?
sudo systemctl restart langgraph    # restart it
sudo systemctl stop langgraph       # stop it
sudo systemctl start langgraph      # start it
journalctl -u langgraph -f          # watch live logs (Ctrl+C to exit)
journalctl -u langgraph -n 100      # last 100 log lines
```

---

## Deploy a code update

When you change code (e.g. edit `agent.py`) and push it to Git:

```bash
cd ~/LangGraph
git pull                            # get the latest code
source .venv/bin/activate
pip install -U -r requirements.txt  # in case dependencies changed
sudo systemctl restart langgraph    # apply the change
```

> Your `.env` is untouched by `git pull` (it's not in the repo), so your keys
> stay put.

---

## Change the AI model

Edit `agent.py`, line with `ChatAnthropic`:

```python
llm = ChatAnthropic(model="claude-sonnet-4-6")   # current
# Cheaper/faster:        claude-haiku-4-5-20251001
# Highest quality:       claude-opus-4-8
```

Then commit, push, and on the server: `git pull && sudo systemctl restart langgraph`.

---

## If you're NOT using systemd (manual run)

Start in the background with `nohup` so it survives disconnect:

```bash
cd ~/LangGraph
source .venv/bin/activate
set -a; source .env; set +a
nohup langgraph dev --host 0.0.0.0 --port 8123 > langgraph.log 2>&1 &
```

- View logs: `tail -f ~/LangGraph/langgraph.log`
- Stop it: `pkill -f "langgraph dev"`

(systemd is preferred — it auto-restarts on crash and reboot. `nohup` does not.)

---

## Security checklist (do this for any real use)

- [ ] **Restrict the firewall.** Networking → edit the port-8123 rule → set
      **Source IP** to your own IP only. The dev server has **no authentication**,
      so an open port = anyone can spend your Anthropic credits.
- [ ] **Never commit `.env`.** It's in `.gitignore` — keep it that way.
- [ ] **Rotate keys if leaked.** If a key ever appears in chat/screenshots/Git,
      revoke it (Anthropic console / LangSmith settings) and create a new one.
- [ ] **The `langgraph dev` server is for development.** For a public production
      service, put it behind a reverse proxy (nginx/Caddy) with HTTPS + auth, or
      use LangGraph's production server mode.

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Requests time out from outside | Firewall port 8123 closed / restricted to wrong IP | Networking tab → open/adjust the 8123 rule |
| "Connection refused" | Service not running | `sudo systemctl restart langgraph` |
| Service won't start | Bad `.env`, missing key, or wrong Python | `journalctl -u langgraph -n 50` to read the error |
| `langgraph dev` says "Python 3.11 required" | venv built with Python 3.10 | Rebuild venv with `python3.11 -m venv .venv` (see deployment guide) |
| `ensurepip is not available` | `python3-venv` not installed | `sudo apt-get install -y python3.11-venv` |
| Server killed / out of memory | 512MB instance too small | Use the $7 / 1GB plan |
| 500 error mentioning Anthropic | Invalid key or no credit | Check `ANTHROPIC_API_KEY` and Anthropic billing |
| No traces in LangSmith | Tracing off or wrong project | Ensure `LANGCHAIN_TRACING_V2=true` and check `LANGCHAIN_PROJECT` |

---

## Cost monitoring

- **Anthropic usage:** <https://console.anthropic.com> → Usage.
- **LangSmith usage (trace count vs free 5,000/mo):** smith.langchain.com →
  Settings → Usage.
- **Lightsail:** flat $7/mo (free for first 90 days). Watch the trial end date.

---

## Tear-down (if you stop using it)

1. Lightsail → instance → **Delete**.
2. Networking → **release the static IP** (an unattached static IP starts
   costing ~$3.60/mo, so don't leave it orphaned).
