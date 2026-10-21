//! Ordered, atomic source-qualified observations, independent from model interpretation.
use crate::{Data, Engine, Error, Result, invalid_data as invalid};
use num_bigint::BigInt;
use std::{
    collections::{BTreeMap, BTreeSet},
    sync::{
        Arc,
        atomic::{AtomicU64, AtomicUsize, Ordering},
    },
};
static NEXT: AtomicU64 = AtomicU64::new(1);
#[derive(Clone)]
pub(crate) struct State {
    task: String,
    pub source: String,
    pub generation: u64,
    pub round: BigInt,
    pub events: Vec<Data>,
    pub seen: BTreeMap<String, String>,
    pub references: BTreeSet<String>,
    pub verified_references: BTreeSet<String>,
    pub failures: BTreeSet<String>,
    pub last_failure: Option<String>,
    pub consumed: BTreeMap<String, String>,
    pub totals: Data,
    pub first: Data,
    pub epochs: Vec<Data>,
}
pub(crate) fn totals() -> Data {
    let counts = [
        "modelCalls",
        "inputTokens",
        "outputTokens",
        "thinkingTokens",
        "repairModelCalls",
        "repairThinkingTokens",
        "failedVerifications",
        "directAnswers",
        "evidenceEvents",
        "checkpoints",
        "supportedBranches",
        "contradictedBranches",
        "unknownBranches",
    ];
    let flags = [
        "usageComplete",
        "thinkingComplete",
        "repairThinkingComplete",
    ];
    Data::Map(
        counts
            .into_iter()
            .map(|k| (k.into(), Data::Integer(0.into())))
            .chain(flags.into_iter().map(|k| (k.into(), Data::Bool(true))))
            .collect(),
    )
}
pub(crate) fn set(value: &mut Data, key: &str, item: Data) -> Result<()> {
    let Data::Map(fields) = value else {
        return Err(invalid("ledger object required"));
    };
    fields.insert(key.into(), item);
    Ok(())
}
pub(crate) fn add(stats: &mut Data, key: &str, value: &BigInt) -> Result<()> {
    let total = stats.field(key)?.natural()? + value;
    set(stats, key, Data::Integer(total))
}
pub(crate) fn increment(stats: &mut Data, key: &str) -> Result<()> {
    add(stats, key, &1.into())
}
struct Permit(Arc<AtomicUsize>);
impl Drop for Permit {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::Relaxed);
    }
}
/// Rust-owned source epochs and provider usage. Observations confer no execution permission.
pub struct Trajectory {
    engine: Engine,
    permit: Option<Permit>,
    handle: u64,
    state: State,
    closed: Option<Data>,
}
impl Trajectory {
    /// # Errors
    /// Rejects empty identities, a closed engine, or 64 live trajectory owners.
    pub fn new(engine: &Engine, task: &str, source: &str) -> Result<Self> {
        engine.check()?;
        if task.is_empty() || source.is_empty() {
            return Err(invalid("task/source identities required"));
        }
        engine
            .trajectory_owners
            .try_update(Ordering::Relaxed, Ordering::Relaxed, |n| {
                (n < 64).then_some(n + 1)
            })
            .map_err(|_| invalid("trajectory owner capacity"))?;
        let permit = Permit(engine.trajectory_owners.clone());
        let handle = NEXT
            .try_update(Ordering::Relaxed, Ordering::Relaxed, |n| n.checked_add(1))
            .map_err(|_| invalid("trajectory identity exhausted"))?;
        Ok(Self {
            engine: engine.clone(),
            permit: Some(permit),
            handle,
            closed: None,
            state: State {
                task: task.into(),
                source: source.into(),
                generation: 0,
                round: 0.into(),
                events: Vec::new(),
                seen: BTreeMap::new(),
                references: BTreeSet::new(),
                verified_references: BTreeSet::new(),
                failures: BTreeSet::new(),
                last_failure: None,
                consumed: BTreeMap::new(),
                totals: totals(),
                first: Data::Bool(false),
                epochs: Vec::new(),
            },
        })
    }
    #[must_use]
    pub fn handle(&self) -> u64 {
        self.handle
    }
    #[must_use]
    pub fn source_identity(&self) -> &str {
        &self.state.source
    }
    #[must_use]
    pub fn is_closed(&self) -> bool {
        self.closed.is_some()
    }
    /// Validate an observed call before a downstream tool starts any native query.
    /// # Errors
    /// Rejects revoked owners and calls absent from the current observation history.
    pub fn require_model_call(&self, call: &str) -> Result<()> {
        self.engine.check()?;
        if self.closed.is_some() {
            return Err(Error::Closed);
        }
        if self
            .state
            .seen
            .get(&format!("call:{call}"))
            .map(String::as_str)
            != Some("model-call")
        {
            return Err(invalid("checkpoint needs an observed model call"));
        }
        Ok(())
    }
    /// # Errors
    /// Rejects stale/invalid events atomically, without charging counters or reusing IDs.
    pub fn append(&mut self, supplied: Data) -> Result<Data> {
        self.append_batch(&[supplied])
    }
    /// Admit related receipts and their checkpoint as one transaction.
    /// # Errors
    /// Rejects the entire batch if any event is stale, malformed or exceeds capacity.
    pub fn append_batch(&mut self, supplied: &[Data]) -> Result<Data> {
        self.engine.check()?;
        if self.closed.is_some() {
            return Err(Error::Closed);
        }
        let mut next = self.state.clone();
        for event in supplied {
            next.apply(event.clone())?;
        }
        self.state = next;
        self.observation(false, false, None)
    }
    /// # Errors
    /// Rejects a closed engine for live ledgers; closed snapshots remain plain owned data.
    pub fn snapshot(&self) -> Result<Data> {
        if let Some(snapshot) = &self.closed {
            return Ok(snapshot.clone());
        }
        self.engine.check()?;
        self.observation(true, false, None)
    }
    /// Describe comparable prior attempts without authorizing or selecting work.
    /// # Errors
    /// Rejects a closed owner or a malformed candidate; never changes the ledger.
    pub fn explore(&self, candidate: &Data) -> Result<Data> {
        self.engine.check()?;
        if self.closed.is_some() {
            return Err(Error::Closed);
        }
        let mut packet = self.state.explore(candidate)?;
        set(&mut packet, "ownerIdentity", self.handle.into())?;
        Ok(packet)
    }
    /// Inspect retained attempt premises without choosing a candidate or exposing results.
    /// # Errors
    /// Rejects a closed owner; never changes the ledger.
    pub fn context(&self) -> Result<Data> {
        self.engine.check()?;
        if self.closed.is_some() {
            return Err(Error::Closed);
        }
        let mut packet = self.state.context()?;
        set(&mut packet, "ownerIdentity", self.handle.into())?;
        Ok(packet)
    }
    /// Return a small read index; an observed brief must bind this owner's retained prefix.
    /// No attempt payload or result reference is included.
    /// # Errors
    /// Rejects a closed owner or a foreign, malformed, or divergent observed brief.
    pub fn brief(&self, observed: Option<&Data>) -> Result<Data> {
        self.engine.check()?;
        if self.closed.is_some() {
            return Err(Error::Closed);
        }
        self.state.brief(observed, self.handle)
    }
    /// Compare one caller-chosen candidate against only relevant changes to an observed view.
    /// # Errors
    /// Rejects a closed owner or a foreign, malformed, or divergent observed view.
    pub fn focus(&self, candidate: &Data, observed: Option<&Data>) -> Result<Data> {
        self.engine.check()?;
        if self.closed.is_some() {
            return Err(Error::Closed);
        }
        self.state.focus(candidate, observed, self.handle)
    }
    /// Read a named retained event prefix; this does not review its result references.
    /// # Errors
    /// Rejects a closed owner or a count/identity mismatch.
    pub fn exact_prefix(&self, through: usize, identity: &str) -> Result<Data> {
        self.engine.check()?;
        if self.closed.is_some() {
            return Err(Error::Closed);
        }
        self.state.exact_prefix(through, identity, self.handle)
    }
    /// Check whether an immutable advice packet still names this exact ledger revision.
    /// This does not review underlying evidence or grant execution permission.
    /// # Errors
    /// Rejects a closed engine or malformed packet.
    pub fn exploration_current(&self, packet: &Data) -> Result<bool> {
        self.engine.check()?;
        if self.closed.is_some() {
            return Ok(false);
        }
        Ok(matches!(
            packet.field("schema")?.text()?,
            "ascent.trajectory-exploration.v1"
                | "ascent.trajectory-context.v1"
                | "ascent.trajectory-brief.v1"
                | "ascent.trajectory-focus.v1"
                | "ascent.trajectory-exact-prefix.v1"
        ) && *packet.field("ownerIdentity")?.natural()? == self.handle.into()
            && packet.field("sourceIdentity")?.text()? == self.state.source
            && *packet.field("generation")?.natural()? == self.state.generation.into()
            && *packet.field("eventCount")?.natural()? == self.state.events.len().into()
            && packet.field("prefixIdentity")?.text()? == Data::digest_slice(&self.state.events))
    }
    /// # Errors
    /// Rejects a closed engine; repeated closure returns the same detached observation.
    pub fn close(&mut self, reason: &str) -> Result<Data> {
        if let Some(snapshot) = &self.closed {
            return Ok(snapshot.clone());
        }
        self.engine.check()?;
        let result = self.observation(true, true, Some(reason))?;
        self.closed = Some(result.clone());
        self.permit.take();
        Ok(result)
    }
    fn observation(&self, events: bool, closed: bool, reason: Option<&str>) -> Result<Data> {
        let state = &self.state;
        let after = if matches!(state.first, Data::Bool(false)) {
            Data::Bool(false)
        } else {
            Data::object([
                (
                    "modelCalls",
                    Data::Integer(
                        state.totals.field("modelCalls")?.natural()?
                            - state.first.field("modelCalls")?.natural()?,
                    ),
                ),
                (
                    "thinkingTokens",
                    Data::Integer(
                        state.totals.field("thinkingTokens")?.natural()?
                            - state.first.field("thinkingTokens")?.natural()?,
                    ),
                ),
                (
                    "thinkingComplete",
                    state.totals.field("thinkingComplete")?.clone(),
                ),
            ])
        };
        let mut result = Data::object([
            ("schema", "ascent.trajectory.v1".into()),
            ("task", state.task.clone().into()),
            ("sourceIdentity", state.source.clone().into()),
            ("generation", state.generation.into()),
            ("eventCount", state.events.len().into()),
            ("totals", state.totals.clone()),
            ("throughFirstCorrect", state.first.clone()),
            ("postSuccess", after),
            (
                "verified",
                (!matches!(state.first, Data::Bool(false))).into(),
            ),
            ("closed", closed.into()),
            (
                "censored",
                (closed && matches!(state.first, Data::Bool(false))).into(),
            ),
            ("finishReason", reason.map_or(Data::Bool(false), Data::from)),
            ("completedEpochs", Data::List(state.epochs.clone())),
        ]);
        if events {
            set(&mut result, "events", Data::List(state.events.clone()))?;
        }
        Ok(result)
    }
}
