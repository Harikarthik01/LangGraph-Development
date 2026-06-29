"""LangGraph agent backed by Claude (Anthropic)."""
from typing import Annotated, TypedDict

from langgraph.graph import StateGraph, START, END
from langgraph.graph.message import add_messages
from langchain_anthropic import ChatAnthropic


class State(TypedDict):
    messages: Annotated[list, add_messages]


# Sonnet 4.6 — strong balance of quality and cost for dev.
llm = ChatAnthropic(model="claude-sonnet-4-6")


def chatbot(state: State):
    # Sends the running conversation to Claude and appends the reply to state.
    return {"messages": [llm.invoke(state["messages"])]}


builder = StateGraph(State)
builder.add_node("chatbot", chatbot)
builder.add_edge(START, "chatbot")
builder.add_edge("chatbot", END)

# The server imports this `graph` symbol (see langgraph.json)
graph = builder.compile()
