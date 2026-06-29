# 01 — Overview: What is this project?

> **Audience:** anyone — even if you've never heard of LangGraph or LangChain.
> Read this first. It explains *what* we built and *why*, in plain language.

---

## What we built

A small web service that runs an **AI agent**. You send it a message over HTTP,
it asks an AI model (Claude) for a reply, and sends the reply back. It runs on a
cheap cloud server (AWS Lightsail) and every request is recorded so we can debug
it (LangSmith).

In one sentence: **a chatbot API, self-hosted on a tiny AWS server, with full
visibility into every call.**

---

## The jargon, explained simply

You'll see these names everywhere. Here's what each one actually is:

| Name | What it really is | A simple analogy |
|---|---|---|
| **LangChain** | A Python toolkit for talking to AI models (Claude, GPT, etc.) with one common interface. | A universal remote that works with any TV brand. |
| **LangGraph** | Built on top of LangChain. It lets you design an AI workflow as a **graph** — boxes (steps) connected by arrows. It also gives you a ready-made **server** to run that graph as an API. | A flowchart that you can actually *run*. |
| **LangGraph Server** | The web server (the thing listening on a port) that runs your graph and answers HTTP requests. | The waiter that takes your order and brings food from the kitchen. |
| **LangSmith** | A website (smith.langchain.com) that records every run of your graph so you can see what happened — inputs, outputs, errors, timing, cost. | A security camera + receipt printer for your AI calls. |
| **Claude (Anthropic)** | The actual AI model that generates the replies. We use `claude-sonnet-4-6`. | The brain doing the thinking. |
| **AWS Lightsail** | A simple, cheap cloud server (a computer in a data center) that hosts everything. | The rented room where your service lives. |

---

## How the pieces fit together (the short version)

```
You  ──HTTP request──►  LangGraph Server  ──►  Claude (Anthropic)
                          (on Lightsail)         returns an answer
                              │
                              └──reports the run──►  LangSmith (a website)
```

1. **You** send a message.
2. **LangGraph** runs the workflow (our workflow is just one step: "ask Claude").
3. **Claude** generates the reply.
4. LangGraph sends the reply back to you.
5. In the background, the whole run is logged to **LangSmith** so we can inspect it.

> A deeper version of this flow is in [`02-architecture-flow.md`](02-architecture-flow.md).

---

## What each tool costs us

| Thing | Cost | Notes |
|---|---|---|
| **LangGraph** | Free | Self-hosted "lite" mode, free up to 1M steps/year. |
| **LangSmith** | Free | Developer tier, 5,000 traces/month free. |
| **AWS Lightsail** | $7/month | **Free for the first 90 days.** 1 GB RAM instance. |
| **Claude (Anthropic)** | Pay per use | ~cents for dev. You only pay for messages you send. |
| **Static IP / firewall** | Free | Free while attached to a running instance. |

**Bottom line for dev: roughly $0 for the first 3 months, then ~$7/month + a few
cents of Claude usage.**

---

## Why self-host instead of using a hosted service?

- It's a **proof-of-concept (PoC) / development** environment — we want full
  control and to keep it cheap.
- Self-hosting on Lightsail is the cheapest way to have a real, always-on URL.
- LangSmith stays on the free cloud tier because self-hosting *it* would need an
  expensive Enterprise license and a much bigger server — not worth it for dev.

---

## Where to go next

- **Want to understand how it works internally?** → [`02-architecture-flow.md`](02-architecture-flow.md)
- **Want to deploy a fresh copy yourself?** → [`03-deployment-guide.md`](03-deployment-guide.md)
- **Want to use the server we already deployed?** → [`04-access-and-usage.md`](04-access-and-usage.md)
- **Need to keep it running / troubleshoot?** → [`05-operations.md`](05-operations.md)
