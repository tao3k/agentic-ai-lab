# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Checkpoint transport inputs and explicit child-process JSON wire boundary."""
from importlib.resources import files
import json
import sys

from agentic_ai_lab_runtime.reasoning import ReasoningRuntime, ClueExchange

PROJECTION = """
(define-program (project)
 (sources clue factor link) (outputs clue factor link)
 (relation clue (id digest claim polarity role source))
 (relation factor (id digest name value))
 (relation link (claim target label id digest)))
(define-program (select)
 (sources clue factor binding) (outputs question)
 (relation clue (id digest claim polarity role source))
 (relation factor (id digest name value))
 (relation binding (name value))
 (relation question (claim))
 ((question C) <-- (clue I D C _ _ _) (factor I D N V) (binding N V)))
"""


def exchange(extra=None):
    engine = ReasoningRuntime()
    facts = {"clue": [["known", "sha", "gc-claim", "support", "observation", "receipt"]],
             "factor": [["known", "sha", "topic", "gc"]], "link": []}
    if extra is not None:
        facts["clue"].append(["additional", "sha", "elsewhere" if extra == "unrelated" else "gc-claim",
                              "counter", "observation", "receipt"])
    return engine, ClueExchange(engine, [PROJECTION], "project", facts, {"receipt": "sha"})


def write_reply(value):
    """Child-process fixture wire output, not library diagnostic logging."""
    json.dump(value, sys.stdout)
    sys.stdout.write("\n")


def resume_fixture():
    request = json.load(sys.stdin)
    engine, owner = exchange(request.pop("extra", None))
    try:
        write_reply(owner.slice(request))
    finally:
        owner.close()


TRACE_PROJECTION = """
(define-program (project-trace)
 (sources requirement contract receipt completed_outcome verified quiescent
   support_declaration support_witness required_command required_binding binding
   current_binding command command_observation checkpoint_claim checkpoint_source
   checkpoint_receipt_source)
 (outputs clue factor link)
 (include evidence-checkpoint-exchange-fragment)
 (relation clue (id digest claim polarity role source))
 (relation factor (id digest name value))
 (relation link (claim target label id digest))
 ((clue I H C P (lit "observation") S) <--
   (checkpoint_observation I H C P S _ _ _ _))
 ((factor I H (lit "requirement") R) <--
   (checkpoint_observation I H _ _ _ R _ _ _))
 ((factor I H (lit "state") State) <--
   (checkpoint_observation I H _ _ _ _ _ State _)))
"""


def trace_packet(request):
    engine = ReasoningRuntime()
    source = files("agentic_ai_lab_runtime").joinpath("reasoning_rules/checkpoint_rules.ss").read_text()
    owner = ClueExchange(engine, [source, TRACE_PROJECTION, PROJECTION],
                         "project-trace", request["facts"], {"dsl": "d", "report": "h"})
    try:
        fields = {"bindings": [["requirement", "test"]]}
        if "checkpoint" in request:
            fields["checkpoint"] = request["checkpoint"]
        return owner.slice_selected([PROJECTION], "select", fields)
    finally:
        owner.close()


def resume_trace_fixture():
    write_reply(trace_packet(json.load(sys.stdin)))


def resume_progress_fixture():
    engine = ReasoningRuntime()
    source = files("agentic_ai_lab_runtime").joinpath("reasoning_rules/checkpoint_rules.ss").read_text()
    session = engine.rules(source, "make-evidence-checkpoint", trusted=True)
    try:
        session.replace(json.load(sys.stdin))
        result = session.run()
        handle = session.result(result)
        try:
            write_reply(result["relations"])
        finally:
            handle.close()
    finally:
        session.close()
