//! Validate a complete event on an unpublished epoch before admitting observations.
use super::{State, add, increment, set, totals};
use crate::{Data, Error, Result, invalid_data as invalid};
use std::collections::BTreeSet;
impl State {
    pub(super) fn apply(&mut self, mut event: Data) -> Result<()> {
        let id = event.field("id")?.identity()?.to_string();
        let kind = event.field("kind")?.identity()?.to_string();
        if self.seen.contains_key(&id) || self.events.len() >= 4096 {
            return Err(invalid("duplicate event or trajectory capacity"));
        }
        if event.field("sourceIdentity")?.text()? != self.source {
            return Err(invalid("stale trajectory event source"));
        }
        let round = event
            .get("round")
            .map_or(Ok(&self.round), Data::natural)?
            .clone();
        if round < self.round {
            return Err(invalid("trajectory round moved backwards"));
        }
        self.round.clone_from(&round);
        set(&mut event, "round", Data::Integer(round))?;
        if kind == "model-call"
            && event.get("repairOf").is_none()
            && let Some(failure) = &self.last_failure
        {
            set(&mut event, "repairOf", failure.clone().into())?;
        }
        let generation = self.generation;
        match kind.as_str() {
            "attempt" => self.attempt(&event)?,
            "model-call" => self.model(&event)?,
            "evidence" => self.evidence(&event)?,
            "direct-answer" => {
                self.reference(&event, "resultReference")?;
                increment(&mut self.totals, "directAnswers")?;
            }
            "checkpoint" => self.checkpoint(&event)?,
            "consumption" => self.consumption(&event)?,
            "verification" => self.verification(&event, &id)?,
            "invalidate" => self.invalidate(&event)?,
            _ => return Err(invalid("unknown trajectory event kind")),
        }
        set(&mut event, "sequence", (self.events.len() + 1).into())?;
        set(&mut event, "generation", generation.into())?;
        self.seen.insert(id, kind);
        self.events.push(event);
        Ok(())
    }
    fn attempt(&self, event: &Data) -> Result<()> {
        for key in ["questionIdentity", "operationIdentity", "inputIdentity"] {
            event.field(key)?.identity()?;
        }
        for key in [
            "scopeIdentity",
            "toolIdentity",
            "modelIdentity",
            "proposalIdentity",
            "purpose",
            "contractIdentity",
        ] {
            if let Some(value) = event.get(key) {
                value.identity()?;
            }
        }
        if event.get("resultReference").is_some() {
            self.reference(event, "resultReference")?;
            event.field("contractIdentity")?.identity()?;
        }
        Ok(())
    }
    fn reference(&self, event: &Data, key: &str) -> Result<String> {
        let reference = event.field(key)?.identity()?;
        if !self.references.contains(reference) {
            return Err(invalid("unknown or invalidated evidence reference"));
        }
        Ok(reference.into())
    }
    fn model(&mut self, event: &Data) -> Result<()> {
        let empty = Data::Map(std::collections::BTreeMap::default());
        let usage = event.get("usage").unwrap_or(&empty);
        usage.map()?;
        let repair = event
            .get("repairOf")
            .filter(|v| !matches!(v, Data::Bool(false) | Data::Null));
        if let Some(repair) = repair
            && !self.failures.contains(repair.identity()?)
        {
            return Err(invalid("repair needs a failed current-generation verdict"));
        }
        increment(&mut self.totals, "modelCalls")?;
        if repair.is_some() {
            increment(&mut self.totals, "repairModelCalls")?;
        }
        for key in ["inputTokens", "outputTokens", "thinkingTokens"] {
            match usage.get(key) {
                None | Some(Data::Bool(false) | Data::Null) => set(
                    &mut self.totals,
                    if key == "thinkingTokens" {
                        "thinkingComplete"
                    } else {
                        "usageComplete"
                    },
                    false.into(),
                )?,
                Some(value) => add(&mut self.totals, key, value.natural()?)?,
            }
        }
        if repair.is_some() {
            match usage.get("thinkingTokens") {
                Some(Data::Integer(n)) => add(&mut self.totals, "repairThinkingTokens", n)?,
                _ => set(&mut self.totals, "repairThinkingComplete", false.into())?,
            }
        }
        Ok(())
    }
    fn evidence(&mut self, event: &Data) -> Result<()> {
        let reference = event.field("resultReference")?.identity()?;
        event.field("pathIdentity")?.identity()?;
        self.references.insert(reference.into());
        increment(&mut self.totals, "evidenceEvents")
    }
    fn checkpoint(&mut self, event: &Data) -> Result<()> {
        let call = event.field("modelCall")?.identity()?;
        if self.seen.get(call).map(String::as_str) != Some("model-call") {
            return Err(invalid("checkpoint needs an observed model call"));
        }
        let branches = event.field("branches")?.list()?;
        if branches.len() > 128 {
            return Err(invalid("checkpoint branch capacity"));
        }
        let mut ids = BTreeSet::new();
        for branch in branches {
            let id = branch.field("id")?.identity()?;
            if !ids.insert(id) {
                return Err(invalid("distinct branch identities required"));
            }
            let key = match branch.field("status")?.text()? {
                "unknown" => "unknownBranches",
                "supported" => {
                    self.reference(branch, "resultReference")?;
                    "supportedBranches"
                }
                "contradicted" => {
                    self.reference(branch, "resultReference")?;
                    if branch.get("complete") != Some(&Data::Bool(true)) {
                        return Err(invalid("negative branch needs complete domain check"));
                    }
                    "contradictedBranches"
                }
                _ => return Err(invalid("invalid branch status")),
            };
            increment(&mut self.totals, key)?;
        }
        increment(&mut self.totals, "checkpoints")
    }
    fn consumption(&mut self, event: &Data) -> Result<()> {
        if let Some(interpretation) = event
            .get("interpretation")
            .filter(|v| !matches!(v, Data::Null | Data::Bool(false)))
        {
            if interpretation.field("scope")?.text()? != "model-interpreted" {
                return Err(invalid("interpretation scope"));
            }
            interpretation.field("utteranceIdentity")?.identity()?;
            interpretation.field("resolver")?.identity()?;
            if self
                .seen
                .get(interpretation.field("modelCall")?.identity()?)
                .map(String::as_str)
                != Some("model-call")
            {
                return Err(invalid("interpretation needs observed model call"));
            }
        }
        self.reference(event, "consumedReference")?;
        let reference = self.reference(event, "resultReference")?;
        event.field("intentIdentity")?.identity()?;
        let contract = event.field("contractIdentity")?.identity()?;
        self.consumed.insert(reference, contract.into());
        Ok(())
    }
    fn verification(&mut self, event: &Data, id: &str) -> Result<()> {
        event.field("verifier")?.identity()?;
        let correct = event.field("correct")?.boolean()?;
        let scope = event
            .get("scope")
            .map(Data::text)
            .transpose()?
            .unwrap_or("task");
        if !matches!(scope, "task" | "subgoal") {
            return Err(invalid("invalid verification scope"));
        }
        if let Some(reference) = event
            .get("consumptionReference")
            .filter(|v| !matches!(v, Data::Null | Data::Bool(false)))
        {
            let reference = reference.identity()?;
            if !self.consumed.contains_key(reference) {
                return Err(invalid("verification needs admitted consumption reference"));
            }
            if correct {
                self.verified_references.insert(reference.into());
            } else {
                self.verified_references.remove(reference);
            }
        }
        self.last_failure = (!correct).then(|| id.to_string());
        if !correct {
            self.failures.insert(id.into());
            increment(&mut self.totals, "failedVerifications")?;
        } else if scope == "task" && matches!(self.first, Data::Bool(false)) {
            self.first = self.totals.clone();
            set(&mut self.first, "event", id.into())?;
            set(&mut self.first, "round", Data::Integer(self.round.clone()))?;
        }
        Ok(())
    }
    fn invalidate(&mut self, event: &Data) -> Result<()> {
        let next = event.field("nextSourceIdentity")?.identity()?.to_string();
        self.epochs.push(Data::object([
            ("sourceIdentity", self.source.clone().into()),
            ("generation", self.generation.into()),
            ("totals", self.totals.clone()),
            ("throughFirstCorrect", self.first.clone()),
        ]));
        self.generation = self.generation.checked_add(1).ok_or(Error::StateLimit)?;
        self.source = next;
        self.references.clear();
        self.verified_references.clear();
        self.failures.clear();
        self.last_failure = None;
        self.consumed.clear();
        self.totals = totals();
        self.first = false.into();
        self.round = 0.into();
        Ok(())
    }
}
