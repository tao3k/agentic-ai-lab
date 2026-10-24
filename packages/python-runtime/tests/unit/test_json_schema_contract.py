# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
#
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

from __future__ import annotations

import io
import json

from agentic_ai_lab_runtime.json_schema_contract import (
    json_schema_to_scheme_contract,
    main,
)


def _stage_schema() -> dict[str, object]:
    return {
        "type": "object",
        "required": ["jobs"],
        "properties": {
            "jobs": {
                "type": "object",
                "patternProperties": {
                    "^[_a-zA-Z][a-zA-Z0-9_-]*$": {
                        "type": "object",
                        "required": ["runs-on"],
                        "properties": {
                            "runs-on": {"type": "string", "minLength": 1},
                        },
                    }
                },
                "additionalProperties": False,
            }
        },
    }


def test_json_schema_to_scheme_contract_projects_map_value_schema() -> None:
    source = json_schema_to_scheme_contract(
        _stage_schema(),
        name="custom-stage",
        source_ref="schemas/json/custom-stage.json",
        object_kind="AgenticAILabCustomStage",
        object_key="funflow/custom-stage",
    )

    assert "(import (only-in :yuanxu/modules/json-schema/interface" in source
    assert "(export custom-stage-schema" in source
    assert '("type" . "object")' in source
    assert '("patternProperties" .' in source
    assert '(object-key . funflow/custom-stage)' in source


def test_jsonschema_contract_cli_writes_scheme_source(tmp_path) -> None:
    schema = tmp_path / "stage.schema.json"
    output = tmp_path / "stage-contract.ss"
    schema.write_text(json.dumps(_stage_schema()), encoding="utf-8")

    exit_code = main(
        [
            str(schema),
            "--name",
            "stage-ci",
            "--object-key",
            "funflow/stage-ci",
            "--output",
            str(output),
        ],
        stdout=io.StringIO(),
    )

    assert exit_code == 0
    generated = output.read_text(encoding="utf-8")
    assert "(def stage-ci-contract-artifact" in generated
    assert '(object-key . funflow/stage-ci)' in generated
