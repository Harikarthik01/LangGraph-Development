# 4 — Integrating Agents into Mobile & Web Apps

> How to consume the deployed LangGraph agents from your own mobile and web applications — **securely**. We build agents on this platform, then use them from other apps.

---

## §1 — The golden rule: never expose the API key

**❌ NEVER put the `X-Api-Key` in a mobile or web app.**

- In a **mobile app**, the key can be extracted from the app binary.
- In a **web app**, it's visible in the browser's Network/Sources tab.

Once leaked, anyone can spend your Claude credits.

**✅ The key must live only on a server you control** — your backend — which adds it when forwarding requests to the LangGraph server.

---

## §2 — The correct architecture

```
Mobile / Web app         Your backend             LangGraph server
(NO key)                 (holds the key)          langgraph.sudoxp.com
   |                          |                          |
   |  POST /api/chat -------> |  adds X-Api-Key          |
   |  { message, threadId }   |  POST /threads/{id}/runs --> runs agent
   |                          | <-------- reply --------- |
   | <------- reply --------- |                          |
```

| Layer | Responsibility |
|---|---|
| **Client app** (mobile/web) | UI only. Talks to **your backend**, never LangGraph directly. Holds **no** key. |
| **Your backend** (proxy) | Holds the API key (env var). Adds `X-Api-Key`, forwards to LangGraph, returns the reply. Add your own user auth here. |
| **LangGraph server** | Runs the agent. Only accepts requests with the valid key. |

> **Bonus:** the backend is where you add your app's **user login**, rate limiting, and logging — and you can hide the LangGraph details from clients entirely.

---

## §3 — Build a backend proxy

The key comes from a **server env var** — never hard-coded, never sent to the client.

### Node.js (Express)

```js
// server.js — runs on YOUR backend
import express from "express";
const app = express();
app.use(express.json());

const LG_URL = "https://langgraph.sudoxp.com";
const LG_KEY = process.env.LANGGRAPH_API_KEY;   // server env var, never in the app

app.post("/api/chat", async (req, res) => {
  // (optional) verify YOUR app's user auth here first
  const { message, threadId } = req.body;

  let tid = threadId;
  if (!tid) {
    const t = await fetch(`${LG_URL}/threads`, {
      method: "POST",
      headers: { "X-Api-Key": LG_KEY, "Content-Type": "application/json" },
      body: "{}",
    }).then(r => r.json());
    tid = t.thread_id;
  }

  const out = await fetch(`${LG_URL}/threads/${tid}/runs/wait`, {
    method: "POST",
    headers: { "X-Api-Key": LG_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({
      assistant_id: "agent",
      input: { messages: [{ role: "user", content: message }] },
    }),
  }).then(r => r.json());

  res.json({ threadId: tid, reply: out.messages.at(-1).content });
});

app.listen(3000);
```

### Python (FastAPI)

```python
import os, requests
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()
LG_URL = "https://langgraph.sudoxp.com"
LG_KEY = os.environ["LANGGRAPH_API_KEY"]        # server env var
H = {"X-Api-Key": LG_KEY, "Content-Type": "application/json"}

class ChatIn(BaseModel):
    message: str
    threadId: str | None = None

@app.post("/api/chat")
def chat(body: ChatIn):
    tid = body.threadId
    if not tid:
        tid = requests.post(f"{LG_URL}/threads", headers=H, json={}).json()["thread_id"]
    out = requests.post(f"{LG_URL}/threads/{tid}/runs/wait", headers=H, json={
        "assistant_id": "agent",
        "input": {"messages": [{"role": "user", "content": body.message}]},
    }).json()
    return {"threadId": tid, "reply": out["messages"][-1]["content"]}
```

---

## §4 — Web app (React)

The app calls **your backend** (`/api/chat`) — not LangGraph. No key in the frontend.

```js
async function sendMessage(message, threadId) {
  const res = await fetch("https://your-backend.com/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message, threadId }),
  });
  return res.json();   // { threadId, reply } — save threadId for the next message
}
```

CORS: since the app calls *your* backend, you control CORS there — no dependency on the LangGraph server's CORS.

---

## §5 — Mobile app

Same idea — the app calls **your backend**, never LangGraph directly.

### React Native
```js
const res = await fetch("https://your-backend.com/api/chat", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ message, threadId }),
});
const { threadId: tid, reply } = await res.json();
// store `tid` (AsyncStorage) to continue the conversation
```

### Flutter (Dart)
```dart
final res = await http.post(
  Uri.parse("https://your-backend.com/api/chat"),
  headers: {"Content-Type": "application/json"},
  body: jsonEncode({"message": message, "threadId": threadId}),
);
final data = jsonDecode(res.body);   // { threadId, reply }
```

Native iOS/Android follow the same pattern — a standard HTTPS POST to your backend. The mobile app never knows the LangGraph URL or key.

---

## §6 — Conversation memory (threads)

Reuse the `threadId` to keep context:

| Step | What happens |
|---|---|
| First message | Client sends no `threadId` → backend creates one → returns it |
| Client stores it | Save `threadId` (localStorage / AsyncStorage / DB) |
| Next messages | Client sends the same `threadId` → agent remembers the conversation (Postgres) |
| New conversation | Drop the `threadId` → backend makes a fresh thread |

---

## §7 — Streaming responses (typing effect)

Your backend calls `/runs/stream` and pipes the server-sent events to the client:

```js
app.post("/api/chat/stream", async (req, res) => {
  const upstream = await fetch(`${LG_URL}/threads/${req.body.threadId}/runs/stream`, {
    method: "POST",
    headers: { "X-Api-Key": LG_KEY, "Content-Type": "application/json" },
    body: JSON.stringify({
      assistant_id: "agent",
      stream_mode: "messages",
      input: { messages: [{ role: "user", content: req.body.message }] },
    }),
  });
  res.setHeader("Content-Type", "text/event-stream");
  upstream.body.pipe(res);   // forward the token stream
});
```

The client reads the stream (EventSource / fetch reader) and appends tokens as they arrive — ChatGPT-style live typing.

---

## §8 — Integration checklist

- [ ] Client apps call **your backend**, never LangGraph directly
- [ ] The `X-Api-Key` lives **only** on your backend (env var), never in app code
- [ ] Your backend adds its own **user authentication**
- [ ] Persist `threadId` per user/conversation for memory
- [ ] Add rate limiting on your backend (protect Claude usage)
- [ ] Use HTTPS everywhere (client → backend → LangGraph)
