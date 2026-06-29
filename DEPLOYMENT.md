# LangGraph on AWS Lightsail — Deployment Guide

A simple, cheap dev deployment of a **LangGraph** server with **LangSmith**
tracing, running on a small AWS Lightsail instance.

---

## 1. What we're using (the pieces)

| Component | Role | Where it runs | Cost |
|---|---|---|---|
| **LangGraph** | The orchestration engine — defines the graph (nodes + edges), manages state, exposes an HTTP API to run it. | Self-hosted on our Lightsail box | Free (Self-Hosted Lite, up to 1M node runs/yr) |
| **LangSmith** | Observability — records every run as a trace so we can see what happened, debug, and inspect state. Also acts as the license key that lets LangGraph Lite start. | Cloud (LangChain's free Developer tier) | Free (5k traces/mo) |
| **AWS Lightsail** | The server (a small Ubuntu VPS) that hosts our LangGraph process. | AWS | ~$3.50–5/mo |
| **LangGraph CLI** | Tool that builds/runs the server from our config. | On the Lightsail box | Free |
| *(LLM — optional)* | The "brain" (Claude/OpenAI/etc). **Not used right now** — our graph just echoes. Add later when needed. | External API | Pay per use |

> **Why no LLM yet?** LangGraph is only the workflow layer. It runs whatever
> logic we put in the nodes. Right now our node just echoes text, so no model
> and no API key are required. When we want real "AI" responses, we plug an
> LLM into a node.

---

## 2. How it works (the flow)

```
                         ┌──────────────────────────────┐
   Client (you / app)    │      AWS Lightsail VPS        │
   ─────────────────►    │                              │
   HTTP POST /runs       │   ┌──────────────────────┐   │
   { messages: [...] }   │   │   LangGraph Server   │   │
                         │   │  (langgraph dev)     │   │
                         │   │                      │   │
                         │   │   START              │   │
                         │   │     │                │   │
                         │   │     ▼                │   │
                         │   │  [ echo node ]       │   │
                         │   │     │                │   │
                         │   │     ▼                │   │
                         │   │    END               │   │
                         │   └─────────┬────────────┘   │
                         │             │ trace           │
                         └─────────────┼─────────────────┘
                                       │
                                       ▼
                            ┌────────────────────┐
                            │  LangSmith (cloud) │
                            │  shows every run   │
                            └────────────────────┘
   ◄─────────────────
   Response: { messages: [..., "echo: <your text>"] }
```

**Step by step:**
1. A client sends an HTTP request to the LangGraph server (`POST /runs/wait`)
   with input — a list of messages.
2. LangGraph starts the graph at `START` and walks the edges.
3. Execution hits the **`echo` node**, which takes the last message and returns
   `"echo: <text>"`. (Later this node could call an LLM instead.)
4. The graph reaches `END`; LangGraph returns the final state to the client.
5. In parallel, every run is reported to **LangSmith**, where we can open the
   trace and see the inputs, outputs, and timing of each node.

---

## 3. The files in this project

| File | What it does |
|---|---|
| `agent.py` | Defines the graph — the `State`, the `echo` node, and wires `START → echo → END`. Exposes `graph`. |
| `langgraph.json` | Tells the LangGraph server which file/symbol is the graph (`./agent.py:graph`) and where the env file is. |
| `requirements.txt` | Python deps (just `langgraph` + the CLI for now). |
| `.env` | Secrets/config — the LangSmith key and tracing settings. **Never commit this.** |
| `deploy-lite.sh` | **Cheapest path** — runs LangGraph in-memory, no Docker, fits a 512MB box. State resets on restart (fine for dev). |
| `deploy.sh` + `docker-compose.yml` | Heavier path — Docker stack with Postgres + Redis for persistent state. Needs a 2GB box (~$10/mo). |
| `setup-docker.sh` | Installs Docker — only needed for the `deploy.sh` path. |

---

## 4. How to deploy (cheapest path)

### Prerequisites
- An AWS account.
- A free LangSmith key from <https://smith.langchain.com> → Settings → API Keys
  (starts with `lsv2_pt_...`).

### Step 1 — Create the Lightsail instance
1. Go to <https://lightsail.aws.amazon.com> → **Create instance**.
2. **Linux/Unix → OS Only → Ubuntu 22.04**.
3. Plan: **$3.50/mo (512MB)** or **$5/mo (1GB, recommended)**.
4. Create it.

### Step 2 — Network setup
In the instance's **Networking** tab:
- Attach a **Static IP** (so the address doesn't change on reboot).
- Open firewall ports **22** (SSH) and **8123** (the API).

### Step 3 — Add your LangSmith key
Edit `.env` and replace both `lsv2_pt_xxxxxxxx` placeholders with your real key.

### Step 4 — Push the project and deploy
From your Mac:
```bash
scp -r /Users/sudoboat/Desktop/LangGraph ubuntu@<static-ip>:~/
ssh ubuntu@<static-ip>
```
On the instance:
```bash
cd ~/LangGraph
bash deploy-lite.sh
```

### Step 5 — Verify
```bash
curl http://<static-ip>:8123/ok
```

---

## 5. How to use it

### Call the API
```bash
curl -s -X POST http://<static-ip>:8123/runs/wait \
  -H "Content-Type: application/json" \
  -d '{
        "assistant_id": "agent",
        "input": { "messages": [{ "role": "user", "content": "hello" }] }
      }'
# -> returns: ... "echo: hello"
```
- `assistant_id` = the graph name from `langgraph.json` (`agent`).
- `input` = the initial state (here, a list of messages).

### See the traces
Open <https://smith.langchain.com> → project **`langgraph-dev`** → each call
appears as a trace you can click into.

### Visual debugging (optional)
LangGraph Studio can connect to your server URL (`http://<static-ip>:8123`)
to view and step through the graph in the browser.

### Check logs / restart (lite path)
```bash
tail -f ~/LangGraph/langgraph.log      # live logs
pkill -f "langgraph dev"               # stop
cd ~/LangGraph && bash deploy-lite.sh  # restart
```

---

## 6. How to extend it later

- **Add an LLM:** edit `agent.py` — replace the `echo` node with one that calls
  a model (e.g. `ChatAnthropic`), add the package to `requirements.txt`, and put
  the provider's API key in `.env`.
- **Add nodes:** define more functions and wire them with
  `builder.add_node(...)` / `builder.add_edge(...)` for multi-step workflows.
- **Persist state:** switch to the Docker path (`deploy.sh`) so runs survive
  restarts (needs the 2GB instance).

---

## 7. Cost summary

| Item | Monthly |
|---|---|
| LangSmith (free tier) | $0 |
| LangGraph (self-hosted lite) | $0 |
| Lightsail 512MB | $3.50 |
| Lightsail 1GB (recommended) | $5 |
| **Total (dev)** | **~$3.50–5** |

> Lightsail's smallest plans are often **free for the first 3 months**.
