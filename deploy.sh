#!/usr/bin/env bash
# Run from the project dir on the Lightsail instance.
set -euo pipefail

# Install the CLI locally just to generate the Dockerfile
pip install -U "langgraph-cli[inmem]"

# Generates a ./Dockerfile from langgraph.json (uses your deps + graphs)
langgraph dockerfile Dockerfile

# Build and start everything in the background
docker compose up --build -d

echo "Waiting for API to come up..."
sleep 10
curl -s http://localhost:8123/ok && echo " <- LangGraph API is healthy"
