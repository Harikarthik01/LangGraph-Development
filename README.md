# LangGraph AI Platform (Self-Hosted)

A cheap, fully self-hosted **AI agent platform** built with **LangGraph**, powered by
**Claude (Anthropic)**, with persistence (**PostgreSQL**), a task queue (**Redis**),
**HTTPS** (Caddy + Let's Encrypt), **API-key auth**, and observability via **LangSmith** —
running on **AWS Lightsail**.

Everything (code, agents, data, compute) lives on our own server. The only external
pieces are Claude (the model) and LangSmith/Studio (free observability + UI).

---

## Live server

| Thing | Value |
|---|---|
| Secure API | `https://langgraph.sudoxp.com` (needs `X-Api-Key`) |
| API docs | `https://langgraph.sudoxp.com/docs` |
| Health | `https://langgraph.sudoxp.com/ok` |
| Studio | `https://smith.langchain.com/studio/?baseUrl=https://langgraph.sudoxp.com` |
| Traces | smith.langchain.com → project `Ai-Poc-Dev` |
| Model | `claude-sonnet-4-6` |

---

## 📖 Documentation

| Doc | Covers |
|---|---|
| [docs/1-architecture.md](docs/1-architecture.md) | What we use, how it works, the flow, data ownership |
| [docs/2-building-agents.md](docs/2-building-agents.md) | Build agents, test in Studio, access them from code |
| [docs/3-setup-and-deployment.md](docs/3-setup-and-deployment.md) | Local setup, workflow, full deployment, operations |

Polished PDF versions (same content) are in the repo root:
`1-System-Architecture.pdf`, `2-Building-Agents-Guide.pdf`, `3-Developer-Setup-Deployment.pdf`.

---

## ⚡ Quick start

**Use the live server** (needs the API key — ask the team):
```bash
curl -s -X POST https://langgraph.sudoxp.com/runs/wait \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"assistant_id":"agent","input":{"messages":[{"role":"user","content":"hi"}]}}'
```

**Develop locally:**
```bash
python3.11 -m venv .venv && source .venv/bin/activate
pip install -U "langgraph-cli[inmem]" -r requirements.txt langchain-anthropic
cp .env.example .env    # fill in real keys
set -a; source .env; set +a
langgraph dev           # opens local Studio
```

**Deploy:** see [docs/3-setup-and-deployment.md](docs/3-setup-and-deployment.md).

---

## 🧱 Repo layout

| File | Purpose |
|---|---|
| `agent.py` | The LangGraph agent (one-node graph calling Claude) |
| `langgraph.json` | Registers the graph(s) the server runs |
| `requirements.txt` | App dependencies (base image provides LangGraph) |
| `Dockerfile` | Builds the agent into the production server image |
| `docker-compose.yml` | The 3-service stack: langgraph-api + Postgres + Redis |
| `.env.example` | Template for the secrets file (copy to `.env`) |
| `docs/` | Full documentation |

> **Secrets never live in the repo.** `.env` (real keys) is created on each machine and is git-ignored.

---

## 🧰 Stack

- **LangGraph** — agent orchestration + auto-generated REST API
- **Claude `claude-sonnet-4-6`** — the model (Anthropic)
- **PostgreSQL** — persistence / memory / threads
- **Redis** — task queue / streaming
- **Caddy** — HTTPS (Let's Encrypt) + API-key auth + CORS
- **Docker Compose** — runs the stack
- **LangSmith** — tracing (free tier) + Self-Hosted Lite license
- **AWS Lightsail** — 4 GB Ubuntu server (~$24/mo)

## 💸 Cost

~**$24/mo** (Lightsail 4 GB) + a few dollars of Claude usage. LangGraph, Studio, LangSmith
(free tier), Caddy, and the HTTPS certificate are all free.
