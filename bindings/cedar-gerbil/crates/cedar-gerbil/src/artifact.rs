// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! A validated Lean/Cedar candidate can only constrain a Gerbil POO-owned
//! authority snapshot; it cannot construct one or publish policy inputs.

use cedar_poo_bridge::{ValidatedManifest, render_validated_policy_sources};
use agentic_ai_lab_cedar_authority::projection::Bootstrap;
use agentic_ai_lab_cedar_authority::{Error, Result};
use serde_json::Value;
use std::collections::BTreeMap;

pub(crate) fn ensure_matches_poo_snapshot(
    snapshot: &Bootstrap,
    manifest: &ValidatedManifest,
    case_name: &str,
) -> Result<()> {
    let sources = render_validated_policy_sources(manifest, case_name)
        .map_err(|detail| Error::new("cedar-artifact-invalid", detail))?;
    let case = manifest
        .cases
        .iter()
        .find(|case| case.name == case_name)
        .ok_or_else(|| Error::new("cedar-artifact-invalid", "selected case is missing"))?;
    let schema: Value = serde_json::from_str(&snapshot.schema_json)
        .map_err(|error| Error::new("cedar-artifact-invalid", error.to_string()))?;
    let entities: Value = serde_json::from_str(&snapshot.entities_json)
        .map_err(|error| Error::new("cedar-artifact-invalid", error.to_string()))?;
    if schema != manifest.schema || entities != case.entities {
        return Err(Error::new(
            "cedar-artifact-mismatch",
            "POO snapshot schema or entities differ from the Lean artifact",
        ));
    }
    let mut projected = BTreeMap::new();
    for policy in &snapshot.policies {
        if projected
            .insert(policy.identity.clone(), policy.source.clone())
            .is_some()
        {
            return Err(Error::new(
                "cedar-artifact-mismatch",
                "POO snapshot repeats a policy identity",
            ));
        }
    }
    if projected != sources {
        return Err(Error::new(
            "cedar-artifact-mismatch",
            "POO snapshot policy identities or bodies differ from the Lean artifact",
        ));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn only_accepts_the_poo_snapshot_matching_the_validated_case() {
        let manifest: ValidatedManifest = serde_json::from_value(json!({
            "schema": {"": {
                "entityTypes": {
                    "User": {"shape": {"type": "Record", "attributes": {}}},
                    "Document": {"shape": {"type": "Record", "attributes": {}}}
                },
                "actions": {"view": {"appliesTo": {
                    "principalTypes": ["User"], "resourceTypes": ["Document"],
                    "context": {"type": "Record", "attributes": {}}
                }}}
            }},
            "cases": [{
                "name": "view", "revision": "Published", "policy_ids": ["view-permit"],
                "policies": {"staticPolicies": {"view-permit": {
                    "effect": "permit",
                    "principal": {"op": "All"}, "action": {"op": "All"},
                    "resource": {"op": "All"}, "conditions": []
                }}, "templates": {}, "templateLinks": []},
                "entities": [],
                "request": {"principal": "User::\"alice\"",
                    "action": "Action::\"view\"",
                    "resource": "Document::\"one\"", "context": {}},
                "expected": "allow", "expected_reasons": ["view-permit"],
                "expected_error_policies": []
            }]
        }))
        .unwrap();
        let sources = render_validated_policy_sources(&manifest, "view").unwrap();
        let mut snapshot: Bootstrap = serde_json::from_value(json!({
            "schema_id": "agentic-ai-lab.cedar.bootstrap.v1",
            "producer": "gerbil-poo",
            "source": "poo-composition",
            "object_kind": "cedar-authority",
            "provenance": {
                "composition_identity": "composed-view",
                "profile_identities": [],
                "profile_origin_digest": "origin",
                "governance_assessment_digest": "assessment",
                "subject_snapshot_digest": "subject",
                "governance_admitted": true,
                "certification_names": []
            },
            "authority_id": "view-authority",
            "runtime_context_id": "runtime",
            "runtime_generation": 1,
            "bundle_epoch": 1,
            "runtime_bundle_digest": "runtime-bundle",
            "profile_bundle_digest": "profile-bundle",
            "independent_bundle_digest": "independent-bundle",
            "capability_contract_digest": "capability-contract",
            "policy_revision": 1,
            "revocation_epoch": 0,
            "schema_json": manifest.schema.to_string(),
            "policies": [{"identity": "view-permit", "source": sources["view-permit"]}],
            "entities_json": "[]",
            "capabilities": []
        }))
        .unwrap();
        ensure_matches_poo_snapshot(&snapshot, &manifest, "view").unwrap();

        snapshot.policies[0].source.push_str(" // changed");
        assert!(ensure_matches_poo_snapshot(&snapshot, &manifest, "view").is_err());
        snapshot.policies[0].source = sources["view-permit"].clone();
        snapshot.entities_json = "[{}]".into();
        assert!(ensure_matches_poo_snapshot(&snapshot, &manifest, "view").is_err());
    }
}
