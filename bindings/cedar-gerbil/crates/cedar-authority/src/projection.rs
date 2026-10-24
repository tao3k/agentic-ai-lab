// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! Validate the POO-owned semantic snapshot at the runtime boundary.

use crate::{Error, Result, canonical, wire};
use cedar_policy::{
    Context, Entities, EntityUid, Policy, PolicyId, PolicySet, Request, Schema, ValidationMode,
    Validator,
};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use std::collections::BTreeMap;
use std::str::FromStr;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct PolicySource {
    pub identity: String,
    pub source: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Capability {
    pub action: String,
    pub event_kind: u32,
    pub source_admission_required: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Provenance {
    pub composition_identity: String,
    pub profile_identities: Vec<String>,
    pub profile_origin_digest: String,
    pub governance_assessment_digest: String,
    pub subject_snapshot_digest: String,
    pub governance_admitted: bool,
    pub certification_names: Vec<String>,
}

/// Administrative projection from the composition/authority owner, never an
/// argument that an untrusted authorization request may replace.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Bootstrap {
    pub schema_id: String,
    pub producer: String,
    pub source: String,
    pub object_kind: String,
    pub provenance: Provenance,
    pub authority_id: String,
    pub runtime_context_id: String,
    pub runtime_generation: u64,
    pub bundle_epoch: u64,
    pub runtime_bundle_digest: String,
    pub profile_bundle_digest: String,
    pub independent_bundle_digest: String,
    pub capability_contract_digest: String,
    pub policy_revision: u64,
    pub revocation_epoch: u64,
    pub schema_json: String,
    pub policies: Vec<PolicySource>,
    pub entities_json: String,
    pub capabilities: Vec<Capability>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HandoffInput {
    pub sequence: u64,
    pub payload_hex: String,
    pub semantic_root: String,
    pub before_execution_root: String,
    pub after_execution_root: String,
    pub observation_digest: String,
}

impl HandoffInput {
    pub fn validate(&self) -> Result<Vec<u8>> {
        if self.sequence == 0 {
            return Err(Error::new("handoff-invalid", "sequence must be positive"));
        }
        for digest in [
            &self.semantic_root,
            &self.before_execution_root,
            &self.after_execution_root,
            &self.observation_digest,
        ] {
            canonical::check_digest(digest)?;
        }
        let payload = hex::decode(&self.payload_hex)
            .map_err(|_| Error::new("handoff-invalid", "invalid payload hex"))?;
        if payload.len() > 65536 || hex::encode(&payload) != self.payload_hex {
            return Err(Error::new(
                "handoff-invalid",
                "payload must be canonical lowercase hex and at most 64 KiB",
            ));
        }
        Ok(payload)
    }
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Proposal {
    pub schema_id: String,
    pub principal: String,
    pub action: String,
    pub resource: String,
    pub context: Value,
    pub intent_digest: String,
    pub handoff: HandoffInput,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AuthorizationSubject {
    pub request_digest: String,
    pub policy_set_digest: String,
    pub entity_store_digest: String,
    pub independent_declaration_bundle_digest: String,
    pub governance_assessment_digest: String,
    pub subject_snapshot_digest: String,
    pub epoch: u64,
}

pub struct PreparedRequest {
    pub subject: AuthorizationSubject,
    pub policy_input_digest: String,
    pub protobuf: Vec<u8>,
    pub event_kind: u32,
    pub action: String,
}

pub struct Snapshot {
    pub bootstrap: Bootstrap,
    schema: Schema,
    policies: PolicySet,
    entities: Entities,
    capabilities: BTreeMap<String, (u32, bool)>,
    policy_digest: String,
    entity_digest: String,
    schema_digest: String,
}

fn cedar_error<E: std::fmt::Display>(code: &'static str) -> impl FnOnce(E) -> Error {
    move |error| Error::new(code, error.to_string())
}

/// The reserved context is a versioned projection of the POO authority
/// context, not a caller-selected Cedar context value. Only direct Record
/// contexts are admitted by this first adapter version.
fn materialize_context_schema(mut schema: Value) -> Result<Value> {
    let namespaces = schema
        .as_object_mut()
        .ok_or_else(|| Error::new("cedar-schema-invalid", "schema must be an object"))?;
    for namespace in namespaces.values_mut() {
        let Some(actions) = namespace.get_mut("actions").and_then(Value::as_object_mut) else {
            continue;
        };
        for action in actions.values_mut() {
            let Some(applies) = action.get_mut("appliesTo").and_then(Value::as_object_mut) else {
                continue;
            };
            let context = applies
                .entry("context")
                .or_insert_with(|| json!({"type": "Record", "attributes": {}}));
            if context.get("type").and_then(Value::as_str) != Some("Record") {
                return Err(Error::new(
                    "cedar-context-schema-unsupported",
                    "authority v1 requires direct Record contexts",
                ));
            }
            let fields = context
                .get_mut("attributes")
                .and_then(Value::as_object_mut)
                .ok_or_else(|| {
                    Error::new(
                        "cedar-schema-invalid",
                        "context attributes must be an object",
                    )
                })?;
            if fields.contains_key("agentic_ai_lab") {
                return Err(Error::new(
                    "reserved-authority-context",
                    "schema cannot redefine context.agentic_ai_lab",
                ));
            }
            fields.insert("agentic_ai_lab".into(), json!({"type": "Record", "attributes": {
                "intentDigest": {"type": "String"}, "handoffDigest": {"type": "String"}, "runtimeContext": {"type": "String"},
                "runtimeGeneration": {"type": "Long"}, "bundleEpoch": {"type": "Long"}, "runtimeBundleDigest": {"type": "String"},
                "profileBundleDigest": {"type": "String"}, "capabilityContractDigest": {"type": "String"}, "revocationEpoch": {"type": "Long"},
                "governanceAssessmentDigest": {"type": "String"}, "subjectSnapshotDigest": {"type": "String"}, "governanceAdmitted": {"type": "Boolean"}
            }}));
        }
    }
    Ok(schema)
}

impl Snapshot {
    pub fn new(bootstrap: Bootstrap) -> Result<Self> {
        if bootstrap.schema_id != "agentic-ai-lab.cedar-authority-snapshot.v1"
            || bootstrap.object_kind != "cedar-authority-snapshot"
            || bootstrap.producer != "agentic-ai-lab.scheme-control"
            || bootstrap.source != "modules/authorization/providers/cedar/objects.ss"
        {
            return Err(Error::new(
                "snapshot-owner-invalid",
                "expected the POO authority projection",
            ));
        }
        for identity in [
            &bootstrap.authority_id,
            &bootstrap.runtime_context_id,
            &bootstrap.provenance.composition_identity,
        ] {
            if identity.is_empty() || identity.len() > 256 {
                return Err(Error::new(
                    "identity-invalid",
                    "identity must contain 1..256 bytes",
                ));
            }
        }
        if bootstrap.runtime_generation == 0 || bootstrap.policy_revision == 0 {
            return Err(Error::new(
                "generation-invalid",
                "runtime generation and policy revision must be positive",
            ));
        }
        for digest in [
            &bootstrap.runtime_bundle_digest,
            &bootstrap.profile_bundle_digest,
            &bootstrap.independent_bundle_digest,
            &bootstrap.capability_contract_digest,
            &bootstrap.provenance.profile_origin_digest,
            &bootstrap.provenance.governance_assessment_digest,
            &bootstrap.provenance.subject_snapshot_digest,
        ] {
            canonical::check_digest(digest)?;
        }
        if bootstrap.provenance.profile_identities.is_empty()
            || bootstrap
                .provenance
                .profile_identities
                .iter()
                .any(String::is_empty)
            || !bootstrap.provenance.governance_admitted
        {
            return Err(Error::new(
                "governance-admission-invalid",
                "profile identities and admitted Governance evidence are required",
            ));
        }
        if bootstrap.provenance.certification_names.is_empty()
            || bootstrap
                .provenance
                .certification_names
                .iter()
                .any(String::is_empty)
        {
            return Err(Error::new(
                "proof-binding-absent",
                "certification names must survive the projection",
            ));
        }
        let schema_json =
            materialize_context_schema(canonical::parse(bootstrap.schema_json.as_bytes())?)?;
        let schema = Schema::from_json_value(schema_json.clone())
            .map_err(cedar_error("cedar-schema-invalid"))?;
        let mut policies = PolicySet::new();
        let mut by_id = BTreeMap::new();
        if bootstrap.policies.len() > 256 {
            return Err(Error::new(
                "policy-budget-exceeded",
                "maximum is 256 static policies",
            ));
        }
        for input in &bootstrap.policies {
            if input.identity.is_empty() || input.source.len() > 65536 {
                return Err(Error::new(
                    "policy-invalid",
                    "empty identity or oversized source",
                ));
            }
            PolicyId::from_str(&input.identity).map_err(cedar_error("policy-identity-invalid"))?;
            let parsed =
                PolicySet::from_str(&input.source).map_err(cedar_error("cedar-policy-invalid"))?;
            if parsed.templates().next().is_some() {
                return Err(Error::new(
                    "cedar-policy-invalid",
                    "policy templates require explicit linking",
                ));
            }
            let mut bodies = parsed
                .policies()
                .map(|policy| {
                    policy
                        .to_cedar()
                        .map(|body| (policy.id().to_string(), body))
                        .ok_or_else(|| {
                            Error::new("cedar-policy-invalid", "linked policy cannot render")
                        })
                })
                .collect::<Result<Vec<_>>>()?;
            if bodies.is_empty() {
                return Err(Error::new("cedar-policy-invalid", "empty policy artifact"));
            }
            bodies.sort_by(|left, right| left.0.cmp(&right.0));
            let multiple = bodies.len() > 1;
            for (index, (_, source)) in bodies.into_iter().enumerate() {
                let identity = if multiple {
                    format!("{}-{index}", input.identity)
                } else {
                    input.identity.clone()
                };
                let policy = Policy::parse(
                    Some(
                        PolicyId::from_str(&identity)
                            .map_err(cedar_error("policy-identity-invalid"))?,
                    ),
                    &source,
                )
                .map_err(cedar_error("cedar-policy-invalid"))?;
                let canonical = policy
                    .to_json()
                    .map_err(cedar_error("cedar-policy-invalid"))?;
                if let Some(previous) = by_id.get(&identity) {
                    if previous != &canonical {
                        return Err(Error::new("policy-identity-conflict", &identity));
                    }
                    continue;
                }
                by_id.insert(identity, canonical);
                if by_id.len() > 256 {
                    return Err(Error::new(
                        "policy-budget-exceeded",
                        "maximum is 256 static policies",
                    ));
                }
                policies
                    .add(policy)
                    .map_err(cedar_error("cedar-policy-invalid"))?;
            }
        }
        let validation = Validator::new(schema.clone()).validate(&policies, ValidationMode::Strict);
        if !validation.validation_passed() {
            let errors: Vec<_> = validation
                .validation_errors()
                .map(ToString::to_string)
                .collect();
            return Err(Error::new(
                "cedar-policy-validation-failed",
                errors.join("; "),
            ));
        }
        let entities = Entities::from_json_value(
            canonical::parse(bootstrap.entities_json.as_bytes())?,
            Some(&schema),
        )
        .map_err(cedar_error("cedar-entities-invalid"))?;
        let mut canonical_entities: Vec<Value> = serde_json::from_value(
            entities
                .to_json_value()
                .map_err(cedar_error("cedar-entities-invalid"))?,
        )
        .map_err(cedar_error("cedar-entities-invalid"))?;
        // Cedar owns set and transitive-closure semantics; project its parsed
        // entities and normalize only the documented set-like collections.
        for entity in &mut canonical_entities {
            if let Some(parents) = entity.get_mut("parents").and_then(Value::as_array_mut) {
                parents.sort_by_key(Value::to_string);
                parents.dedup();
            }
        }
        canonical_entities.sort_by_key(|entity| entity.get("uid").map(Value::to_string));
        let mut capabilities = BTreeMap::new();
        for capability in &bootstrap.capabilities {
            let action = EntityUid::from_str(&capability.action)
                .map_err(cedar_error("capability-invalid"))?
                .to_string();
            if capability.event_kind == 0
                || capabilities
                    .insert(
                        action,
                        (capability.event_kind, capability.source_admission_required),
                    )
                    .is_some()
            {
                return Err(Error::new(
                    "capability-invalid",
                    "duplicate action or zero event kind",
                ));
            }
        }
        if capabilities.is_empty() {
            return Err(Error::new("capability-invalid", "no admitted actions"));
        }
        let policy_digest = canonical::digest("agentic-ai-lab/cedar/policy-set", &by_id)?;
        let entity_digest = canonical::digest("agentic-ai-lab/cedar/entity-store", &canonical_entities)?;
        let schema_digest = canonical::digest("agentic-ai-lab/cedar/schema-revision", &schema_json)?;
        Ok(Self {
            bootstrap,
            schema,
            policies,
            entities,
            capabilities,
            policy_digest,
            entity_digest,
            schema_digest,
        })
    }

    pub fn prepare(&self, proposal: &Proposal) -> Result<PreparedRequest> {
        if proposal.schema_id != "agentic-ai-lab.cedar-authorization-request.v1" {
            return Err(Error::new("request-schema-invalid", &proposal.schema_id));
        }
        canonical::check_digest(&proposal.intent_digest)?;
        proposal.handoff.validate()?;
        let principal = EntityUid::from_str(&proposal.principal)
            .map_err(cedar_error("cedar-request-invalid"))?;
        let action =
            EntityUid::from_str(&proposal.action).map_err(cedar_error("cedar-request-invalid"))?;
        let resource = EntityUid::from_str(&proposal.resource)
            .map_err(cedar_error("cedar-request-invalid"))?;
        let (event_kind, source_admission_required) =
            *self
                .capabilities
                .get(&action.to_string())
                .ok_or_else(|| Error::new("capability-not-granted", action.to_string()))?;
        // This requirement belongs to the administrative capability, not to
        // caller-editable context. Removing all preflight fields cannot turn
        // a source-bound action into an ordinary Cedar grant.
        if source_admission_required {
            return Err(Error::new(
                "runtime-source-admission-required",
                "this action requires Runtime-owned source admission",
            ));
        }
        let mut context_json = proposal.context.clone();
        let fields = context_json
            .as_object_mut()
            .ok_or_else(|| Error::new("cedar-context-invalid", "context must be a record"))?;
        if fields.contains_key("agentic_ai_lab") {
            return Err(Error::new(
                "reserved-authority-context",
                "caller cannot supply context.agentic_ai_lab",
            ));
        }
        // POO-native preflight projections are caller-editable input. Until a
        // Runtime-owned source admission exists, even a permissive Cedar
        // policy must not turn one into an effect grant.
        if fields.contains_key("agentic_ai_lab_preflight_only") {
            return Err(Error::new(
                "runtime-source-admission-required",
                "preflight-only context has no Runtime source admission",
            ));
        }
        fields.insert("agentic_ai_lab".into(), json!({
            "intentDigest": proposal.intent_digest,
            "handoffDigest": canonical::digest("agentic-ai-lab/cedar/runtime-handoff", &proposal.handoff)?,
            "runtimeContext": self.bootstrap.runtime_context_id,
            "runtimeGeneration": self.bootstrap.runtime_generation,
            "bundleEpoch": self.bootstrap.bundle_epoch,
            "runtimeBundleDigest": self.bootstrap.runtime_bundle_digest,
            "profileBundleDigest": self.bootstrap.profile_bundle_digest,
            "capabilityContractDigest": self.bootstrap.capability_contract_digest,
            "revocationEpoch": self.bootstrap.revocation_epoch,
            "governanceAssessmentDigest": self.bootstrap.provenance.governance_assessment_digest,
            "subjectSnapshotDigest": self.bootstrap.provenance.subject_snapshot_digest,
            "governanceAdmitted": self.bootstrap.provenance.governance_admitted,
        }));
        let context = Context::from_json_value(context_json, Some((&self.schema, &action)))
            .map_err(cedar_error("cedar-context-invalid"))?;
        let request_json = json!({"principal": principal.to_string(), "action": action.to_string(), "resource": resource.to_string(),
            "context": context.to_json_value().map_err(cedar_error("cedar-context-invalid"))?});
        let subject = AuthorizationSubject {
            request_digest: canonical::digest("agentic-ai-lab/cedar/request", &request_json)?,
            policy_set_digest: self.policy_digest.clone(),
            entity_store_digest: self.entity_digest.clone(),
            independent_declaration_bundle_digest: self.bootstrap.independent_bundle_digest.clone(),
            governance_assessment_digest: self
                .bootstrap
                .provenance
                .governance_assessment_digest
                .clone(),
            subject_snapshot_digest: self.bootstrap.provenance.subject_snapshot_digest.clone(),
            epoch: self.bootstrap.bundle_epoch,
        };
        let policy_input_digest = canonical::digest(
            "agentic-ai-lab/cedar/policy-input",
            &json!([
                wire::CEDAR_VERSION,
                wire::LEAN_REVISION,
                self.policy_digest,
                self.schema_digest,
                subject.request_digest,
                self.entity_digest,
                [],
                self.bootstrap.profile_bundle_digest,
                self.bootstrap.capability_contract_digest,
                self.bootstrap.provenance.governance_assessment_digest,
                self.bootstrap.provenance.subject_snapshot_digest,
                "strict-lockstep",
                self.bootstrap.provenance.profile_origin_digest,
            ]),
        )?;
        let request = Request::new(
            principal,
            action.clone(),
            resource,
            context,
            Some(&self.schema),
        )
        .map_err(cedar_error("cedar-request-invalid"))?;
        let protobuf = wire::AuthorizationRequest::encode(&request, &self.policies, &self.entities);
        if protobuf.len() > canonical::MAX_PROJECTION_BYTES {
            return Err(Error::new(
                "cedar-input-too-large",
                "protobuf exceeds 1 MiB",
            ));
        }
        Ok(PreparedRequest {
            subject,
            policy_input_digest,
            protobuf,
            event_kind,
            action: action.to_string(),
        })
    }
}
