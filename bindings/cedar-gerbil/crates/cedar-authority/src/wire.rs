// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! The three-field AuthorizationRequest matches the pinned Cedar specification.
use crate::{Error, Result};
use cedar_policy::{Authorizer, Decision, Entities, PolicySet, Request};
use prost::Message;
use serde::{Deserialize, Serialize};

pub const CEDAR_VERSION: &str = "4.12.0";
pub const LEAN_REVISION: &str = "e9fa9c1e6b636f29b0897d8706bd7aa5eaf06f9a";
pub const OUTCOME_SCHEMA: &str = "agentic-ai-lab.cedar-engine-outcome.v1";

#[derive(Clone, PartialEq, Message)]
pub struct AuthorizationRequest {
    #[prost(message, optional, tag = "1")]
    pub request: Option<cedar_policy::proto::models::Request>,
    #[prost(message, optional, tag = "2")]
    pub policies: Option<cedar_policy::proto::models::PolicySet>,
    #[prost(message, optional, tag = "3")]
    pub entities: Option<cedar_policy::proto::models::Entities>,
}

impl AuthorizationRequest {
    pub fn encode(request: &Request, policies: &PolicySet, entities: &Entities) -> Vec<u8> {
        Self {
            request: Some(request.into()),
            policies: Some(policies.into()),
            entities: Some(entities.into()),
        }
        .encode_to_vec()
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Outcome {
    pub schema_id: String,
    pub engine_id: String,
    pub semantic_revision: String,
    pub decision: String,
    pub determining_policies: Vec<String>,
    pub erroring_policies: Vec<String>,
}

impl Outcome {
    pub fn validate(&mut self, engine_id: &str, revision: &str) -> Result<()> {
        if self.schema_id != OUTCOME_SCHEMA
            || self.engine_id != engine_id
            || self.semantic_revision != revision
        {
            return Err(Error::new("engine-identity-mismatch", engine_id));
        }
        if !matches!(self.decision.as_str(), "allow" | "deny") {
            return Err(Error::new("engine-outcome-malformed", "unknown decision"));
        }
        for ids in [&mut self.determining_policies, &mut self.erroring_policies] {
            ids.sort();
            if ids.windows(2).any(|pair| pair[0] == pair[1]) || ids.iter().any(String::is_empty) {
                return Err(Error::new(
                    "engine-outcome-malformed",
                    "duplicate or empty policy identity",
                ));
            }
        }
        if self
            .determining_policies
            .iter()
            .any(|id| self.erroring_policies.contains(id))
        {
            return Err(Error::new(
                "engine-outcome-malformed",
                "determining and erroring identities overlap",
            ));
        }
        if self.decision == "allow" && self.determining_policies.is_empty() {
            return Err(Error::new(
                "engine-outcome-malformed",
                "allow requires an explicit determining policy",
            ));
        }
        Ok(())
    }

    pub fn agrees_with(&self, other: &Self) -> bool {
        self.decision == other.decision
            && self.determining_policies == other.determining_policies
            && self.erroring_policies == other.erroring_policies
    }
}

fn decode_input(bytes: &[u8]) -> Result<(Request, PolicySet, Entities)> {
    let wire = AuthorizationRequest::decode(bytes)
        .map_err(|e| Error::new("cedar-input-invalid", e.to_string()))?;
    let request = Request::try_from(
        wire.request
            .ok_or_else(|| Error::new("cedar-input-invalid", "request absent"))?,
    )
    .map_err(|e| Error::new("cedar-input-invalid", e.to_string()))?;
    let policies = PolicySet::try_from(
        wire.policies
            .ok_or_else(|| Error::new("cedar-input-invalid", "policies absent"))?,
    )
    .map_err(|e| Error::new("cedar-input-invalid", e.to_string()))?;
    let entities = Entities::try_from(
        wire.entities
            .ok_or_else(|| Error::new("cedar-input-invalid", "entities absent"))?,
    )
    .map_err(|e| Error::new("cedar-input-invalid", e.to_string()))?;
    Ok((request, policies, entities))
}

/// Admission before an independent Runtime may pass bytes to either engine.
pub fn validate_native_input(bytes: &[u8]) -> Result<()> {
    decode_input(bytes).map(drop)
}

pub fn evaluate_rust(bytes: &[u8]) -> Result<Outcome> {
    let (request, policies, entities) = decode_input(bytes)?;
    let response = Authorizer::new().is_authorized(&request, &policies, &entities);
    let mut outcome = Outcome {
        schema_id: OUTCOME_SCHEMA.into(),
        engine_id: "cedar-rust".into(),
        semantic_revision: CEDAR_VERSION.into(),
        decision: match response.decision() {
            Decision::Allow => "allow",
            Decision::Deny => "deny",
        }
        .into(),
        determining_policies: response
            .diagnostics()
            .reason()
            .map(ToString::to_string)
            .collect(),
        erroring_policies: response
            .diagnostics()
            .errors()
            .map(|e| match e {
                cedar_policy::AuthorizationError::PolicyEvaluationError(e) => {
                    e.policy_id().to_string()
                }
            })
            .collect(),
    };
    outcome.validate("cedar-rust", CEDAR_VERSION)?;
    Ok(outcome)
}
