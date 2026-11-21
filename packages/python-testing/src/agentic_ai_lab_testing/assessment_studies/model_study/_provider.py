# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Provider for the model study study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
import json
import time
import http.client
from ._config import PROVIDER_IDLE_SECONDS


def response_outcome(response, correct=None):
    """Classify observable completion separately from answer correctness."""
    if response.get("error") is not None:
        return "transport_error"
    terminal = response.get("terminal") or {}
    if terminal.get("error") is not None or terminal.get("status") == "failed":
        return "provider_failure"
    if terminal.get("status") == "incomplete":
        details = terminal.get("incomplete_details") or {}
        return (
            "output_budget_exhausted"
            if details.get("reason") == "max_output_tokens"
            else "incomplete"
        )
    if terminal.get("status") != "completed":
        return "missing_terminal"
    if correct is None:
        return "completed_ungraded"
    return "correct" if correct else "answer_mismatch"


def request_for(plan, preview, item, initial):
    source = (preview / f"{item['case']}.input.ss").read_text()
    inputs = [{"role": "user", "content": source}]
    if item["arm"] in ("transfer-history", "transfer-feedback"):
        previous = initial[item["family"]]
        inputs = [
            {
                "role": "user",
                "content": (preview / f"{item['family']}-initial.input.ss").read_text(),
            }
        ]
        if previous["raw"]:
            inputs.append({"role": "assistant", "content": previous["raw"]})
        feedback = (
            json.dumps(previous["nativeObservation"], sort_keys=True) + "\n"
            if item["arm"] == "transfer-feedback"
            else ""
        )
        inputs.append(
            {
                "role": "user",
                "content": feedback + (preview / f"{item['case']}.task.ss").read_text(),
            }
        )
    if len(json.dumps(inputs, ensure_ascii=False).encode()) > plan["maxInputBytes"]:
        raise ValueError("serialized input exceeds frozen byte ceiling before call")
    return {
        "model": plan["model"],
        "input": inputs,
        "reasoning": {"effort": item["reasoningEffort"]},
        "max_output_tokens": plan["maxOutputTokens"],
        "stream": True,
        "store": False,
    }


def provider(request, api_key, destination):
    started = time.monotonic()
    raw = ""
    terminal = None
    reason_events = 0
    first_text = None
    packet = json.dumps(request, ensure_ascii=False).encode()
    response_error = None
    connection = http.client.HTTPSConnection(
        "api.deepseek.com", timeout=PROVIDER_IDLE_SECONDS
    )
    try:
        connection.connect()
        wire = connection.sock
        wire.settimeout(PROVIDER_IDLE_SECONDS)
        connection.request(
            "POST",
            "/responses",
            body=packet,
            headers={
                "Content-Type": "application/json",
                "Authorization": "Bearer " + api_key,
            },
        )
        response = connection.getresponse()
        if response.status != 200:
            detail = (
                response.read(8192)
                .decode("utf-8", errors="replace")
                .replace(api_key, "[redacted]")
            )
            raise RuntimeError(f"provider HTTP status {response.status}: {detail}")
        last_progress = time.monotonic()
        with destination.with_suffix(".events.jsonl").open("x") as events:
            while True:
                remaining = PROVIDER_IDLE_SECONDS - (time.monotonic() - last_progress)
                if remaining <= 0:
                    raise TimeoutError(
                        "provider made no observable progress before idle deadline"
                    )
                wire.settimeout(remaining)
                line = response.readline()
                if time.monotonic() - last_progress > PROVIDER_IDLE_SECONDS:
                    raise TimeoutError(
                        "provider made no observable progress before idle deadline"
                    )
                if not line:
                    break
                if not line.startswith(b"data: "):
                    continue
                event = json.loads(line[6:])
                events.write(json.dumps(event, ensure_ascii=False) + "\n")
                events.flush()
                kind = event.get("type", "")
                if kind.startswith(
                    (
                        "response.output_text.",
                        "response.reasoning",
                        "response.function_call_arguments.",
                    )
                ) or kind in {
                    "response.created",
                    "response.in_progress",
                    "response.output_item.added",
                    "response.output_item.done",
                    "response.content_part.added",
                    "response.content_part.done",
                    "response.completed",
                    "response.incomplete",
                    "response.failed",
                }:
                    last_progress = time.monotonic()
                if kind == "response.output_text.delta":
                    raw += event["delta"]
                    first_text = first_text or time.monotonic() - started
                    report_text(".", end="", flush=True)
                elif kind.startswith("response.reasoning"):
                    reason_events += 1
                    report_text("r", end="", flush=True)
                else:
                    report_text(f"[{kind}]", end="", flush=True)
                if kind in (
                    "response.completed",
                    "response.incomplete",
                    "response.failed",
                ):
                    terminal = event["response"]
                    break
            if terminal is None:
                raise RuntimeError("provider omitted terminal response")
    except Exception as failure:
        response_error = {
            "type": type(failure).__name__,
            "message": str(failure).replace(api_key, "[redacted]")[:2048],
        }
    finally:
        connection.close()
    metadata = {
        "terminal": terminal,
        "error": response_error,
        "reasoningEvents": reason_events,
        "providerSeconds": time.monotonic() - started,
        "firstVisibleTextSeconds": first_text,
        "progressIdleSeconds": PROVIDER_IDLE_SECONDS,
        "absoluteWallDeadlineSeconds": None,
    }
    destination.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    return raw, metadata
