# 1 — System Architecture & How It Works

> The complete self-hosted LangGraph AI platform: what we use, how the pieces fit, and the end-to-end request flow. Reflects the **live production setup**.

- **Domain:** `https://langgraph.sudoxp.com` (HTTPS)
- **Server:** AWS Lightsail, 4 GB RAM, Ubuntu 22.04 (Mumbai)
- **Model:** `claude-sonnet-4-6`
- **LangSmith project:** `Ai-Poc-Dev`

---

## The technology stack

| Layer | Technology | Role | Runs where |
|---|---|---|---|
| Orchestration | **LangGraph** | Defines & runs the agent as a graph of steps | Our server (Docker) |
| API server | **langgraph-api** | Turns the graph into a REST API (FastAPI/Uvicorn under the hood) | Our server (Docker) |
| LLM connector | **langchain-anthropic** | Connects the graph to Claude | Our server (Docker) |
| AI model | **Claude Sonnet 4.6** | Generates the replies | Anthropic cloud |
| Persistence | **PostgreSQL** | Saves conversation state, threads, memory | Our server (Docker) |
| Queue / cache | **Redis** | Task queue, streaming, background jobs | Our server (Docker) |
| Web server / HTTPS / auth | **Caddy** | Reverse proxy + auto HTTPS + API-key auth | Our server |
| Containerization | **Docker + Compose** | Runs the whole stack together | Our server |
| Observability | **LangSmith** | Trace logging + free license | LangChain cloud (free) |
| Visual IDE | **LangGraph Studio** | Build/test/debug agents | LangChain cloud (free) |
| Cloud host | **AWS Lightsail** | The server | AWS |
| DNS | **GoDaddy** | `langgraph.sudoxp.com` → server IP | GoDaddy |

> **We did not write any FastAPI code.** The LangGraph server generates the API (`/runs/wait`, `/threads`, `/docs`, …) automatically from `agent.py` + `langgraph.json`.

---

## Architecture

```
                          INTERNET
                             |
             +---------------+----------------+
             |                                |
   Team / Apps (API calls)          LangGraph Studio (browser)
             |                        smith.langchain.com
             +------- https://langgraph.sudoxp.com -------+
                             |  (port 443, HTTPS)
   ==========================v========================= OUR LIGHTSAIL SERVER ==
   |  CADDY (reverse proxy + HTTPS + API-key auth)                            |
   |     langgraph.sudoxp.com:443  -->  localhost:8123                        |
   |                              |                                           |
   |  DOCKER COMPOSE STACK        v                                           |
   |    langgraph-api  <-->  PostgreSQL (persistence)    Redis (queue)        |
   ==============================|===========================================
                                 |  (outbound)
                    +------------+-------------+
                    v                          v
             Claude (Anthropic)         LangSmith cloud
             generates replies          traces + license -> Ai-Poc-Dev
```

---

## Request flow (what happens on one call)

1. A caller (app / Studio) hits `https://langgraph.sudoxp.com/...`
2. **Caddy** receives it on 443 (HTTPS), checks the `X-Api-Key` (for protected endpoints), forwards to `localhost:8123`
3. **langgraph-api** loads the thread's saved state from **PostgreSQL**
4. The **agent graph runs** — it calls **Claude** for the reply
5. New state is **saved back to PostgreSQL**; **Redis** handles the run queue/streaming
6. A **trace** is sent to **LangSmith** (`Ai-Poc-Dev`)
7. The reply returns through Caddy to the caller

Only two things leave our server: the message goes to **Claude** (to generate the reply) and a copy of the run goes to **LangSmith** (for debugging, optional).

---

## Authentication (enforced at Caddy)

The free Self-Hosted Lite tier does **not** include LangGraph's built-in auth, so we enforce it at the Caddy layer:

- **Public (no key):** `/ok`, `/info`, `/docs`, `/openapi.json` — health/metadata only
- **Protected (require `X-Api-Key`):** `/runs`, `/threads`, and all agent operations

This protects Claude credits and data while letting Studio's connection probe (`/info`) succeed.

---

## Where data lives & what's ours

| Data | Location | Ours? |
|---|---|---|
| Agent code | GitHub + our server | ✅ 100% ours |
| Secret keys (`.env`) | Our server only | ✅ 100% ours |
| Conversation state / memory / threads | **PostgreSQL on our server** | ✅ 100% ours |
| HTTPS certificate | Our server (Caddy) | ✅ ours (free) |
| Traces (debug logs) | LangSmith cloud | ⚠️ copy sent (optional) |
| Studio UI | LangChain cloud | ⚠️ borrowed, free |
| AI replies | Anthropic (Claude) | ✗ needed for replies |

---

## Access points

| What | URL |
|---|---|
| Secure API | `https://langgraph.sudoxp.com` (needs `X-Api-Key`) |
| API docs | `https://langgraph.sudoxp.com/docs` |
| Health | `https://langgraph.sudoxp.com/ok` |
| Studio | `https://smith.langchain.com/studio/?baseUrl=https://langgraph.sudoxp.com` |
| Traces | smith.langchain.com → `Ai-Poc-Dev` |

See [2-building-agents.md](2-building-agents.md) and [3-setup-and-deployment.md](3-setup-and-deployment.md).
