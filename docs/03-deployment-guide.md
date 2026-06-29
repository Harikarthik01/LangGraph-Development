# 03 — Deployment Guide: Deploy from scratch

> **Audience:** someone setting up a brand-new copy of this on their own AWS
> account. Follow top to bottom. You do **not** need to know LangGraph — just
> copy the commands. Every step says *what* and *why*.

This is exactly how the live server was built.

---

## What you'll need before starting

1. An **AWS account** (for Lightsail).
2. An **Anthropic API key** — from <https://console.anthropic.com> → API Keys.
   Add a few dollars of credit. This is what pays for Claude's replies.
3. A **LangSmith API key** (free) — from <https://smith.langchain.com> →
   Settings → API Keys. Starts with `lsv2_pt_...`.
4. This project pushed to a **Git repo** (GitHub/Bitbucket) so the server can
   clone it. (Our repo: `https://github.com/Harikarthik01/LangGraph-Development`)

---

## Part A — Create the cloud server (AWS Lightsail)

1. Go to <https://lightsail.aws.amazon.com> → **Create instance**.
2. **Region:** pick the one closest to you (we used Mumbai / ap-south-1).
3. **Platform:** Linux/Unix.
4. **Blueprint:** **OS Only → Ubuntu 22.04 LTS**.
5. **Plan:** **$7/month (1 GB RAM, 2 vCPU)** — *free for the first 90 days*.
   > Don't pick the $5/512MB plan — it's too small and the server can crash.
6. **Name** it (e.g. `langgraph-dev`) → **Create instance**.
7. Wait ~1 minute until it shows **Running**.

### Give it a permanent address (static IP)

By default the server's IP changes if you stop/start it. Pin it:

1. Open the instance → **Networking** tab.
2. Under **Public IPv4**, click **Attach static IP** → name it → attach.
3. Note this IP — it's how you'll reach the server. (Ours: `13.203.182.189`.)

> A static IP is **free while attached to a running instance**.

### Open the port so you can reach the API

1. Still in **Networking** → **IPv4 Firewall** → **+ Add rule**.
2. Set: **Application = Custom**, **Protocol = TCP**, **Port = 8123**.
3. **Source IP address:**
   - **For testing:** choose **Any IPv4 address** (anyone can reach it).
   - **Recommended for dev:** choose **Custom IPv4 address** and enter *your*
     public IP (find it at <https://whatismyipaddress.com>). This means only you
     can call the server, which protects your Anthropic credits.
4. **Create.**

> Firewall rules are **free**.

---

## Part B — Set up the software on the server

### Connect to the server

Instance page → **Connect** tab → **Connect using SSH**. A black terminal opens
in your browser — you are now logged into the server as user `ubuntu`.

### Get the code onto the server

Clone the repo (replace the URL with yours):

```bash
cd ~
git clone https://github.com/Harikarthik01/LangGraph-Development.git LangGraph
cd LangGraph
ls -la
```

You should see `agent.py`, `langgraph.json`, `requirements.txt`, etc.
There is **no `.env`** — that's correct, secrets are never committed. You create
it next.

### Install Python 3.11

> **Why:** Ubuntu 22.04 ships Python 3.10, but the LangGraph server needs 3.11+.

```bash
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt-get update -y
sudo apt-get install -y python3.11 python3.11-venv python3-pip
```

### Create the `.env` file (your secrets)

```bash
nano .env
```

Paste this in, replacing each placeholder with your **real** keys:

```bash
ANTHROPIC_API_KEY=sk-ant-your-real-key
LANGCHAIN_TRACING_V2=true
LANGCHAIN_ENDPOINT=https://api.smith.langchain.com
LANGCHAIN_API_KEY=lsv2_pt_your-real-key
LANGCHAIN_PROJECT=Ai-Poc-Dev
LANGSMITH_API_KEY=lsv2_pt_your-real-key
```

Save and exit nano: **`Ctrl+O`**, then **`Enter`** (confirm filename), then
**`Ctrl+X`**. Verify with `cat .env`.

> `LANGCHAIN_PROJECT` is the name your traces appear under in LangSmith. Change
> it per environment (e.g. `Ai-Poc-Prod`).

### Install the Python dependencies

```bash
cd ~/LangGraph
python3.11 -m venv .venv          # create an isolated Python environment
source .venv/bin/activate         # activate it (prompt shows "(.venv)")
python --version                  # should say Python 3.11.x
pip install -U pip
pip install -U "langgraph-cli[inmem]" -r requirements.txt
```

This downloads LangGraph, the server, and the Anthropic connector (~1–2 min).

---

## Part C — Run it

### Quick test run (foreground)

```bash
cd ~/LangGraph
source .venv/bin/activate
set -a; source .env; set +a          # load the .env values into the shell
langgraph dev --host 0.0.0.0 --port 8123
```

You'll see a banner and:
```
- API: http://0.0.0.0:8123
- API Docs: http://0.0.0.0:8123/docs
```

The terminal now "hangs" — that's normal, the server is running.

### Test it

From your own computer (replace with your IP):

```bash
curl -s -X POST http://13.203.182.189:8123/runs/wait \
  -H "Content-Type: application/json" \
  -d '{"assistant_id":"agent","input":{"messages":[{"role":"user","content":"hi in one sentence"}]}}'
```

You should get a JSON reply from Claude. 🎉 Also check
<https://smith.langchain.com> → project **Ai-Poc-Dev** — the run appears there.

> **Important:** running it this way stops the moment you close the terminal.
> To keep it running forever, set it up as a service —
> see [`05-operations.md`](05-operations.md).

---

## Recap of the files involved

| File | Purpose |
|---|---|
| `agent.py` | Defines the graph (the AI workflow). |
| `langgraph.json` | Tells the server which graph to run and where `.env` is. |
| `requirements.txt` | The Python packages to install. |
| `.env` | Your secret keys — **created on the server, never committed**. |
| `.gitignore` | Ensures `.env` (and other junk) never gets pushed to Git. |

---

## Next

- **Keep it running 24/7 + troubleshooting:** [`05-operations.md`](05-operations.md)
- **How to actually call the API:** [`04-access-and-usage.md`](04-access-and-usage.md)
