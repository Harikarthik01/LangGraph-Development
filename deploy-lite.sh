#!/usr/bin/env bash
# Cheapest deploy: in-memory LangGraph server, no Postgres/Redis, no Docker.
# Fits a 512MB / $3.50 Lightsail instance. State resets on restart (fine for dev).
set -euo pipefail

# Python + venv
sudo apt-get update
sudo apt-get install -y python3-pip python3-venv

cd ~/LangGraph
python3 -m venv .venv
source .venv/bin/activate
pip install -U "langgraph-cli[inmem]" -r requirements.txt

# Load env (LangSmith key, etc.)
set -a; source .env; set +a

# Run the in-memory dev server, bound to all interfaces so you can reach it.
# nohup keeps it alive after you disconnect SSH.
nohup langgraph dev --host 0.0.0.0 --port 8123 > langgraph.log 2>&1 &

sleep 8
curl -s http://localhost:8123/ok && echo " <- LangGraph is up (in-memory)"
echo "Logs: tail -f ~/LangGraph/langgraph.log"
