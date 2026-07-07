# 3 — Developer Setup & Deployment

> Set up locally, understand the workflow, and deploy the full production stack (Docker + Postgres + Redis + Caddy HTTPS + API-key auth).

---

## Part A — Local developer setup

**Prerequisites:** Python 3.11+, Git, a free LangSmith account, the shared API keys (Anthropic + LangSmith).

```bash
# 1. Clone
git clone https://github.com/Harikarthik01/LangGraph-Development.git LangGraph
cd LangGraph

# 2. Virtual env + install
python3.11 -m venv .venv
source .venv/bin/activate
pip install -U pip
pip install -U "langgraph-cli[inmem]" -r requirements.txt langchain-anthropic

# 3. Create .env (see .env.example — never committed)
#    ANTHROPIC_API_KEY, LANGCHAIN_*, LANGSMITH_API_KEY, LANGCHAIN_PROJECT=Ai-Poc-Dev

# 4. Run locally (opens Studio)
set -a; source .env; set +a
langgraph dev
```

Studio opens at `smith.langchain.com/studio/?baseUrl=http://127.0.0.1:2024`. Edit `agent.py` → save → hot-reload.

---

## Part B — Daily workflow

```
1. Edit / create an agent          (agent.py, researcher.py, ...)
2. Test locally                    langgraph dev  -> Studio
3. Commit & push                   git add . && git commit -m "..." && git push
4. Deploy on the server            git pull && sudo docker compose up -d --build
```

> Build & test **locally** (Studio works on localhost). The **server runs** the finished agents. Never edit code directly on the server.

---

## Part C — Full server deployment from scratch

### 1. Create the server (AWS Lightsail)

| Setting | Value |
|---|---|
| Blueprint | OS Only → Ubuntu 22.04 LTS |
| Plan | $24/mo — 4 GB RAM, 2 vCPU, 80 GB SSD |
| Static IP | Attach one (e.g. `13.203.182.189`) |
| Firewall | Open ports **22, 80, 443, 8123** |

> **Port 443 is required for HTTPS** — a missing 443 rule is the most common deployment snag.

### 2. Install Docker

```bash
sudo apt-get update -y
curl -fsSL https://get.docker.com | sh
sudo docker --version && sudo docker compose version
```

### 3. Clone the code & add secrets

```bash
cd ~
git clone https://github.com/Harikarthik01/LangGraph-Development.git LangGraph
cd LangGraph
nano .env        # paste the keys (same as local .env)
```

### 4. Build & launch the stack

```bash
sudo docker compose up -d --build       # ~3-5 min first time
sudo docker compose ps                   # expect 3 healthy services
curl http://localhost:8123/ok            # {"ok":true}
```

Starts `langgraph-api` + `langgraph-postgres` (memory) + `langgraph-redis` (queue). Auto-restarts on crash (`restart: unless-stopped`) and on reboot (Docker starts on boot).

---

## Part D — HTTPS + domain + auth (Caddy)

**1. Point DNS** — in your registrar (GoDaddy), add an **A record**: `langgraph → 13.203.182.189` (→ `langgraph.sudoxp.com`). Verify: `dig +short langgraph.sudoxp.com`.

**2. Install Caddy:**

```bash
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update && sudo apt install -y caddy
```

**3. Configure Caddy** (auto-HTTPS + API-key auth + CORS for Studio):

```
langgraph.sudoxp.com {
    @preflight method OPTIONS
    @needsauth {
        not path /ok /info /docs /openapi.json
        not method OPTIONS
        not header X-Api-Key "YOUR_SECRET_KEY"
    }
    handle @preflight {
        header Access-Control-Allow-Origin "{http.request.header.Origin}"
        header Access-Control-Allow-Methods "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        header Access-Control-Allow-Headers "{http.request.header.Access-Control-Request-Headers}"
        header Access-Control-Allow-Credentials "true"
        header Access-Control-Max-Age "3600"
        respond 204
    }
    handle {
        route {
            respond @needsauth "Unauthorized" 401
            reverse_proxy localhost:8123 {
                header_down Access-Control-Allow-Origin "{http.request.header.Origin}"
                header_down Access-Control-Allow-Credentials "true"
            }
        }
    }
}
```

Write it with `sudo tee /etc/caddy/Caddyfile`, then `sudo systemctl reload caddy`. Caddy auto-fetches a free Let's Encrypt certificate (~30s).

- Generate a key: `openssl rand -hex 24`
- Rotate anytime: edit the Caddyfile + `sudo systemctl reload caddy`
- `/ok`, `/info`, `/docs` stay public so Studio's connection probe (which doesn't send the key) succeeds; everything else needs the key.

**4. Verify:** `curl https://langgraph.sudoxp.com/ok` → `{"ok":true}`.

**5. Connect Studio** — `smith.langchain.com/studio/?baseUrl=https://langgraph.sudoxp.com`; in Server connection settings add Custom Header `X-Api-Key` = your key. (For daily building, local Studio via `langgraph dev` is simpler.)

---

## Part E — Operations

```bash
# everyday
sudo docker compose ps                       # status
sudo docker compose logs -f langgraph-api    # live logs
sudo docker compose restart                  # restart stack
sudo systemctl status caddy --no-pager       # HTTPS status

# deploy a code update
cd ~/LangGraph && git pull && sudo docker compose up -d --build
```

### Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| HTTPS times out | Firewall 443 not open | Add HTTPS/443 rule in Lightsail |
| Studio "domain not allowed" | Domain not in allowlist | Studio → Configure connection → add domain |
| Studio "connection failed" (`/info` 401) | Auth blocking Studio's probe | Ensure `/info` is public in the Caddyfile |
| Studio "Failed to fetch" (remote HTTP) | No HTTPS | Set up Caddy (Part D) |
| Build fails: langgraph version clash | App package named "langgraph" | Dockerfile: package name = `agent-app` |
| Container unhealthy | Bad `.env` / missing key | `docker compose logs langgraph-api` |
| Agent forgets everything | Not using threads | Use `/threads/{id}/runs/wait` |
| No traces in LangSmith | Tracing off / wrong project | Check `LANGCHAIN_TRACING_V2=true` |

### Security checklist

- [x] HTTPS on (Caddy + Let's Encrypt)
- [x] API-key auth on agent endpoints (`X-Api-Key`)
- [ ] Never commit `.env` (git-ignored — keep it so)
- [ ] Rotate any API key that leaks (Anthropic / LangSmith / server key)
- [ ] Optionally restrict port 8123 / 443 to team IPs for defense-in-depth
