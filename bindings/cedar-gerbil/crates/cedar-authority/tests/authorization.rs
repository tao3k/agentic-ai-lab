// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

mod support;

use agentic_ai_lab_cedar_authority::authority::{Authority, ConsumeRequest, verify_signature};
use agentic_ai_lab_cedar_authority::canonical;
use agentic_ai_lab_cedar_authority::projection::{
    Bootstrap, HandoffInput, PolicySource, Proposal, Snapshot,
};
use agentic_ai_lab_cedar_authority::runtime::Deployment;
use agentic_ai_lab_cedar_authority::wire::{CEDAR_VERSION, LEAN_REVISION};
use serde_json::json;
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

fn digest(byte: u8) -> String {
    format!("sha256:{}", hex::encode([byte; 32]))
}

fn bootstrap() -> Bootstrap {
    let schema = json!({"": {"entityTypes": {"User": {}, "Job": {}}, "actions": {"run": {"appliesTo": {
        "principalTypes": ["User"], "resourceTypes": ["Job"], "context": {"type": "Record", "attributes": {
            "approved": {"type": "Boolean"}, "blocked": {"type": "Boolean"}
        }}
    }}}}});
    serde_json::from_value(json!({
        "schema_id": "agentic-ai-lab.cedar-authority-snapshot.v1", "producer": "agentic-ai-lab.scheme-control",
        "source": "modules/authorization/providers/cedar/objects.ss", "object_kind": "cedar-authority-snapshot",
        "provenance": {"composition_identity": "example.composition",
            "profile_identities": ["example.profile"], "profile_origin_digest": digest(1),
            "governance_assessment_digest": digest(10), "subject_snapshot_digest": digest(11),
            "governance_admitted": true,
            "certification_names": ["AgenticAILabProof.Runtime.CedarNative", "AgenticAILabProof.Runtime.CedarRuntimeHost"]},
        "authority_id": "example.authority", "runtime_context_id": "context-1", "runtime_generation": 1, "bundle_epoch": 7,
        "runtime_bundle_digest": digest(2), "profile_bundle_digest": digest(3), "independent_bundle_digest": digest(4),
        "capability_contract_digest": digest(5), "policy_revision": 1, "revocation_epoch": 0,
        "schema_json": schema.to_string(),
        "policies": [
            {"identity": "permit-run", "source": "permit(principal == User::\"alice\", action == Action::\"run\", resource == Job::\"demo\") when { context.approved };"},
            {"identity": "forbid-blocked", "source": "forbid(principal, action, resource) when { context.blocked };"}
        ],
        "entities_json": "[]", "capabilities": [{"action": "Action::\"run\"", "event_kind": 1,
            "source_admission_required": false}]
    })).unwrap()
}

fn proposal() -> Proposal {
    Proposal {
        schema_id: "agentic-ai-lab.cedar-authorization-request.v1".into(),
        principal: "User::\"alice\"".into(),
        action: "Action::\"run\"".into(),
        resource: "Job::\"demo\"".into(),
        context: json!({"approved": true, "blocked": false}),
        intent_digest: digest(6),
        handoff: HandoffInput {
            sequence: 1,
            payload_hex: hex::encode(b"owned runtime payload"),
            semantic_root: digest(7),
            before_execution_root: digest(0),
            after_execution_root: digest(8),
            observation_digest: digest(9),
        },
    }
}

#[test]
fn one_poo_source_can_carry_an_exported_cedar_policy_set() {
    let mut input = bootstrap();
    let source = input
        .policies
        .iter()
        .map(|policy| policy.source.as_str())
        .collect::<Vec<_>>()
        .join("\n");
    input.policies = vec![PolicySource {
        identity: "generic-bundle".into(),
        source,
    }];
    Snapshot::new(input).unwrap().prepare(&proposal()).unwrap();
}

