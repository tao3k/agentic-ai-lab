# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Explicit semantic comparison pairs; names alone never imply equivalence."""

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class ComparisonSpec:
    label: str
    native_case: str
    agentic_ai_lab_case: str


COMPARISONS = (
    ComparisonSpec("LangChain branch/tool route", "langchain-branch-tool-native", "agentic-ai-lab-executor-router-agent"),
    ComparisonSpec("LangGraph router", "langgraph-router-agent-native", "agentic-ai-lab-executor-router-agent"),
    ComparisonSpec("LangGraph handoff/reducer", "langgraph-handoff-reducer-native", "agentic-ai-lab-executor-handoff-reducer"),
    ComparisonSpec("LangGraph interrupt/resume", "langgraph-interrupt-resume-native", "agentic-ai-lab-executor-interrupt-resume"),
    ComparisonSpec("LangGraph long graph", "langgraph-long-graph-native", "agentic-ai-lab-executor-long-graph"),
    ComparisonSpec("LangGraph stream/events", "langgraph-router-stream-native", "agentic-ai-lab-executor-router-stream-events"),
    ComparisonSpec("CrewAI sequential crew", "crewai-sequential-crew-native", "agentic-ai-lab-executor-crewai-sequential"),
)
