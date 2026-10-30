// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
//
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

//! POO-owned projections crossing the existing native Gerbil bridge.
//!
//! Application callers construct Gerbil POO objects. Only their explicit
//! runtime projection is encoded; there is no JSON RPC server or gxi fallback.

mod artifact;

use cedar_poo_bridge::ValidatedManifest;
use gerbil_scheme::{GerbilRuntime, LinkedStringExport};
use agentic_ai_lab_cedar_authority::authority::{
    Authority, AuthorityInfo, AuthorizationResult, ConsumedHandoff, Grant, Signed,
};
use agentic_ai_lab_cedar_authority::projection::{Bootstrap, Proposal};
use agentic_ai_lab_cedar_authority::runtime::Deployment;
use agentic_ai_lab_cedar_authority::{Error, Result, canonical};
use serde::de::DeserializeOwned;

/// Runtime-bound authorization owner. Native projections remain borrowed from
/// the same one-shot Gerbil runtime, and grants remain opaque signed values.
pub struct NativeAuthority<'runtime> {
    authority: Authority,
    _runtime: &'runtime GerbilRuntime,
}

impl<'runtime> NativeAuthority<'runtime> {
    /// Administrative bootstrap; signer material is never a request field.
    pub fn new(
        runtime: &'runtime GerbilRuntime,
        snapshot: &LinkedStringExport<'runtime>,
        deployment: Deployment,
        signer_seed: [u8; 32],
    ) -> Result<Self> {
        let bootstrap: Bootstrap = read_projection(snapshot)?;
        Ok(Self {
            authority: Authority::new(bootstrap, deployment, signer_seed)?,
            _runtime: runtime,
        })
    }

    /// Admit a Lean/Cedar candidate only when the Gerbil POO authority
    /// snapshot projects the same identified policies, schema, and entities.
    /// The artifact cannot supply provenance or replace the POO snapshot.
    pub fn new_with_validated_case(
        runtime: &'runtime GerbilRuntime,
        snapshot: &LinkedStringExport<'runtime>,
        manifest: &ValidatedManifest,
        case_name: &str,
        deployment: Deployment,
        signer_seed: [u8; 32],
    ) -> Result<Self> {
        let bootstrap: Bootstrap = read_projection(snapshot)?;
        artifact::ensure_matches_poo_snapshot(&bootstrap, manifest, case_name)?;
        Ok(Self {
            authority: Authority::new(bootstrap, deployment, signer_seed)?,
            _runtime: runtime,
        })
    }

    pub fn info(&self) -> AuthorityInfo {
        self.authority.info()
    }

    pub fn issue(&mut self, request: &LinkedStringExport<'runtime>) -> Result<AuthorizationResult> {
        self.authority.issue(read_projection::<Proposal>(request)?)
    }

    /// Re-project the POO request and consume exactly the effect signed by the
    /// grant. Runtime identity is obtained from this owner, not caller flags.
    pub fn consume(
        &mut self,
        grant: Signed<Grant>,
        request: &LinkedStringExport<'runtime>,
    ) -> Result<ConsumedHandoff> {
        let proposal: Proposal = read_projection(request)?;
        self.authority.consume_proposal(grant, proposal)
    }

    pub fn revoke(&mut self, epoch: u64) -> Result<()> {
        self.authority.revoke(epoch)
    }
    pub fn close(&mut self) {
        self.authority.close();
    }
}

fn read_projection<T: DeserializeOwned>(export: &LinkedStringExport<'_>) -> Result<T> {
    let root = export.call().into_result().map_err(native_error)?;
    let length = root.len().into_result().map_err(native_error)?;
    if length > 1024 * 1024 {
        return Err(Error::new(
            "native-projection-budget-exceeded",
            "projection exceeds 1 MiB characters",
        ));
    }
    let projection = root.to_string().into_result().map_err(native_error)?;
    canonical::parse(projection.as_bytes())
}

fn native_error(error: gerbil_scheme::NativeError) -> Error {
    Error::new("gerbil-native-projection-failed", error.to_string())
}