fn healthcare_bootstrap(reconciliation_observed: bool, revoked: bool) -> Bootstrap {
    let entities = json!([
        {"uid": {"type": "Healthcare::Provider", "id": "provider-1"}, "attrs": {}, "parents": []},
        {"uid": {"type": "Healthcare::Provider", "id": "provider-2"}, "attrs": {}, "parents": []},
        {"uid": {"type": "Healthcare::Patient", "id": "patient-1"}, "attrs": {}, "parents": []},
        {"uid": {"type": "Healthcare::Encounter", "id": "encounter-1"}, "attrs": {}, "parents": []},
        {"uid": {"type": "Healthcare::MedicationOrder", "id": "medication-order-1"},
         "attrs": {
             "assignedProvider": {"__entity": {"type": "Healthcare::Provider", "id": "provider-1"}},
             "patient": {"__entity": {"type": "Healthcare::Patient", "id": "patient-1"}},
             "encounter": {"__entity": {"type": "Healthcare::Encounter", "id": "encounter-1"}},
             "reconciliationObserved": reconciliation_observed,
             "revoked": revoked
         }, "parents": []}
    ]);
    serde_json::from_value(json!({
        "schema_id": "agentic-ai-lab.cedar-authority-snapshot.v1",
        "producer": "agentic-ai-lab.scheme-control",
        "source": "modules/authorization/providers/cedar/objects.ss",
        "object_kind": "cedar-authority-snapshot",
        "provenance": {
            "composition_identity": "post-operative-healing",
            "profile_identities": [
                "lambda-episteme/ontology/evidence",
                "lambda-episteme/ontology/privacy",
                "lambda-episteme/ontology/healthcare/base",
                "lambda-episteme/ontology/healthcare/healing",
                "lambda-episteme/ontology/healthcare/medication-safety"
            ],
            "profile_origin_digest": digest(1),
            "governance_assessment_digest": digest(10),
            "subject_snapshot_digest": digest(11),
            "governance_admitted": true,
            "certification_names": [
                "AgenticAILabProof.Enterprise.GovernanceThreatAssuranceClosure",
                "AgenticAILabProof.PooC4.CedarDualEngineArbitration"
            ]
        },
        "authority_id": "healthcare.authority",
        "runtime_context_id": "post-operative-runtime",
        "runtime_generation": 1,
        "bundle_epoch": 1,
        "runtime_bundle_digest": digest(2),
        "profile_bundle_digest": digest(3),
        "independent_bundle_digest": digest(4),
        "capability_contract_digest": digest(5),
        "policy_revision": 1,
        "revocation_epoch": 0,
        "schema_json": include_str!("../../../../../packages/lambda-episteme/user-interface/scenarios/healthcare/authorization/schema.json"),
        "policies": [{
            "identity": "healthcare-medication-permit",
            "source": include_str!("../../../../../packages/lambda-episteme/user-interface/scenarios/healthcare/authorization/medication-safety.cedar")
        }, {
            "identity": "healthcare-medication-revocation",
            "source": include_str!("../../../../../packages/lambda-episteme/user-interface/scenarios/healthcare/authorization/medication-revocation.cedar")
        }],
        "entities_json": entities.to_string(),
        "capabilities": [{
            "action": "Healthcare::Action::\"administerMedication\"",
            "event_kind": 4101,
            "source_admission_required": false
        }]
    }))
    .unwrap()
}

fn healthcare_proposal(provider: &str) -> Proposal {
    Proposal {
        schema_id: "agentic-ai-lab.cedar-authorization-request.v1".into(),
        principal: format!("Healthcare::Provider::\"{provider}\""),
        action: "Healthcare::Action::\"administerMedication\"".into(),
        resource: "Healthcare::MedicationOrder::\"medication-order-1\"".into(),
        context: json!({
            "assuranceDigest": digest(12),
            "assuranceClosed": true,
            "trajectoryAssessmentDigest": digest(13),
            "trajectoryHandoffReady": true
        }),
        intent_digest: digest(6),
        handoff: HandoffInput {
            sequence: 1,
            payload_hex: hex::encode(b"medication administration intent"),
            semantic_root: digest(7),
            before_execution_root: digest(0),
            after_execution_root: digest(8),
            observation_digest: digest(9),
        },
    }
}

#[test]
fn healthcare_trajectory_context_is_admitted_by_the_strict_cedar_schema() {
    let snapshot = Snapshot::new(healthcare_bootstrap(true, false)).unwrap();
    snapshot
        .prepare(&healthcare_proposal("provider-1"))
        .expect("closed assurance and trajectory context must project to Cedar");

    let mut missing_trajectory = healthcare_proposal("provider-1");
    missing_trajectory
        .context
        .as_object_mut()
        .unwrap()
        .remove("trajectoryAssessmentDigest");
    let error = match snapshot.prepare(&missing_trajectory) {
        Ok(_) => panic!("missing trajectory digest must fail closed"),
        Err(error) => error,
    };
    assert_eq!(error.code, "cedar-context-invalid");
}

