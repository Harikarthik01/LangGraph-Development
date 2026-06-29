# 02 — Architecture & Flow: How it actually works

> **Audience:** anyone who wants to understand what happens "under the hood"
> when you call the service. No prior LangGraph knowledge needed.

---

## The big picture

```
┌─────────────┐         HTTP POST /runs/wait           ┌────────────────────────────┐
│             │  ───────────────────────────────────►  │   AWS Lightsail server      │
│  Client     │   { "assistant_id": "agent",           │   (Ubuntu, 1GB, Mumbai)     │
│  (you, an   │     "input": { "messages": [...] } }   │                            │
│   app, curl)│                                         │  ┌──────────────────────┐  │
│             │                                         │  │  LangGraph Server     │  │
│             │  ◄───────────────────────────────────  │  │  (port 8123)          │  │
└─────────────┘         JSON response (the reply)       │  │                      │  │
                                                        │  │   START               │  │
                                                        │  │     │                 │  │
                                                        │  │     ▼                 │  │
                                                        │  │  [ chatbot node ]─────┼──┼──► Claude API
                                                        │  │     │            ◄────┼──┼──  (Anthropic)
                                                        │  │     ▼                 │  │     returns reply
                                                        │  │    END                │  │
                                                        │  └──────────┬───────────┘  │
                                                        │             │ sends trace   │
                                                        └─────────────┼───────────────┘
                                                                      ▼
                                                          ┌────────────────────────┐
                                                          │  LangSmith (cloud)     │
                                                          │  smith.langchain.com   │
                                                          │  project: Ai-Poc-Dev   │
                                                          └────────────────────────┘
```

---

## What is "the graph"?

LangGraph models your logic as a **graph**: a set of **nodes** (steps) connected
by **edges** (arrows showing what runs next). Every graph has a special `START`
and `END`.

Our graph is intentionally tiny — **one node**:

```
START  ──►  chatbot  ──►  END
```

- **START** → the entry point. The user's message comes in here.
- **chatbot** → the one step that does the work: it sends the conversation to
  Claude and gets a reply.
- **END** → the graph is done; the final result is returned to the caller.

You can add more nodes later (e.g. "fetch data" → "summarize" → "translate") and
LangGraph will run them in the order the edges define.

---

## What is "state"?

As the graph runs, it carries a **state** object — a shared bag of data that each
node can read and update. In our project the state is just a list of **messages**:

```python
class State(TypedDict):
    messages: Annotated[list, add_messages]
```

- Each request starts the state with the user's message.
- The `chatbot` node adds Claude's reply to the list.
- The final state (user message + AI reply) is what you get back.

`add_messages` is a helper that makes sure new messages get **appended** to the
list rather than overwriting it.

---

## Step-by-step: what happens on one request

1. **Request arrives.** A client sends `POST /runs/wait` to the LangGraph server
   on port `8123`, with a user message in the body.
2. **Graph starts.** LangGraph creates the initial `state` containing that
   message and moves from `START` to the `chatbot` node.
3. **chatbot node runs.** It calls `llm.invoke(state["messages"])`, which sends
   the conversation to the **Claude API** (Anthropic) over the internet.
4. **Claude replies.** The model returns a generated answer.
5. **State updates.** The reply is appended to `state["messages"]`.
6. **Graph ends.** Execution reaches `END`. The full message list is returned to
   the client as JSON.
7. **Trace is logged.** In parallel, the entire run (inputs, the Claude call,
   outputs, timing, token cost) is sent to **LangSmith** under the project
   `Ai-Poc-Dev`, where you can open and inspect it.

> `/runs/wait` means "run the graph and wait for the final answer" (synchronous).
> There are also streaming and async endpoints — see the API docs at
> `http://<server-ip>:8123/docs`.

---

## The code that defines all of this

It all lives in **`agent.py`** (about 25 lines):

```python
from typing import Annotated, TypedDict
from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages
from langchain_anthropic import ChatAnthropic

# 1. The shared state: a growing list of messages
class State(TypedDict):
    messages: Annotated[list, add_messages]

# 2. The AI model we call
llm = ChatAnthropic(model="claude-sonnet-4-6")

# 3. The one node: send messages to Claude, return the reply
def chatbot(state: State):
    return {"messages": [llm.invoke(state["messages"])]}

# 4. Wire the graph: START -> chatbot -> END
builder = StateGraph(State)
builder.add_node("chatbot", chatbot)
builder.add_edge(START, "chatbot")
builder.add_edge("chatbot", END)

# 5. Compile it. The server looks for this `graph` variable.
graph = builder.compile()
```

And **`langgraph.json`** tells the server where to find the graph:

```json
{
  "dependencies": ["."],
  "graphs": { "agent": "./agent.py:graph" },
  "env": ".env"
}
```

- `"agent": "./agent.py:graph"` → the graph named **`agent`** is the `graph`
  variable inside `agent.py`. That name `agent` is the `assistant_id` you pass
  in API requests.
- `"env": ".env"` → load secrets/config from the `.env` file.

---

## Where the secrets live

Nothing secret is in the code or in Git. All keys live in a **`.env`** file that
exists **only on the server** (it's listed in `.gitignore` so it's never pushed):

```bash
ANTHROPIC_API_KEY=...      # lets us call Claude
LANGCHAIN_API_KEY=...      # lets us send traces to LangSmith
LANGSMITH_API_KEY=...      # licenses the self-hosted LangGraph server
LANGCHAIN_PROJECT=Ai-Poc-Dev   # which LangSmith project the traces go to
LANGCHAIN_TRACING_V2=true  # turn tracing on
```

---

## Next

- **Deploy your own copy:** [`03-deployment-guide.md`](03-deployment-guide.md)
- **Call the running server:** [`04-access-and-usage.md`](04-access-and-usage.md)
