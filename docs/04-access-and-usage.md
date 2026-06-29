# 04 — Access & Usage: How to use OUR running server

> **Audience:** anyone who just wants to *use* the LangGraph server we already
> deployed — without setting anything up. You only need a terminal (or any tool
> that can make HTTP requests).

---

## Our live server

| Thing | Value |
|---|---|
| **Base URL** | `http://13.203.182.189:8123` |
| **Graph / assistant name** | `agent` |
| **Model behind it** | Claude `claude-sonnet-4-6` |
| **Interactive API docs** | `http://13.203.182.189:8123/docs` |
| **Traces (LangSmith)** | <https://smith.langchain.com> → project **Ai-Poc-Dev** |

> If the firewall is restricted to specific IPs, you may need your IP added
> before you can connect. Ask the owner if requests time out.

---

## 1. Quickest check — is it alive?

```bash
curl http://13.203.182.189:8123/ok
```

A small JSON/OK response means the server is up.

---

## 2. Send a message and get a reply

This runs the graph and waits for the final answer:

```bash
curl -s -X POST http://13.203.182.189:8123/runs/wait \
  -H "Content-Type: application/json" \
  -d '{
        "assistant_id": "agent",
        "input": { "messages": [ { "role": "user", "content": "Explain what an API is in one sentence." } ] }
      }'
```

**What the parts mean:**
- `assistant_id: "agent"` → which graph to run (we only have one, called `agent`).
- `input.messages` → the conversation so far. Each message has a `role`
  (`user` or `assistant`) and `content` (the text).

**What you get back:** a JSON object with a `messages` array. The **last** message
(`"type": "ai"`) is Claude's reply.

---

## 3. Have a multi-turn conversation

To keep context, send the previous messages back along with the new one:

```bash
curl -s -X POST http://13.203.182.189:8123/runs/wait \
  -H "Content-Type: application/json" \
  -d '{
        "assistant_id": "agent",
        "input": { "messages": [
          { "role": "user", "content": "My name is Hari." },
          { "role": "assistant", "content": "Nice to meet you, Hari!" },
          { "role": "user", "content": "What is my name?" }
        ] }
      }'
```

> This server runs in **in-memory** mode, so it doesn't remember past requests on
> its own — you include the history in each call (as shown above).

---

## 4. Call it from code

### Python
```python
import requests

resp = requests.post(
    "http://13.203.182.189:8123/runs/wait",
    json={
        "assistant_id": "agent",
        "input": {"messages": [{"role": "user", "content": "Hello!"}]},
    },
)
messages = resp.json()["messages"]
print(messages[-1]["content"])   # Claude's reply
```

### JavaScript (fetch)
```javascript
const res = await fetch("http://13.203.182.189:8123/runs/wait", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    assistant_id: "agent",
    input: { messages: [{ role: "user", content: "Hello!" }] },
  }),
});
const data = await res.json();
console.log(data.messages.at(-1).content); // Claude's reply
```

---

## 5. Explore everything in the browser

Open **`http://13.203.182.189:8123/docs`** — this is an interactive API reference
(Swagger UI). You can see every endpoint and even send test requests from the
page. Useful endpoints:

- `POST /runs/wait` — run and wait for the full answer (what we used above).
- `POST /runs/stream` — stream the answer token-by-token.
- `GET /assistants` — list available graphs.

---

## 6. See what happened (debugging)

Every call you make is recorded in **LangSmith**:

1. Go to <https://smith.langchain.com> and log in.
2. Left sidebar → **Projects** → **Ai-Poc-Dev**.
3. Click any run to see the inputs, the Claude call, the output, timing, and the
   token cost.

This is the main tool for understanding or debugging the agent's behaviour.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `curl` hangs then "timed out" | Firewall port 8123 closed, or restricted to an IP that isn't yours | Owner opens port 8123 / adds your IP (Networking tab) |
| "Connection refused" | The server process isn't running | Owner restarts it (see [`05-operations.md`](05-operations.md)) |
| Empty reply | Same as timeout — usually firewall | As above |
| `500` error mentioning Anthropic | API key invalid or out of credit | Owner checks `ANTHROPIC_API_KEY` / billing |

---

## Next

- **Run / restart / keep-alive details:** [`05-operations.md`](05-operations.md)
