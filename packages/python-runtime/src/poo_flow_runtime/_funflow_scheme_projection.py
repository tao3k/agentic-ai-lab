# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Load Scheme-produced FunFlow plan projections into the Python runtime."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any

from ._funflow_types import (
    FunFlowDag,
    FunFlowPlanProjection,
    FunFlowRuntimeError,
    FunFlowSandbox,
    FunFlowStep,
    FunFlowStepAction,
)

SchemeRows = Mapping[str, Any] | Sequence[tuple[Any, Any] | Sequence[Any]]


def funflow_projection_from_scheme_plan(
    plan: SchemeRows,
    actions: Mapping[str, FunFlowStepAction],
    sandboxes: Mapping[str, FunFlowSandbox] | None = None,
) -> FunFlowPlanProjection:
    rows = _rows(plan)
    schema = _text(_required(rows, "schema"))
    wrapper_origin = rows.get("origin", "use-module-funflow")
    wrapper_source_map = rows.get("source-map")
    if schema == "yuanxu.funflow-plan-projection.v1":
        rows = _rows(_required(rows, "plan"))
        schema = _text(_required(rows, "schema"))
    if schema != "yuanxu.modules.funflow.plan.v1":
        raise FunFlowRuntimeError(f"unsupported FunFlow Scheme plan schema: {schema}")
    runtime_contract = _text(_required(rows, "runtime-contract"))
    if runtime_contract != "yuanxu.anyio.v1":
        raise FunFlowRuntimeError(
            "FunFlow Scheme plan requires runtime contract 'yuanxu.anyio.v1'"
        )

    name = _text(_required(rows, "name"))
    node_names = tuple(_node_name(node) for node in _sequence(rows.get("node-table", ())))
    edge_rows = tuple(_rows(edge) for edge in _sequence(rows.get("edge-table", ())))
    needs_by_node = {node: [] for node in node_names}
    for edge in edge_rows:
        source = _text(_required(edge, "from"))
        target = _text(_required(edge, "to"))
        if target not in needs_by_node:
            raise FunFlowRuntimeError(
                f"FunFlow Scheme plan edge targets unknown node: {target}"
            )
        needs_by_node[target].append(source)

    sandboxes = sandboxes or {}
    steps = tuple(
        FunFlowStep(
            name=node,
            action=_required_action(actions, node),
            needs=tuple(needs_by_node[node]),
            sandbox=sandboxes.get(node, FunFlowSandbox(node)),
        )
        for node in node_names
    )
    return FunFlowPlanProjection(
        dag=FunFlowDag(name=name, steps=steps),
        origin=_origin(rows.get("origin", wrapper_origin)),
        runtime_contract=runtime_contract,
        source_map=_source_map(rows.get("source-map", wrapper_source_map or ())),
    )


def _rows(value: Any) -> dict[str, Any]:
    if isinstance(value, Mapping):
        return {_text(key): row_value for key, row_value in value.items()}
    rows: dict[str, Any] = {}
    for row in value:
        if not isinstance(row, (tuple, list)) or len(row) == 0:
            raise FunFlowRuntimeError(f"invalid Scheme row: {row!r}")
        key = _text(row[0])
        if len(row) == 1:
            rows[key] = ()
        elif len(row) == 2:
            rows[key] = row[1]
        else:
            rows[key] = tuple(row[1:])
    return rows


def _sequence(value: Any) -> tuple[Any, ...]:
    if value is None:
        return ()
    if isinstance(value, tuple):
        return value
    if isinstance(value, list):
        return tuple(value)
    raise FunFlowRuntimeError(f"expected Scheme sequence, got: {value!r}")


def _required(rows: Mapping[str, Any], key: str) -> Any:
    try:
        return rows[key]
    except KeyError as exc:
        raise FunFlowRuntimeError(f"FunFlow Scheme plan missing field: {key}") from exc


def _required_action(
    actions: Mapping[str, FunFlowStepAction], node: str
) -> FunFlowStepAction:
    try:
        return actions[node]
    except KeyError as exc:
        raise FunFlowRuntimeError(
            f"FunFlow Scheme plan missing Python action binding: {node}"
        ) from exc


def _node_name(node: Any) -> str:
    rows = _rows(node)
    return _text(_required(rows, "name"))


def _source_map(value: Any) -> dict[str, str]:
    source_map: dict[str, str] = {}
    for row in _sequence(value):
        rows = _rows(row)
        stage = rows.get("stage")
        path = rows.get("path")
        if stage is not None and path is not None:
            source_map[_text(stage)] = _path_text(path)
    return source_map


def _origin(value: Any) -> str:
    origin = _text(value)
    if origin == "use-module-funflow":
        return "use-module funflow"
    if origin == "user-composition-funflow":
        return "user-composition funflow"
    return origin


def _path_text(value: Any) -> str:
    if isinstance(value, (tuple, list)):
        return "/".join(_text(item) for item in value)
    return _text(value)


def _text(value: Any) -> str:
    if isinstance(value, str):
        return value
    return str(value)


__all__ = ["funflow_projection_from_scheme_plan"]
