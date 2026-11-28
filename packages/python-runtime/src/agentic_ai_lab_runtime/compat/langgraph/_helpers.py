# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Shared helpers for the LangGraph compatibility facade."""

from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Annotated, Any, get_args, get_origin, get_type_hints

START = "__start__"
END = "__end__"


def endpoint(value: str) -> str:
    if value == "START":
        return START
    if value == "END":
        return END
    return value


def node_name(action: Any) -> str:
    return str(getattr(action, "__name__", action.__class__.__name__))


def route_map(
    path_map: Mapping[str, str] | Sequence[str] | None,
) -> Mapping[str, str] | None:
    if path_map is None:
        return None
    if isinstance(path_map, Mapping):
        return {key: endpoint(value) for key, value in path_map.items()}
    return {value: endpoint(value) for value in path_map}


def schema_reducers(state_schema: object | None) -> dict[str, Any]:
    if state_schema is None:
        return {}
    try:
        hints = get_type_hints(state_schema, include_extras=True)
    except TypeError:
        return {}
    except NameError:
        return {}
    reducers: dict[str, Any] = {}
    for key, annotation in hints.items():
        reducer = annotated_reducer(annotation)
        if reducer is not None:
            reducers[key] = reducer
    return reducers


def annotated_reducer(annotation: object) -> Any | None:
    if get_origin(annotation) is not Annotated:
        return None
    for metadata in get_args(annotation)[1:]:
        if callable(metadata):
            return metadata
    return None
