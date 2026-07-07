# 2 — Building & Accessing AI Agents

> How to create AI agents in LangGraph, test them in Studio, and access the deployed agents from apps/code.

---

## Core concepts

| Term | What it is |
|---|---|
| **Graph** | The agent — a flowchart of steps. This is what you build. |
| **Node** | A single step (a Python function), e.g. "call the LLM". |
| **Edge** | An arrow connecting nodes (can be conditional). |
| **State** | The data that flows through the graph (e.g. the messages). |
| **assistant_id** | The name of a graph, used in API calls to pick which agent to run. |
| **Thread** | One ongoing conversation with saved history (stored in Postgres). |

---

## Our current agent (`agent.py`)

```python
"""LangGraph agent backed by Claude (Anthropic)."""
from typing import Annotated, TypedDict
from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages
from langchain_anthropic import ChatAnthropic

class State(TypedDict):
    messages: Annotated[list, add_messages]

llm = ChatAnthropic(model="claude-sonnet-4-6")

def chatbot(state: State):
    return {"messages": [llm.invoke(state["messages"])]}

builder = StateGraph(State)
builder.add_node("chatbot", chatbot)
builder.add_edge(START, "chatbot")
builder.add_edge("chatbot", END)
graph = builder.compile()   # the server imports this `graph`
```

`langgraph.json` maps the name `agent` to this graph.

---

## Create a NEW agent

**1. Create `researcher.py`:**

```python
from typing import Annotated, TypedDict
from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages
from langchain_anthropic import ChatAnthropic
from langchain_core.messages import SystemMessage

class State(TypedDict):
    messages: Annotated[list, add_messages]

llm = ChatAnthropic(model="claude-sonnet-4-6")

def researcher(state: State):
    system = SystemMessage(content="You are a meticulous research assistant. "
                                   "Answer with sources and bullet points.")
    return {"messages": [llm.invoke([system] + state["messages"])]}

builder = StateGraph(State)
builder.add_node("researcher", researcher)
builder.add_edge(START, "researcher")
builder.add_edge("researcher", END)
graph = builder.compile()
```

**2. Register it in `langgraph.json`:**

```json
{
  "dependencies": ["."],
  "graphs": {
    "agent": "./agent.py:graph",
    "researcher": "./researcher.py:graph"
  },
  "env": ".env"
}
```

**3. Test locally, then deploy:**

```bash
langgraph dev                       # test in local Studio
git add . && git commit -m "add researcher agent" && git push
# on the server:
cd ~/LangGraph && git pull && sudo docker compose up -d --build
```

Now call each by name: `assistant_id: "agent"` or `assistant_id: "researcher"`.

---

## Testing in Studio

| Environment | How |
|---|---|
| **Local (building)** ⭐ | `langgraph dev` → Studio opens at `...?baseUrl=http://127.0.0.1:2024` |
| **Live server** | `smith.langchain.com/studio/?baseUrl=https://langgraph.sudoxp.com` — in **Server connection settings**, add Custom Header `X-Api-Key` = your key |

---

## Accessing the deployed agents

Base URL: `https://langgraph.sudoxp.com`. **All agent calls require the header `X-Api-Key: <YOUR_API_KEY>`** (public endpoints: `/ok`, `/info`, `/docs`).

### curl
```bash
curl -s -X POST https://langgraph.sudoxp.com/runs/wait \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"assistant_id":"agent","input":{"messages":[{"role":"user","content":"Hello!"}]}}'
```

### Python
```python
import requests
r = requests.post("https://langgraph.sudoxp.com/runs/wait",
    headers={"X-Api-Key": "YOUR_API_KEY"},
    json={"assistant_id": "agent",
          "input": {"messages": [{"role": "user", "content": "Hello!"}]}})
print(r.json()["messages"][-1]["content"])
```

### JavaScript
```javascript
const res = await fetch("https://langgraph.sudoxp.com/runs/wait", {
  method: "POST",
  headers: { "X-Api-Key": "YOUR_API_KEY", "Content-Type": "application/json" },
  body: JSON.stringify({
    assistant_id: "agent",
    input: { messages: [{ role: "user", content: "Hello!" }] },
  }),
});
console.log((await res.json()).messages.at(-1).content);
```

### Key endpoints
| Endpoint | Purpose |
|---|---|
| `POST /runs/wait` | Run and wait for the full reply (stateless) |
| `POST /runs/stream` | Stream the reply token-by-token |
| `POST /threads` | Create a conversation thread (for memory) |
| `POST /threads/{id}/runs/wait` | Run inside a thread (remembers history) |
| `GET /assistants` / `/docs` | List agents / interactive API page |

---

## Threads & memory (multi-turn)

For an agent that **remembers**, use a thread (state saved in Postgres):

```bash
KEY="YOUR_API_KEY"

TID=$(curl -s -X POST https://langgraph.sudoxp.com/threads -d '{}' \
      -H "X-Api-Key: $KEY" -H "Content-Type: application/json" \
      | python3 -c "import sys,json;print(json.load(sys.stdin)['thread_id'])")

curl -s -X POST https://langgraph.sudoxp.com/threads/$TID/runs/wait \
  -H "X-Api-Key: $KEY" -H "Content-Type: application/json" \
  -d '{"assistant_id":"agent","input":{"messages":[{"role":"user","content":"My name is Hari."}]}}'

# later — the agent still remembers "Hari"
curl -s -X POST https://langgraph.sudoxp.com/threads/$TID/runs/wait \
  -H "X-Api-Key: $KEY" -H "Content-Type: application/json" \
  -d '{"assistant_id":"agent","input":{"messages":[{"role":"user","content":"What is my name?"}]}}'
```

> **Stateless** (`/runs/wait`, no thread) forgets between calls — you send full history each time. **Stateful** (`/threads/{id}/runs/wait`) remembers automatically (persisted in Postgres). Use threads for real conversations.
