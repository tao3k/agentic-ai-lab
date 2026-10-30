// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! Issuer-owned state: no caller observations, outcome booleans, or validators.

use crate::projection::{
    AuthorizationSubject, Bootstrap, HandoffInput, Proposal, Provenance, Snapshot,
};
use crate::runtime::{Deployment, RuntimeClient, RuntimeWitness};
use crate::wire::Outcome;
use crate::{Error, Result, canonical};
use ed25519_dalek::{Signature, Signer, SigningKey, VerifyingKey};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

const SIGNING_DOMAIN: &str = "agentic-ai-lab/cedar/authority-signature";
const MAX_PENDING: usize = 4096;

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Signed<T> {
    pub payload: T,
    pub signature: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EngineReceipt {
    pub schema_id: String,
    pub engine_id: String,
    pub runtime_artifact_digest: String,
    pub engine_component_digest: String,
    pub receipt_id: String,
    pub authorization_subject: AuthorizationSubject,
    pub policy_input_digest: String,
    pub input_artifact_digest: String,
    pub outcome: Outcome,
    pub elapsed_ms: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DecisionReceipt {
    pub schema_id: String,
    pub authority_id: String,
    pub authority_instance: String,
    pub runtime_context_id: String,
    pub runtime_generation: u64,
    pub runtime_bundle_digest: String,
    pub profile_bundle_digest: String,
    pub capability_contract_digest: String,
    pub policy_revision: u64,
    pub revocation_epoch: u64,
    pub provenance: Provenance,
    pub arbitration: String,
    pub per_request_dual_witness: bool,
    pub rust: Signed<EngineReceipt>,
    pub lean: Signed<EngineReceipt>,
    pub decision: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Grant {
    pub schema_id: String,
    pub grant_id: String,
    pub authority_id: String,
    pub authority_instance: String,
    pub issuer_public_key: String,
    pub decision_receipt_digest: String,
    pub subject: AuthorizationSubject,
    pub policy_input_digest: String,
    pub runtime_context_id: String,
    pub runtime_generation: u64,
    pub runtime_bundle_digest: String,
    pub profile_bundle_digest: String,
    pub capability_contract_digest: String,
    pub policy_revision: u64,
    pub revocation_epoch: u64,
    pub intent_digest: String,
    pub handoff_digest: String,
    pub action: String,
    pub event_kind: u32,
    pub nonce: [u64; 2],
    pub issued_at_unix_ms: u64,
    pub expires_at_unix_ms: u64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AuthorizationResult {
    pub status: String,
    pub receipt: Signed<DecisionReceipt>,
    pub grant: Option<Signed<Grant>>,
}

/// Expected values are supplied by the trusted runtime binding, not taken
/// from the token being checked.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ConsumeRequest {
    pub grant: Signed<Grant>,
    pub runtime_context_id: String,
    pub runtime_generation: u64,
    pub runtime_bundle_digest: String,
    pub bundle_epoch: u64,
    pub action: String,
    pub intent_digest: String,
    pub handoff: HandoffInput,
}

#[derive(Clone, Debug, Serialize)]
pub struct ConsumedHandoff {
    pub schema_id: &'static str,
    pub grant_id: String,
    pub nonce: [u64; 2],
    pub event_kind: u32,
    pub payload_digest: String,
    pub handoff: HandoffInput,
}

#[derive(Clone, Debug, Serialize)]
pub struct AuthorityInfo {
    pub schema_id: &'static str,
    pub authority_id: String,
    pub authority_instance: String,
    pub issuer_public_key: String,
    pub runtime_context_id: String,
    pub runtime_generation: u64,
    pub runtime_bundle_digest: String,
    pub bundle_epoch: u64,
    pub policy_revision: u64,
    pub revocation_epoch: u64,
    pub pending_grants: usize,
    pub state: &'static str,
    pub first_failure: Option<Error>,
}

struct Pending {
    digest: String,
    deadline: Instant,
}

pub struct Authority {
    snapshot: Snapshot,
    runtime: RuntimeClient,
    signing_key: SigningKey,
    instance: String,
    deployment: Deployment,
    pending: BTreeMap<String, Pending>,
    suspended: Option<Error>,
    closed: bool,
}

fn random_bytes<const N: usize>() -> Result<[u8; N]> {
    let mut bytes = [0; N];
    getrandom::fill(&mut bytes)
        .map_err(|e| Error::new("authority-entropy-unavailable", e.to_string()))?;
    Ok(bytes)
}

pub fn verify_signature<T: Serialize>(public_key: &str, value: &Signed<T>) -> Result<()> {
    let bytes: [u8; 32] = hex::decode(public_key)
        .map_err(|_| Error::new("authority-signature-invalid", "invalid public key"))?
        .try_into()
        .map_err(|_| Error::new("authority-signature-invalid", "invalid public key length"))?;
    let key = VerifyingKey::from_bytes(&bytes)
        .map_err(|_| Error::new("authority-signature-invalid", "invalid public key"))?;
    let signature =
        Signature::from_slice(&hex::decode(&value.signature).map_err(|_| {
            Error::new("authority-signature-invalid", "invalid signature encoding")
        })?)
        .map_err(|_| Error::new("authority-signature-invalid", "invalid signature length"))?;
    key.verify_strict(
        &canonical::material(SIGNING_DOMAIN, &value.payload)?,
        &signature,
    )
    .map_err(|_| {
        Error::new(
            "authority-signature-invalid",
            "signature does not bind the payload",
        )
    })
}

impl Authority {
    pub fn new(bootstrap: Bootstrap, deployment: Deployment, seed: [u8; 32]) -> Result<Self> {
        if deployment.timeout_ms == 0
            || deployment.timeout_ms > 10000
            || deployment.grant_lifetime_ms == 0
            || deployment.grant_lifetime_ms > 30000
        {
            return Err(Error::new(
                "authority-budget-invalid",
                "engine budget 1..10000ms; grant lifetime 1..30000ms",
            ));
        }
        if deployment.rust_component_digest == deployment.lean_component_digest {
            return Err(Error::new(
                "same-engine-artifact",
                "dual execution requires distinct linked component identities",
            ));
        }
        let snapshot = Snapshot::new(bootstrap)?;
        let runtime = RuntimeClient::connect(
            &deployment.runtime_endpoint,
            &deployment.runtime_artifact_digest,
            &deployment.rust_component_digest,
            &deployment.lean_component_digest,
            deployment.timeout_ms,
        )?;
        Ok(Self {
            snapshot,
            runtime,
            signing_key: SigningKey::from_bytes(&seed),
            instance: hex::encode(random_bytes::<32>()?),
            deployment,
            pending: BTreeMap::new(),
            suspended: None,
            closed: false,
        })
    }

    fn sign<T: Serialize>(&self, payload: T) -> Result<Signed<T>> {
        let signature = self
            .signing_key
            .sign(&canonical::material(SIGNING_DOMAIN, &payload)?);
        Ok(Signed {
            payload,
            signature: hex::encode(signature.to_bytes()),
        })
    }

    fn public_key(&self) -> String {
        hex::encode(self.signing_key.verifying_key().to_bytes())
    }

    fn ensure_live(&self) -> Result<()> {
        if self.closed {
            return Err(Error::new(
                "authority-closed",
                "runtime generation is closed",
            ));
        }
        if let Some(error) = &self.suspended {
            return Err(Error::new("authority-suspended", error.to_string()));
        }
        Ok(())
    }

    pub fn info(&self) -> AuthorityInfo {
        let snapshot = &self.snapshot.bootstrap;
        AuthorityInfo {
            schema_id: "agentic-ai-lab.cedar-authority-state.v1",
            authority_id: snapshot.authority_id.clone(),
            authority_instance: self.instance.clone(),
            issuer_public_key: self.public_key(),
            runtime_context_id: snapshot.runtime_context_id.clone(),
            runtime_generation: snapshot.runtime_generation,
            runtime_bundle_digest: snapshot.runtime_bundle_digest.clone(),
            bundle_epoch: snapshot.bundle_epoch,
            policy_revision: snapshot.policy_revision,
            revocation_epoch: snapshot.revocation_epoch,
            pending_grants: self.pending.len(),
            state: if self.closed {
                "closed"
            } else if self.suspended.is_some() {
                "suspended"
            } else {
                "ready"
            },
            first_failure: self.suspended.clone(),
        }
    }

    pub fn issue(&mut self, proposal: Proposal) -> Result<AuthorizationResult> {
        self.ensure_live()?;
        self.pending
            .retain(|_, pending| pending.deadline > Instant::now());
        if self.pending.len() >= MAX_PENDING {
            return Err(Error::new(
                "authority-grant-budget-exceeded",
                "4096 unconsumed grants",
            ));
        }
        let prepared = self.snapshot.prepare(&proposal)?;
        let execution = self.runtime.evaluate(&prepared.protobuf);
        let (rust, lean) = match execution {
            Ok(execution) => execution,
            Err(error) => {
                self.suspended = Some(error.clone());
                self.pending.clear();
                return Err(error);
            }
        };
        let id_bytes = random_bytes::<16>()?;
        let grant_id = format!("{}:{}", self.instance, hex::encode(id_bytes));
        let input_digest = canonical::raw_digest(&prepared.protobuf);
        let engine_receipt = |result: RuntimeWitness| {
            self.sign(EngineReceipt {
                schema_id: "agentic-ai-lab.cedar-engine-receipt.v1".into(),
                engine_id: result.engine_id.clone(),
                runtime_artifact_digest: self.deployment.runtime_artifact_digest.clone(),
                engine_component_digest: result.component_digest,
                receipt_id: format!("{grant_id}:{}", result.engine_id),
                authorization_subject: prepared.subject.clone(),
                policy_input_digest: prepared.policy_input_digest.clone(),
                input_artifact_digest: input_digest.clone(),
                outcome: result.outcome,
                elapsed_ms: result.elapsed_ms,
            })
        };
        let decision = rust.outcome.decision.clone();
        let snapshot = &self.snapshot.bootstrap;
        let receipt = self.sign(DecisionReceipt {
            schema_id: "agentic-ai-lab.cedar-decision-receipt.v1".into(),
            authority_id: snapshot.authority_id.clone(),
            authority_instance: self.instance.clone(),
            runtime_context_id: snapshot.runtime_context_id.clone(),
            runtime_generation: snapshot.runtime_generation,
            runtime_bundle_digest: snapshot.runtime_bundle_digest.clone(),
            profile_bundle_digest: snapshot.profile_bundle_digest.clone(),
            capability_contract_digest: snapshot.capability_contract_digest.clone(),
            policy_revision: snapshot.policy_revision,
            revocation_epoch: snapshot.revocation_epoch,
            provenance: snapshot.provenance.clone(),
            arbitration: "strict-lockstep".into(),
            per_request_dual_witness: true,
            rust: engine_receipt(rust)?,
            lean: engine_receipt(lean)?,
            decision: decision.clone(),
        })?;
        if decision == "deny" {
            return Ok(AuthorizationResult {
                status: "denied".into(),
                receipt,
                grant: None,
            });
        }
        let issued_at_unix_ms: u64 = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map_err(|e| Error::new("authority-clock-invalid", e.to_string()))?
            .as_millis()
            .try_into()
            .map_err(|_| Error::new("authority-clock-invalid", "timestamp overflow"))?;
        let expires_at_unix_ms = issued_at_unix_ms
            .checked_add(self.deployment.grant_lifetime_ms)
            .ok_or_else(|| Error::new("authority-clock-invalid", "timestamp overflow"))?;
        let grant = self.sign(Grant {
            schema_id: "agentic-ai-lab.cedar-runtime-grant.v1".into(),
            grant_id: grant_id.clone(),
            authority_id: snapshot.authority_id.clone(),
            authority_instance: self.instance.clone(),
            issuer_public_key: self.public_key(),
            decision_receipt_digest: canonical::digest(
                "agentic-ai-lab/cedar/decision-receipt",
                &receipt,
            )?,
            subject: prepared.subject,
            policy_input_digest: prepared.policy_input_digest,
            runtime_context_id: snapshot.runtime_context_id.clone(),
            runtime_generation: snapshot.runtime_generation,
            runtime_bundle_digest: snapshot.runtime_bundle_digest.clone(),
            profile_bundle_digest: snapshot.profile_bundle_digest.clone(),
            capability_contract_digest: snapshot.capability_contract_digest.clone(),
            policy_revision: snapshot.policy_revision,
            revocation_epoch: snapshot.revocation_epoch,
            intent_digest: proposal.intent_digest,
            handoff_digest: canonical::digest("agentic-ai-lab/cedar/runtime-handoff", &proposal.handoff)?,
            action: prepared.action,
            event_kind: prepared.event_kind,
            nonce: [
                u64::from_be_bytes(id_bytes[..8].try_into().unwrap()),
                u64::from_be_bytes(id_bytes[8..].try_into().unwrap()),
            ],
            issued_at_unix_ms,
            expires_at_unix_ms,
        })?;
        self.pending.insert(
            grant_id,
            Pending {
                digest: canonical::digest("agentic-ai-lab/cedar/grant", &grant)?,
                deadline: Instant::now() + Duration::from_millis(self.deployment.grant_lifetime_ms),
            },
        );
        Ok(AuthorizationResult {
            status: "authorized".into(),
            receipt,
            grant: Some(grant),
        })
    }

    /// Native control-plane consumption also binds the complete re-projected
    /// Cedar request, not only the effect fields required by the runtime ABI.
    pub fn consume_proposal(
        &mut self,
        grant: Signed<Grant>,
        proposal: Proposal,
    ) -> Result<ConsumedHandoff> {
        self.ensure_live()?;
        verify_signature(&self.public_key(), &grant)?;
        let prepared = self.snapshot.prepare(&proposal)?;
        if grant.payload.subject != prepared.subject
            || grant.payload.policy_input_digest != prepared.policy_input_digest
        {
            return Err(Error::new(
                "grant-request-binding-mismatch",
                "native request differs from the evaluated request",
            ));
        }
        let current = &self.snapshot.bootstrap;
        self.consume(ConsumeRequest {
            grant,
            runtime_context_id: current.runtime_context_id.clone(),
            runtime_generation: current.runtime_generation,
            runtime_bundle_digest: current.runtime_bundle_digest.clone(),
            bundle_epoch: current.bundle_epoch,
            action: proposal.action,
            intent_digest: proposal.intent_digest,
            handoff: proposal.handoff,
        })
    }

    pub fn consume(&mut self, request: ConsumeRequest) -> Result<ConsumedHandoff> {
        self.ensure_live()?;
        let payload = request.handoff.validate()?;
        verify_signature(&self.public_key(), &request.grant)?;
        let grant = &request.grant.payload;
        let current = &self.snapshot.bootstrap;
        if grant.schema_id != "agentic-ai-lab.cedar-runtime-grant.v1"
            || grant.authority_instance != self.instance
            || grant.authority_id != current.authority_id
            || grant.issuer_public_key != self.public_key()
        {
            return Err(Error::new(
                "grant-authority-mismatch",
                "grant belongs to another authority instance",
            ));
        }
        if grant.revocation_epoch != current.revocation_epoch
            || grant.policy_revision != current.policy_revision
        {
            return Err(Error::new(
                "grant-revoked",
                "policy or revocation epoch changed",
            ));
        }
        if grant.runtime_context_id != current.runtime_context_id
            || request.runtime_context_id != current.runtime_context_id
            || grant.runtime_generation != current.runtime_generation
            || request.runtime_generation != current.runtime_generation
            || grant.runtime_bundle_digest != current.runtime_bundle_digest
            || request.runtime_bundle_digest != current.runtime_bundle_digest
            || grant.subject.epoch != current.bundle_epoch
            || request.bundle_epoch != current.bundle_epoch
        {
            return Err(Error::new(
                "grant-runtime-binding-mismatch",
                "context, generation, bundle, or epoch changed",
            ));
        }
        if grant.action != request.action
            || grant.intent_digest != request.intent_digest
            || grant.handoff_digest
                != canonical::digest("agentic-ai-lab/cedar/runtime-handoff", &request.handoff)?
        {
            return Err(Error::new(
                "grant-effect-binding-mismatch",
                "action, intent, or exact handoff changed",
            ));
        }
        let pending = self.pending.get(&grant.grant_id).ok_or_else(|| {
            Error::new(
                "grant-consumed-or-unknown",
                "grant has no unconsumed issuance",
            )
        })?;
        if pending.deadline <= Instant::now() {
            self.pending.remove(&grant.grant_id);
            return Err(Error::new(
                "grant-expired",
                "monotonic validity window expired",
            ));
        }
        if pending.digest != canonical::digest("agentic-ai-lab/cedar/grant", &request.grant)? {
            return Err(Error::new(
                "grant-issuance-mismatch",
                "receipt differs from the actual issuance",
            ));
        }
        // Commit before external execution. Runtime failure never reopens this
        // nonce; recovery must obtain a fresh, newly evaluated authorization.
        self.pending.remove(&grant.grant_id);
        Ok(ConsumedHandoff {
            schema_id: "agentic-ai-lab.cedar-consumed-handoff.v1",
            grant_id: grant.grant_id.clone(),
            nonce: grant.nonce,
            event_kind: grant.event_kind,
            payload_digest: canonical::raw_digest(&payload),
            handoff: request.handoff,
        })
    }

    pub fn revoke(&mut self, next_epoch: u64) -> Result<()> {
        self.ensure_live()?;
        if next_epoch <= self.snapshot.bootstrap.revocation_epoch {
            return Err(Error::new(
                "revocation-epoch-invalid",
                "epoch must increase",
            ));
        }
        self.snapshot.bootstrap.revocation_epoch = next_epoch;
        self.pending.clear();
        Ok(())
    }

    pub fn close(&mut self) {
        self.closed = true;
        self.pending.clear();
    }
}
