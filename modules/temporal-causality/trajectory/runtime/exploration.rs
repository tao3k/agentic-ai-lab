//! Read-only, open-world attempt comparison. Unknown inputs never imply equality.
use super::State;
use crate::{Data, Result};
use std::collections::BTreeMap;

const PREMISES: [&str; 6] = [
    "questionIdentity",
    "scopeIdentity",
    "operationIdentity",
    "inputIdentity",
    "toolIdentity",
    "modelIdentity",
];

impl State {
    pub(super) fn brief(&self, observed: Option<&Data>, owner: u64) -> Result<Data> {
        let mut change_kinds = Vec::new();
        let status = if let Some(previous) = observed {
            if previous.field("schema")?.text()? != "ascent.trajectory-brief.v1"
                || *previous.field("ownerIdentity")?.natural()? != owner.into()
            {
                return Err(crate::invalid_data(
                    "brief belongs to another owner or schema",
                ));
            }
            let count = previous.field("eventCount")?.natural()?;
            let count = usize::try_from(count)
                .map_err(|_| crate::invalid_data("brief event count exceeds history"))?;
            if count > self.events.len()
                || previous.field("prefixIdentity")?.text()?
                    != Data::digest_slice(&self.events[..count])
            {
                return Err(crate::invalid_data(
                    "brief prefix differs from retained history",
                ));
            }
            for event in &self.events[count..] {
                let kind = event.field("kind")?.clone();
                if !change_kinds.contains(&kind) {
                    change_kinds.push(kind);
                }
            }
            if previous.field("sourceIdentity")?.text()? != self.source
                || *previous.field("generation")?.natural()? != self.generation.into()
            {
                change_kinds.push("source-replacement".into());
            }
            if change_kinds.is_empty() {
                "unchanged"
            } else {
                "changed"
            }
        } else {
            "unread"
        };
        Ok(Data::object([
            ("schema", "ascent.trajectory-brief.v1".into()),
            ("ownerIdentity", owner.into()),
            ("sourceIdentity", self.source.clone().into()),
            ("generation", self.generation.into()),
            ("eventCount", self.events.len().into()),
            ("prefixIdentity", Data::digest_slice(&self.events).into()),
            ("status", status.into()),
            ("changeKinds", Data::List(change_kinds)),
            (
                "readSurfaces",
                Data::List(vec![
                    "context".into(),
                    "explore".into(),
                    "focus".into(),
                    "exact-prefix".into(),
                    "snapshot".into(),
                ]),
            ),
            ("executionAuthorized", false.into()),
            ("actionSelected", false.into()),
        ]))
    }

    pub(super) fn context(&self) -> Result<Data> {
        let attempts = self
            .events
            .iter()
            .filter_map(|event| self.context_attempt(event).transpose())
            .collect::<Result<Vec<_>>>()?;
        Ok(Data::object([
            ("schema", "ascent.trajectory-context.v1".into()),
            ("sourceIdentity", self.source.clone().into()),
            ("generation", self.generation.into()),
            ("eventCount", self.events.len().into()),
            ("prefixIdentity", Data::digest_slice(&self.events).into()),
            ("attempts", Data::List(attempts)),
            ("executionAuthorized", false.into()),
            ("actionSelected", false.into()),
        ]))
    }

    fn context_attempt(&self, event: &Data) -> Result<Option<Data>> {
        if event.field("kind")?.text()? != "attempt" {
            return Ok(None);
        }
        let premises = PREMISES
            .into_iter()
            .chain(["proposalIdentity", "purpose"])
            .filter_map(|key| event.get(key).map(|value| (key.into(), value.clone())))
            .collect::<BTreeMap<_, _>>();
        Ok(Some(Data::object([
            ("earlierEvent", event.field("id")?.clone()),
            ("generation", event.field("generation")?.clone()),
            (
                "historical",
                (event.field("generation")?.natural()? != &self.generation.into()).into(),
            ),
            ("premises", Data::Map(premises)),
        ])))
    }

    pub(super) fn explore(&self, candidate: &Data) -> Result<Data> {
        validate_candidate(candidate)?;
        let comparisons = self
            .events
            .iter()
            .filter_map(|earlier| self.compare_attempt(earlier, candidate).transpose())
            .collect::<Result<Vec<_>>>()?;
        Ok(Data::object([
            ("schema", "ascent.trajectory-exploration.v1".into()),
            ("sourceIdentity", self.source.clone().into()),
            ("generation", self.generation.into()),
            ("eventCount", self.events.len().into()),
            ("prefixIdentity", Data::digest_slice(&self.events).into()),
            ("comparisons", Data::List(comparisons)),
            ("executionAuthorized", false.into()),
            ("actionSelected", false.into()),
        ]))
    }