fn artifact(path: &std::path::Path) -> String {
    canonical::raw_digest(
        &std::fs::read(path)
            .expect("required AOT Runtime Host artifact must exist; no skipped acceptance"),
    )
}

struct TestRuntime {
    deployment: Deployment,
    child: Child,
    _directory: tempfile::TempDir,
}

impl Drop for TestRuntime {
    fn drop(&mut self) {
        let deadline = Instant::now() + Duration::from_secs(5);
        while Instant::now() < deadline {
            if self.child.try_wait().ok().flatten().is_some() {
                return;
            }
            std::thread::sleep(Duration::from_millis(2));
        }
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

fn spawn_runtime(timeout_ms: u64) -> TestRuntime {
    let host = PathBuf::from(
        std::env::var_os("AGENTIC_AI_LAB_CEDAR_RUNTIME_HOST")
            .expect("qualification requires the AOT Runtime Host artifact"),
    );
    let runtime_artifact_digest = artifact(&host);
    let rust_component_digest = canonical::raw_digest(CEDAR_VERSION.as_bytes());
    let lean_component_digest = canonical::raw_digest(LEAN_REVISION.as_bytes());
    let directory = tempfile::tempdir().unwrap();
    let endpoint = directory.path().join("runtime.sock");
    let mut child = Command::new(&host)
        .args([
            "serve-unix",
            endpoint.to_str().unwrap(),
            &runtime_artifact_digest,
            &rust_component_digest,
            &lean_component_digest,
            &timeout_ms.to_string(),
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .unwrap();
    support::wait_for_runtime_ready(&mut child, &endpoint);
    TestRuntime {
        deployment: Deployment {
            runtime_endpoint: endpoint,
            runtime_artifact_digest,
            rust_component_digest,
            lean_component_digest,
            timeout_ms,
            grant_lifetime_ms: 30000,
        },
        child,
        _directory: directory,
    }
}

fn deployment(runtime: &TestRuntime) -> Deployment {
    Deployment {
        runtime_endpoint: runtime.deployment.runtime_endpoint.clone(),
        runtime_artifact_digest: runtime.deployment.runtime_artifact_digest.clone(),
        rust_component_digest: runtime.deployment.rust_component_digest.clone(),
        lean_component_digest: runtime.deployment.lean_component_digest.clone(),
        timeout_ms: runtime.deployment.timeout_ms,
        grant_lifetime_ms: 30000,
    }
}

fn consume_request(
    authority: &Authority,
    grant: agentic_ai_lab_cedar_authority::authority::Signed<agentic_ai_lab_cedar_authority::authority::Grant>,
    proposal: &Proposal,
) -> ConsumeRequest {
    let info = authority.info();
    ConsumeRequest {
        grant,
        runtime_context_id: info.runtime_context_id,
        runtime_generation: info.runtime_generation,
        runtime_bundle_digest: info.runtime_bundle_digest,
        bundle_epoch: info.bundle_epoch,
        action: proposal.action.clone(),
        intent_digest: proposal.intent_digest.clone(),
        handoff: proposal.handoff.clone(),
    }
}

#[test]
fn real_dual_engines_allow_default_deny_and_forbid_override() {
    let runtime = spawn_runtime(10000);
    let mut authority = Authority::new(bootstrap(), deployment(&runtime), [42; 32]).unwrap();
    let request = proposal();
    let allowed = authority.issue(request.clone()).unwrap();
    assert_eq!(allowed.status, "authorized");
    verify_signature(&authority.info().issuer_public_key, &allowed.receipt).unwrap();
    let receipt = &allowed.receipt.payload;
    verify_signature(&authority.info().issuer_public_key, &receipt.rust).unwrap();
    verify_signature(&authority.info().issuer_public_key, &receipt.lean).unwrap();
    assert_ne!(
        receipt.rust.payload.receipt_id,
        receipt.lean.payload.receipt_id
    );
    assert_ne!(
        receipt.rust.payload.engine_id,
        receipt.lean.payload.engine_id
    );
    assert_ne!(
        receipt.rust.payload.engine_component_digest,
        receipt.lean.payload.engine_component_digest
    );
    assert_eq!(
        receipt.rust.payload.runtime_artifact_digest,
        receipt.lean.payload.runtime_artifact_digest
    );
    assert_eq!(
        receipt.rust.payload.authorization_subject,
        receipt.lean.payload.authorization_subject
    );
    assert_eq!(
        receipt.rust.payload.input_artifact_digest,
        receipt.lean.payload.input_artifact_digest
    );
    assert_eq!(
        receipt.rust.payload.outcome.determining_policies,
        ["permit-run"]
    );
    assert!(
        receipt
            .rust
            .payload
            .outcome
            .agrees_with(&receipt.lean.payload.outcome)
    );
    let mut denied = request.clone();
    denied.principal = "User::\"bob\"".into();
    let denied = authority.issue(denied).unwrap();
    assert_eq!(denied.status, "denied");
    assert!(denied.grant.is_none());
    let mut forbidden = request;
    forbidden.context["blocked"] = json!(true);
    let forbidden = authority.issue(forbidden).unwrap();
    assert_eq!(forbidden.status, "denied");
    assert!(forbidden.grant.is_none());
    assert_eq!(
        forbidden
            .receipt
            .payload
            .rust
            .payload
            .outcome
            .determining_policies,
        ["forbid-blocked"]
    );
    assert_eq!(authority.info().state, "ready");
}

#[test]
fn healthcare_medication_authorization_is_governance_bound_and_dual_witnessed() {
    let runtime = spawn_runtime(10000);
    let admitted_deployment = deployment(&runtime);

    let mut admitted = Authority::new(
        healthcare_bootstrap(true, false),
        admitted_deployment,
        [43; 32],
    )
    .unwrap();
    let allowed = admitted.issue(healthcare_proposal("provider-1")).unwrap();
    assert_eq!(allowed.status, "authorized");
    assert_eq!(allowed.receipt.payload.arbitration, "strict-lockstep");
    assert!(allowed.receipt.payload.per_request_dual_witness);
    assert!(
        allowed
            .receipt
            .payload
            .rust
            .payload
            .outcome
            .agrees_with(&allowed.receipt.payload.lean.payload.outcome)
    );
    assert_eq!(
        allowed
            .receipt
            .payload
            .rust
            .payload
            .authorization_subject
            .governance_assessment_digest,
        digest(10)
    );
    assert_eq!(
        allowed
            .receipt
            .payload
            .rust
            .payload
            .authorization_subject
            .subject_snapshot_digest,
        digest(11)
    );

    let mut trajectory_unready = healthcare_proposal("provider-1");
    trajectory_unready.context["trajectoryHandoffReady"] = json!(false);
    let trajectory_denied = admitted.issue(trajectory_unready).unwrap();
    assert_eq!(trajectory_denied.status, "denied");
    assert!(trajectory_denied.grant.is_none());

    let mut assurance_open = healthcare_proposal("provider-1");
    assurance_open.context["assuranceClosed"] = json!(false);
    let assurance_denied = admitted.issue(assurance_open).unwrap();
    assert_eq!(assurance_denied.status, "denied");
    assert!(assurance_denied.grant.is_none());

    let denied = admitted.issue(healthcare_proposal("provider-2")).unwrap();
    assert_eq!(denied.status, "denied");
    assert!(denied.grant.is_none());

    let revoked_runtime = spawn_runtime(10000);
    let mut revoked = Authority::new(
        healthcare_bootstrap(true, true),
        deployment(&revoked_runtime),
        [44; 32],
    )
    .unwrap();
    let forbidden = revoked.issue(healthcare_proposal("provider-1")).unwrap();
    assert_eq!(forbidden.status, "denied");
    assert!(forbidden.grant.is_none());
    assert_eq!(
        forbidden
            .receipt
            .payload
            .rust
            .payload
            .outcome
            .determining_policies,
        ["healthcare-medication-revocation"]
    );
}

#[test]
fn signature_context_generation_intent_and_exact_handoff_are_bound_before_consumption() {
    let runtime = spawn_runtime(10000);
    let mut authority = Authority::new(bootstrap(), deployment(&runtime), [42; 32]).unwrap();
    let proposal = proposal();
    let grant = authority.issue(proposal.clone()).unwrap().grant.unwrap();
    let expected = consume_request(&authority, grant, &proposal);
    let mut forged = expected.clone();
    forged.grant.payload.subject.request_digest = digest(10);
    assert_eq!(
        authority.consume(forged).unwrap_err().code,
        "authority-signature-invalid"
    );
    for field in ["context", "generation", "bundle", "epoch"] {
        let mut changed = expected.clone();
        match field {
            "context" => changed.runtime_context_id = "other".into(),
            "generation" => changed.runtime_generation += 1,
            "bundle" => changed.runtime_bundle_digest = digest(11),
            _ => changed.bundle_epoch += 1,
        }
        assert_eq!(
            authority.consume(changed).unwrap_err().code,
            "grant-runtime-binding-mismatch"
        );
    }
    for field in ["action", "intent", "payload", "sequence", "execution-root"] {
        let mut changed = expected.clone();
        match field {
            "action" => changed.action = "Action::\"other\"".into(),
            "intent" => changed.intent_digest = digest(11),
            "payload" => changed.handoff.payload_hex = hex::encode(b"substituted"),
            "sequence" => changed.handoff.sequence += 1,
            _ => changed.handoff.after_execution_root = digest(11),
        }
        assert_eq!(
            authority.consume(changed).unwrap_err().code,
            "grant-effect-binding-mismatch"
        );
    }
    assert_eq!(authority.info().pending_grants, 1);
    let consumed = authority.consume(expected.clone()).unwrap();
    assert_eq!(consumed.handoff, proposal.handoff);
    assert_eq!(
        authority.consume(expected).unwrap_err().code,
        "grant-consumed-or-unknown"
    );
    assert_eq!(authority.info().pending_grants, 0);
}

#[test]
fn revocation_close_and_recreated_context_never_reopen_a_grant() {
    let runtime = spawn_runtime(10000);
    let mut authority = Authority::new(bootstrap(), deployment(&runtime), [42; 32]).unwrap();
    let proposal = proposal();
    let grant = authority.issue(proposal.clone()).unwrap().grant.unwrap();
    let expected = consume_request(&authority, grant, &proposal);
    let replacement_runtime = spawn_runtime(10000);
    let mut replacement =
        Authority::new(bootstrap(), deployment(&replacement_runtime), [42; 32]).unwrap();
    assert_eq!(
        replacement.consume(expected.clone()).unwrap_err().code,
        "grant-authority-mismatch"
    );
    authority.revoke(1).unwrap();
    assert_eq!(
        authority.consume(expected.clone()).unwrap_err().code,
        "grant-revoked"
    );
    assert_eq!(
        authority.revoke(1).unwrap_err().code,
        "revocation-epoch-invalid"
    );
    authority.close();
    assert_eq!(
        authority.consume(expected).unwrap_err().code,
        "authority-closed"
    );
    assert_eq!(
        authority.issue(proposal).unwrap_err().code,
        "authority-closed"
    );
}

#[test]
fn expiration_and_engine_deadline_are_fail_closed() {
    let runtime = spawn_runtime(10000);
    let mut configuration = deployment(&runtime);
    configuration.grant_lifetime_ms = 1;
    let mut authority = Authority::new(bootstrap(), configuration.clone(), [42; 32]).unwrap();
    let proposal = proposal();
    let grant = authority.issue(proposal.clone()).unwrap().grant.unwrap();
    std::thread::sleep(std::time::Duration::from_millis(5));
    assert_eq!(
        authority
            .consume(consume_request(&authority, grant, &proposal))
            .unwrap_err()
            .code,
        "grant-expired"
    );
    drop(authority);
    let timeout_runtime = spawn_runtime(1);
    configuration = deployment(&timeout_runtime);
    let mut authority = Authority::new(bootstrap(), configuration, [42; 32]).unwrap();
    let error = authority.issue(proposal.clone()).unwrap_err();
    assert_eq!(error.code, "cedar-engine-timeout");
    assert_eq!(
        authority.info().first_failure.unwrap().code,
        "cedar-engine-timeout"
    );
    assert_eq!(authority.info().state, "suspended");
    assert_eq!(
        authority.issue(proposal).unwrap_err().code,
        "authority-suspended"
    );
}

#[test]
fn snapshot_and_request_failures_do_not_manufacture_decisions() {
    let mut conflicting = bootstrap();
    conflicting.policies.push(conflicting.policies[0].clone());
    Snapshot::new(conflicting.clone()).unwrap();
    conflicting.policies.last_mut().unwrap().source = "forbid(principal, action, resource);".into();
    assert_eq!(
        Snapshot::new(conflicting).err().unwrap().code,
        "policy-identity-conflict"
    );
    let snapshot = Snapshot::new(bootstrap()).unwrap();
    let mut request = proposal();
    request.context["agentic_ai_lab"] = json!({});
    assert_eq!(
        snapshot.prepare(&request).err().unwrap().code,
        "reserved-authority-context"
    );
    request = proposal();
    request.action = "Action::\"ungranted\"".into();
    assert_eq!(
        snapshot.prepare(&request).err().unwrap().code,
        "capability-not-granted"
    );
    request = proposal();
    request.context["approved"] = json!("not-a-boolean");
    assert_eq!(
        snapshot.prepare(&request).err().unwrap().code,
        "cedar-request-invalid"
    );
    let runtime = spawn_runtime(10000);
    let mut artifact_changed = deployment(&runtime);
    artifact_changed.runtime_artifact_digest = digest(0);
    assert_eq!(
        Authority::new(bootstrap(), artifact_changed, [42; 32])
            .err()
            .unwrap()
            .code,
        "cedar-runtime-handshake-mismatch"
    );
}

#[test]
fn preflight_only_request_requires_runtime_source_admission() {
    let snapshot = Snapshot::new(bootstrap()).unwrap();
    let mut request = proposal();
    request.context["agentic_ai_lab_preflight_only"] = json!(true);
    assert_eq!(
        snapshot.prepare(&request).err().unwrap().code,
        "runtime-source-admission-required"
    );
    request.context["agentic_ai_lab_preflight_only"] = json!(false);
    assert_eq!(
        snapshot.prepare(&request).err().unwrap().code,
        "runtime-source-admission-required"
    );
}

#[test]
fn source_bound_capability_rejects_stripped_preflight_context() {
    let mut incomplete = serde_json::to_value(bootstrap()).unwrap();
    incomplete["capabilities"][0]
        .as_object_mut()
        .unwrap()
        .remove("source_admission_required");
    assert!(serde_json::from_value::<Bootstrap>(incomplete).is_err());
    let mut administrative = bootstrap();
    administrative.capabilities[0].source_admission_required = true;
    let snapshot = Snapshot::new(administrative).unwrap();
    let mut request = proposal();
    request.context["agentic_ai_lab_preflight_only"] = json!(true);
    assert_eq!(
        snapshot.prepare(&request).err().unwrap().code,
        "runtime-source-admission-required"
    );
    request
        .context
        .as_object_mut()
        .unwrap()
        .remove("agentic_ai_lab_preflight_only");
    assert_eq!(
        snapshot.prepare(&request).err().unwrap().code,
        "runtime-source-admission-required"
    );
    request.context = json!({"approved": true, "blocked": false});
    assert_eq!(
        snapshot.prepare(&request).err().unwrap().code,
        "runtime-source-admission-required"
    );
}

#[test]
fn formatting_order_and_duplicate_policy_identity_preserve_semantic_digest() {
    let initial = Snapshot::new(bootstrap())
        .unwrap()
        .prepare(&proposal())
        .unwrap();
    let mut changed = bootstrap();
    changed.policies.reverse();
    changed.policies[0].source = format!(
        "// whitespace is not identity\n\n {} \n",
        changed.policies[0].source
    );
    changed.policies.push(changed.policies[0].clone());
    let canonical = Snapshot::new(changed)
        .unwrap()
        .prepare(&proposal())
        .unwrap();
    assert_eq!(initial.subject, canonical.subject);
    assert_eq!(initial.policy_input_digest, canonical.policy_input_digest);
    let mut changed_request = proposal();
    changed_request.handoff.payload_hex = hex::encode(b"changed");
    assert_ne!(
        initial.subject.request_digest,
        Snapshot::new(bootstrap())
            .unwrap()
            .prepare(&changed_request)
            .unwrap()
            .subject
            .request_digest
    );
}
