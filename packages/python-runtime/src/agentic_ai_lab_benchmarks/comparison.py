# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Explicit semantic comparison pairs; names alone never imply equivalence."""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class ComparisonSpec:
    label: str
    runtime_case: str
    agentic_ai_lab_case: str


COMPARISONS = (
    ComparisonSpec("LangChain branch/tool route", "langchain-branch-tool-runtime", "agentic-ai-lab-executor-router-agent"),
    ComparisonSpec("LangGraph router", "langgraph-router-agent-runtime", "agentic-ai-lab-executor-router-agent"),
    ComparisonSpec("LangGraph handoff/reducer", "langgraph-handoff-reducer-runtime", "agentic-ai-lab-executor-handoff-reducer"),
    ComparisonSpec("LangGraph interrupt/resume", "langgraph-interrupt-resume-runtime", "agentic-ai-lab-executor-interrupt-resume"),
    ComparisonSpec("LangGraph long graph", "langgraph-long-graph-runtime", "agentic-ai-lab-executor-long-graph"),
    ComparisonSpec("LangGraph stream/events", "langgraph-router-stream-runtime", "agentic-ai-lab-executor-router-stream-events"),
    ComparisonSpec("CrewAI sequential crew", "crewai-sequential-crew-runtime", "agentic-ai-lab-executor-crewai-sequential"),
)