    pub(super) fn focus(
        &self,
        candidate: &Data,
        observed: Option<&Data>,
        owner: u64,
    ) -> Result<Data> {
        validate_candidate(candidate)?;
        let candidate_identity = Data::digest_slice(std::slice::from_ref(candidate));
        let (start, source_changed) = if let Some(previous) = observed {
            if previous.field("schema")?.text()? != "ascent.trajectory-focus.v1"
                || *previous.field("ownerIdentity")?.natural()? != owner.into()
                || previous.field("candidateIdentity")?.text()? != candidate_identity
            {
                return Err(crate::invalid_data(
                    "focus belongs to another owner or candidate",
                ));
            }
            let count = usize::try_from(previous.field("eventCount")?.natural()?)
                .map_err(|_| crate::invalid_data("focus event count exceeds history"))?;
            if count > self.events.len()
                || previous.field("prefixIdentity")?.text()?
                    != Data::digest_slice(&self.events[..count])
            {
                return Err(crate::invalid_data(
                    "focus prefix differs from retained history",
                ));
            }
            let changed = previous.field("sourceIdentity")?.text()? != self.source
                || *previous.field("generation")?.natural()? != self.generation.into();
            let tail_only = !changed
                && self.events[count..].iter().all(|event| {
                    event
                        .field("kind")
                        .and_then(Data::text)
                        .is_ok_and(|kind| kind == "attempt")
                });
            (if tail_only { count } else { 0 }, changed)
        } else {
            (0, false)
        };
        let comparisons = self.events[start..]
            .iter()
            .filter_map(|earlier| self.compare_attempt(earlier, candidate).transpose())
            .collect::<Result<Vec<_>>>()?;
        let status = if observed.is_none() {
            "unread"
        } else if source_changed || !comparisons.is_empty() {
            "changed"
        } else {
            "unchanged"
        };
        Ok(Data::object([
            ("schema", "ascent.trajectory-focus.v1".into()),
            ("ownerIdentity", owner.into()),
            ("sourceIdentity", self.source.clone().into()),
            ("generation", self.generation.into()),
            ("eventCount", self.events.len().into()),
            ("prefixIdentity", Data::digest_slice(&self.events).into()),
            ("candidateIdentity", candidate_identity.into()),
            ("status", status.into()),
            ("comparisons", Data::List(comparisons)),
            ("executionAuthorized", false.into()),
            ("actionSelected", false.into()),
        ]))
    }

    pub(super) fn exact_prefix(&self, through: usize, identity: &str, owner: u64) -> Result<Data> {
        if through > self.events.len() || Data::digest_slice(&self.events[..through]) != identity {
            return Err(crate::invalid_data(
                "exact prefix differs from retained history",
            ));
        }
        let (source, generation) = if through == 0 {
            (
                self.events
                    .first()
                    .map(|event| event.field("sourceIdentity").and_then(Data::text))
                    .transpose()?
                    .unwrap_or(&self.source)
                    .to_owned(),
                0,
            )
        } else {
            let last = &self.events[through - 1];
            let invalidated = last.field("kind")?.text()? == "invalidate";
            let source = last
                .field(if invalidated {
                    "nextSourceIdentity"
                } else {
                    "sourceIdentity"
                })?
                .text()?
                .to_owned();
            let generation = last.field("generation")?.natural()?;
            let generation = usize::try_from(generation)
                .map_err(|_| crate::invalid_data("exact prefix generation exceeds range"))?
                + usize::from(invalidated);
            (source, generation)
        };
        Ok(Data::object([
            ("schema", "ascent.trajectory-exact-prefix.v1".into()),
            ("ownerIdentity", owner.into()),
            ("sourceIdentity", source.into()),
            ("generation", generation.into()),
            ("eventCount", through.into()),
            ("prefixIdentity", identity.into()),
            ("events", Data::List(self.events[..through].to_vec())),
            ("executionAuthorized", false.into()),
            ("actionSelected", false.into()),
        ]))
    }

    fn compare_attempt(&self, earlier: &Data, candidate: &Data) -> Result<Option<Data>> {
        if earlier.field("kind")?.text()? != "attempt"
            || earlier.field("questionIdentity")? != candidate.field("questionIdentity")?
        {
            return Ok(None);
        }
        let historical = *earlier.field("generation")?.natural()? != self.generation.into();
        let (changed, unknown) = changed_premises(earlier, candidate);
        let relation = if historical {
            "historical"
        } else if !changed.is_empty() {
            "changed-premise"
        } else if !unknown.is_empty() {
            "comparison-unknown"
        } else {
            "exact-current"
        };
        let reference = if historical {
            Data::Bool(false)
        } else {
            self.checked_reference(earlier, candidate)
        };
        Ok(Some(Data::object([
            ("earlierEvent", earlier.field("id")?.clone()),
            ("relation", relation.into()),
            ("changedPremises", Data::List(changed)),
            ("unknownPremises", Data::List(unknown)),
            ("currentEvidenceReference", reference),
        ])))
    }

    fn checked_reference(&self, earlier: &Data, candidate: &Data) -> Data {
        earlier
            .get("resultReference")
            .filter(|value| {
                value.identity().is_ok_and(|id| {
                    self.verified_references.contains(id)
                        && earlier.get("contractIdentity") == candidate.get("contractIdentity")
                        && self.consumed.get(id).is_some_and(|contract| {
                            earlier.get("contractIdentity") == Some(&Data::from(contract.as_str()))
                        })
                })
            })
            .cloned()
            .unwrap_or(Data::Bool(false))
    }
}

fn validate_candidate(candidate: &Data) -> Result<()> {
    for key in ["questionIdentity", "operationIdentity", "inputIdentity"] {
        candidate.field(key)?.identity()?;
    }
    for key in PREMISES.into_iter().chain(["contractIdentity"]) {
        if let Some(value) = candidate.get(key) {
            value.identity()?;
        }
    }
    Ok(())
}

fn changed_premises(earlier: &Data, candidate: &Data) -> (Vec<Data>, Vec<Data>) {
    let mut changed = Vec::new();
    let mut unknown = Vec::new();
    for key in PREMISES {
        match (earlier.get(key), candidate.get(key)) {
            (Some(left), Some(right)) if left != right => changed.push(key.into()),
            (None, _) | (_, None) => unknown.push(key.into()),
            _ => {}
        }
    }
    (changed, unknown)
}
