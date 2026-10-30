//! Predicate completion and current path references are owned by the native library.
use super::registry::{EvidenceOperation, Registry, ground};
use crate::{
    Data, Engine, EvidenceChain, FactLimits, Result, evidence_store::put, invalid_data as invalid,
};
use std::{
    collections::{BTreeMap, BTreeSet},
    sync::atomic::{AtomicU64, Ordering},
    time::Instant,
};
static NEXT: AtomicU64 = AtomicU64::new(1);
pub(super) struct Path {
    pub source: String,
    pub identity: String,
    pub conditions: Data,
    pub id: String,
}
/// Completed native receipts accompany the local feedback; callers choose their own journal.
pub struct BranchEvaluation {
    pub feedback: Data,
    pub receipts: Vec<Data>,
}
/// One current source generation with immutable registered domain programs.
pub struct EvidenceInteraction {
    engine: Engine,
    sources: Data,
    operations: BTreeMap<String, EvidenceOperation>,
    registry: Registry,
    chain: EvidenceChain,
    pub(super) paths: BTreeMap<String, Path>,
    owner: u64,
    sequence: u64,
    closed: bool,
}
struct Prepared {
    position: usize,
    id: String,
    conditions: Data,
    identity: String,
    signature: String,
    atoms: Vec<(String, Data, bool)>,
    prior: bool,
}
impl EvidenceInteraction {
    /// # Errors
    /// Rejects invalid source authority, operation schemas and closed engines.
    pub fn new(
        engine: &Engine,
        sources: Data,
        operations: BTreeMap<String, EvidenceOperation>,
        retain: bool,
    ) -> Result<Self> {
        engine.check()?;
        let registry = Registry::new(&sources, &operations)?;
        let chain = EvidenceChain::new(engine, sources.clone(), retain, FactLimits::default())?;
        let owner = NEXT
            .try_update(Ordering::Relaxed, Ordering::Relaxed, |n| n.checked_add(1))
            .map_err(|_| invalid("interaction identity exhausted"))?;
        Ok(Self {
            engine: engine.clone(),
            sources,
            operations,
            registry,
            chain,
            paths: BTreeMap::new(),
            owner,
            sequence: 0,
            closed: false,
        })
    }
    fn check_owner(&self) -> Result<()> {
        self.engine.check()?;
        if self.closed {
            Err(crate::Error::Closed)
        } else {
            Ok(())
        }
    }
    #[must_use]
    pub fn source_identity(&self) -> String {
        self.chain.source_identity()
    }
    #[must_use]
    pub fn descriptions(&self) -> &BTreeMap<String, Data> {
        &self.registry.descriptions
    }
    /// Every local condition uses rows from one completed source-qualified native graph.
    /// # Errors
    /// Rejects malformed/duplicate branch IDs and exhausted reference capacity.
    pub fn check(&mut self, branches: &Data) -> Result<BranchEvaluation> {
        self.check_owner()?;
        let branches = validate_branches(branches)?;
        if self.paths.len() + branches.len() > 4096 {
            return Err(crate::Error::StateLimit);
        }
        let started = Instant::now();
        let mut entries = branches
            .iter()
            .map(|b| {
                Ok(Data::object([
                    ("id", b.field("id")?.clone()),
                    ("status", "unknown".into()),
                    ("complete", false.into()),
                ]))
            })
            .collect::<Result<Vec<_>>>()?;
        let groups = self.prepare(branches, &mut entries)?;
        let mut receipts = Vec::new();
        for (signature, items) in groups {
            self.evaluate_group(&signature, &items, &mut entries, &mut receipts)?;
        }
        Ok(BranchEvaluation {
            feedback: Data::object([
                ("schema", "ascent.branch-feedback.v2".into()),
                ("sourceIdentity", self.source_identity().into()),
                ("scope", "model-declared-local-conditions".into()),
                ("branches", Data::List(entries)),
                ("taskCorrectnessCertified", false.into()),
                (
                    "seconds",
                    Data::Real(started.elapsed().as_secs_f64().to_bits()),
                ),
            ]),
            receipts,
        })
    }
    fn prepare(
        &self,
        branches: &[Data],
        entries: &mut [Data],
    ) -> Result<BTreeMap<String, Vec<Prepared>>> {
        let mut groups = BTreeMap::<String, Vec<Prepared>>::new();
        for (position, branch) in branches.iter().enumerate() {
            match self.branch(position, branch) {
                Ok(prepared) => groups
                    .entry(prepared.signature.clone())
                    .or_default()
                    .push(prepared),
                Err(error) => put(&mut entries[position], "reason", error.to_string().into())?,
            }
        }
        Ok(groups)
    }
    fn branch(&self, position: usize, branch: &Data) -> Result<Prepared> {
        let conditions = branch.get("conditions").cloned().unwrap_or_else(|| {
            Data::List(vec![Data::object([
                (
                    "operation",
                    branch.get("operation").cloned().unwrap_or(Data::Null),
                ),
                (
                    "arguments",
                    branch.get("arguments").cloned().unwrap_or(Data::Null),
                ),
            ])])
        });
        let values = conditions.list()?;
        if values.is_empty() || values.len() > 16 {
            return Err(invalid("declare one to sixteen local conditions"));
        }
        let mut signature = None;
        let mut atoms = Vec::new();
        for condition in values {
            let operation = self.condition(condition)?;
            if signature
                .as_ref()
                .is_some_and(|prior| prior != &operation.signature)
            {
                return Err(invalid("incompatible registered domain programs"));
            }
            signature = Some(operation.signature.clone());
            atoms.push((
                operation.relation.clone(),
                condition.field("arguments")?.clone(),
                operation.complete,
            ));
        }
        let signature = signature.ok_or_else(|| invalid("missing operation graph"))?;
        let canonical = values.iter().cloned().collect::<BTreeSet<_>>();
        let identity = Data::List(vec![
            signature.clone().into(),
            Data::List(canonical.into_iter().collect()),
        ])
        .digest();
        let prior = branch.get("reference");
        if let Some(reference) = prior {
            let path = self
                .paths
                .get(reference.text()?)
                .ok_or_else(|| invalid("unknown or invalidated evidence reference"))?;
            if path.source != self.source_identity() || path.identity != identity {
                return Err(invalid("mismatched evidence reference"));
            }
        }
        Ok(Prepared {
            position,
            id: branch.field("id")?.identity()?.into(),
            conditions,
            identity,
            signature,
            atoms,
            prior: prior.is_some(),
        })
    }
    fn condition(&self, condition: &Data) -> Result<&super::registry::Registered> {
        if condition.map()?.len() != 2 {
            return Err(invalid("condition fields must be operation and arguments"));
        }
        let operation = self
            .registry
            .operations
            .get(condition.field("operation")?.text()?)
            .ok_or_else(|| invalid("unsupported local operation"))?;
        if !ground(condition.field("arguments")?, &operation.columns)? {
            return Err(invalid("unsupported predicate bindings"));
        }
        Ok(operation)
    }
    fn evaluate_group(
        &mut self,
        signature: &str,
        items: &[Prepared],
        entries: &mut [Data],
        receipts: &mut Vec<Data>,
    ) -> Result<()> {
        let program = self
            .registry
            .programs
            .get(signature)
            .ok_or_else(|| invalid("missing registered graph"))?
            .clone();
        let receipt = match self.chain.query(&program) {
            Ok(receipt) => receipt,
            Err(error) => {
                return unavailable(items, entries, &error);
            }
        };
        let rows = index_rows(receipt.field("result")?.field("relations")?)?;
        for item in items {
            let entry = self.outcome(item, &rows, &receipt)?;
            entries[item.position] = entry;
        }
        receipts.push(receipt);
        Ok(())
    }
    fn outcome(
        &mut self,
        item: &Prepared,
        rows: &BTreeMap<String, BTreeSet<Data>>,
        receipt: &Data,
    ) -> Result<Data> {
        let verdicts = item
            .atoms
            .iter()
            .map(|(relation, tuple, complete)| {
                (
                    rows.get(relation).is_some_and(|r| r.contains(tuple)),
                    *complete,
                )
            })
            .collect::<Vec<_>>();
        let supported = verdicts.iter().all(|(present, _)| *present);
        let negative = verdicts
            .iter()
            .any(|(present, complete)| !*present && *complete);
        let status = if supported {
            "supported"
        } else if negative {
            "contradicted"
        } else {
            "unknown"
        };
        self.sequence = self
            .sequence
            .checked_add(1)
            .ok_or(crate::Error::StateLimit)?;
        let reference = format!("path_{}_{}", self.owner, self.sequence);
        let mut entry = Data::object([
            ("id", item.id.clone().into()),
            ("status", status.into()),
            ("complete", (supported || negative).into()),
            ("domainComplete", verdicts.iter().all(|(_, c)| *c).into()),
            ("reference", reference.clone().into()),
            ("conditions", item.conditions.clone()),
            ("referenceRequested", item.prior.into()),
            (
                "reason",
                if supported || negative {
                    "Completed native checks of the declared local conditions"
                } else {
                    "No positive support; absent predicates are not declared complete"
                }
                .into(),
            ),
        ]);
        for key in [
            "sourceIdentity",
            "resultReference",
            "pathIdentity",
            "reusedComponents",
            "freshComponents",
            "retainedCompleted",
            "evaluated",
            "evaluationCount",
        ] {
            put(&mut entry, key, receipt.field(key)?.clone())?;
        }
        self.paths.insert(
            reference,
            Path {
                source: self.source_identity(),
                identity: item.identity.clone(),
                conditions: item.conditions.clone(),
                id: item.id.clone(),
            },
        );
        if let [condition] = item.conditions.list()? {
            put(
                &mut entry,
                "operation",
                condition.field("operation")?.clone(),
            )?;
            put(
                &mut entry,
                "arguments",
                condition.field("arguments")?.clone(),
            )?;
        }
        Ok(entry)
    }
    /// # Errors
    /// Rejects invalid replacement before revoking the current reference generation.
    pub fn replace(&mut self, sources: Data) -> Result<()> {
        self.check_owner()?;
        let registry = Registry::new(&sources, &self.operations)?;
        self.chain.replace(sources.clone())?;
        self.sources = sources;
        self.registry = registry;
        self.paths.clear();
        Ok(())
    }
    pub fn close(&mut self) {
        self.chain.close();
        self.paths.clear();
        self.closed = true;
    }
}
fn validate_branches(branches: &Data) -> Result<&[Data]> {
    let values = branches.list()?;
    if values.is_empty() || values.len() > 128 {
        return Err(invalid("check one to 128 branches"));
    }
    let ids = values
        .iter()
        .map(|b| b.field("id")?.identity())
        .collect::<Result<BTreeSet<_>>>()?;
    if ids.len() != values.len() {
        return Err(invalid("distinct branch identities required"));
    }
    Ok(values)
}
fn index_rows(relations: &Data) -> Result<BTreeMap<String, BTreeSet<Data>>> {
    relations
        .map()?
        .iter()
        .map(|(name, rows)| {
            rows.list()
                .map(|rows| (name.clone(), rows.iter().cloned().collect()))
        })
        .collect()
}

fn unavailable(items: &[Prepared], entries: &mut [Data], error: &crate::Error) -> Result<()> {
    let reason = format!(
        "Check unavailable: {}",
        error.to_string().chars().take(512).collect::<String>()
    );
    items
        .iter()
        .try_for_each(|item| put(&mut entries[item.position], "reason", reason.clone().into()))
}
