# LangGraph + LangSmith on AWS Lightsail

A small, cheap, self-hosted **AI agent API** built with **LangGraph**, powered by
**Claude (Anthropic)**, observable via **LangSmith**, running on **AWS Lightsail**.

This repo includes full documentation written so that **anyone — even without
prior LangGraph or LangChain experience — can understand, deploy, and use it.**

---

## 📖 Documentation

Read these in order if you're new. Jump straight to what you need otherwise.

| Doc | What it covers | Read this if... |
|---|---|---|
| [docs/01-overview.md](docs/01-overview.md) | What this is, the tools, the jargon, the costs | ...you're brand new and want the big picture |
| [docs/02-architecture-flow.md](docs/02-architecture-flow.md) | How it works internally — the graph, the state, the request flow | ...you want to understand the "how" |
| [docs/03-deployment-guide.md](docs/03-deployment-guide.md) | Step-by-step deploy from scratch on AWS Lightsail | ...you want to set up your own copy |
| [docs/04-access-and-usage.md](docs/04-access-and-usage.md) | How to call the running server (curl, Python, JS) | ...you just want to *use* it |
| [docs/05-operations.md](docs/05-operations.md) | Keep it running 24/7, deploy updates, troubleshoot, security | ...you maintain the server |

---

## ⚡ TL;DR

**Use the live server:**
```bash
curl -s -X POST http://13.203.182.189:8123/runs/wait \
  -H "Content-Type: application/json" \
  -d '{"assistant_id":"agent","input":{"messages":[{"role":"user","content":"hi"}]}}'
```
Interactive docs: `http://13.203.182.189:8123/docs` ·
Traces: [smith.langchain.com](https://smith.langchain.com) → project `Ai-Poc-Dev`

**Deploy your own:** follow [docs/03-deployment-guide.md](docs/03-deployment-guide.md).

---

## 🧱 What's in this repo

| File | Purpose |
|---|---|
| `agent.py` | The LangGraph agent (a one-node graph that calls Claude) |
| `langgraph.json` | Tells the LangGraph server which graph to run |
| `requirements.txt` | Python dependencies |
| `.env.example` | Template for the secrets file (copy to `.env`, fill in keys) |
| `.gitignore` | Keeps `.env` and junk out of Git |
| `deploy-lite.sh` | Cheapest deploy path (in-memory, no Docker) |
| `deploy.sh` + `docker-compose.yml` | Alternative Docker-based deploy (persistent) |
| `docs/` | Full guides (see table above) |

> **Secrets never live in this repo.** The `.env` file with real API keys is
> created directly on the server and is git-ignored.

---

## 🧰 Tech stack at a glance

- **LangGraph** — orchestrates the AI workflow and serves it as an HTTP API (free, self-hosted)
- **LangChain (langchain-anthropic)** — connects to the Claude model
- **Claude `claude-sonnet-4-6`** — the AI model (Anthropic)
- **LangSmith** — tracing & observability (free cloud tier)
- **AWS Lightsail** — Ubuntu 22.04, 1 GB RAM (~$7/mo, free 90 days)
- **Python 3.11**

---

## 💸 Cost

Roughly **$0 for the first 90 days** (Lightsail free trial + free LangSmith tier),
then **~$7/month** for the server plus a few cents of Claude usage for dev.
Details in [docs/01-overview.md](docs/01-overview.md).
