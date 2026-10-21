//! Private independently checked finite receipts and source/candidate-bound observations.
use super::{lowering, support};
use crate::{
    Cancellation, Data, Engine, FactLimits, Limits, ProvenanceLimits, ProvenanceStatus, Result,
    Row, SourceSession, evidence_store::rows_data, invalid_data as invalid,
};
use std::{
    collections::{BTreeMap, VecDeque},
    sync::atomic::{AtomicU64, Ordering},
    time::Duration,
};
static NEXT: AtomicU64 = AtomicU64::new(1);
struct Entry {
    source: Data,
    candidate: Data,
    handle: u64,
    scope: Data,
    rows: Vec<Row>,
    closure: BTreeMap<String, Vec<Row>>,
    arities: BTreeMap<String, usize>,
    support: Vec<Data>,
    _session: SourceSession,
}
/// A bounded private receipt store. Unsupported/bounded attempts remain unknown, never absent.
pub struct ComputationalEvidence {
    engine: Engine,
    entries: BTreeMap<String, Entry>,
    order: VecDeque<String>,
    attempts: u64,
    builds: u64,
    hits: u64,
    evictions: u64,
    closed: bool,
}
fn unknown(reason: &str) -> Data {
    Data::object([("status", "unknown".into()), ("reason", reason.into())])
}
impl ComputationalEvidence {
    /// # Errors
    /// Rejects closed engines.
    pub fn new(engine: &Engine) -> Result<Self> {
        engine.check()?;
        Ok(Self {
            engine: engine.clone(),
            entries: BTreeMap::new(),
            order: VecDeque::new(),
            attempts: 0,
            builds: 0,
            hits: 0,
            evictions: 0,
            closed: false,
        })
    }
    fn check(&self) -> Result<()> {
        self.engine.check()?;
        if self.closed {
            Err(crate::Error::Closed)
        } else {
            Ok(())
        }
    }
    fn key(source: &Data, candidate: &Data) -> String {
        Data::List(vec![source.clone(), candidate.clone()]).digest()
    }
    /// Complete evaluation followed by independent finite-closure/provenance replay.
    /// # Errors
    /// Rejects revoked store ownership; inadmissible proposals return unknown observations.
    pub fn resolve(&mut self, source: &Data, candidate: &Data) -> Result<Data> {
        self.check()?;
        let key = Self::key(source, candidate);
        if let Some(entry) = self.entries.get(&key) {
            if entry.source != *source || entry.candidate != *candidate {
                return Err(invalid("receipt digest collision"));
            }
            self.hits += 1;
            return describe(entry, true);
        }
        self.attempts += 1;
        let entry = match self.build(source, candidate) {
            Ok(entry) => entry,
            Err(error) => return Ok(unknown(&error.to_string())),
        };
        let description = describe(&entry, false)?;
        if self.entries.len() == 64 {
            let old = self
                .order
                .pop_front()
                .ok_or_else(|| invalid("receipt eviction queue"))?;
            self.entries.remove(&old);
            self.evictions += 1;
        }
        self.entries.insert(key.clone(), entry);
        self.order.push_back(key);
        self.builds += 1;
        Ok(description)
    }
    fn build(&self, source: &Data, candidate: &Data) -> Result<Entry> {
        let admitted = lowering::read(source, candidate)?;
        let query = admitted.query;
        let arities = admitted
            .program
            .relations
            .iter()
            .map(|r| (r.name.clone(), r.columns.len()))
            .collect::<BTreeMap<_, _>>();
        let mut session = self
            .engine
            .open_source_program(admitted.program, FactLimits::default())?;
        let limits = Limits {
            timeout: Duration::from_secs(1),
            max_states: 100_000,
            max_facts: usize::MAX,
        };
        let cancel = Cancellation::default();
        let evaluated = session.run(None, &limits, &cancel)?;
        let closure = evaluated.relations;
        let rows = closure
            .get(&query.relation)
            .ok_or_else(|| invalid("candidate query missing from closure"))?
            .iter()
            .filter(|r| lowering::matches(&query, r))
            .cloned()
            .collect();
        let policy = ProvenanceLimits {
            max_steps: 100_000,
            max_nodes: 4096,
            max_edges: 65_536,
            timeout: Duration::from_secs(1),
        };
        let proof =
            session.provenance(evaluated.result_handle, &query.relation, &policy, &cancel)?;
        let graph = proof.graph()?;
        if !matches!(
            graph.status,
            ProvenanceStatus::Complete | ProvenanceStatus::ClosedAbsent
        ) || !proof.verify(&graph, &policy, &cancel)?
        {
            return Err(invalid("unverified finite receipt"));
        }
        let support = support::acyclic(&graph)?;
        let handle = NEXT
            .try_update(Ordering::Relaxed, Ordering::Relaxed, |n| n.checked_add(1))
            .map_err(|_| invalid("receipt handles exhausted"))?;
        let scope = Data::List(vec![
            Data::List(vec![
                "source-identity".into(),
                source.field("identity")?.clone(),
            ]),
            Data::List(vec![
                "generation".into(),
                source.field("generation")?.clone(),
            ]),
            Data::List(vec![
                "source-digest".into(),
                source.field("relations")?.digest().into(),
            ]),
            Data::List(vec!["candidate-digest".into(), candidate.digest().into()]),
            Data::List(vec!["query".into(), candidate_query(candidate)?]),
        ]);
        Ok(Entry {
            source: source.clone(),
            candidate: candidate.clone(),
            handle,
            scope,
            rows,
            closure,
            arities,
            support,
            _session: session,
        })
    }
    fn bound(&self, source: &Data, candidate: &Data, handle: u64) -> Option<&Entry> {
        self.entries
            .get(&Self::key(source, candidate))
            .filter(|e| e.handle == handle && e.source == *source && e.candidate == *candidate)
    }
    /// # Errors
    /// Rejects closed owners; stale or foreign handles remain unknown.
    pub fn fact(&self, source: &Data, candidate: &Data, handle: u64, atom: &Data) -> Result<Data> {
        self.check()?;
        let Some(entry) = self.bound(source, candidate, handle) else {
            return Ok(unknown("stale-or-unknown-handle"));
        };
        let cells = match atom.list() {
            Ok(c) if !c.is_empty() => c,
            _ => return Ok(unknown("invalid-atom")),
        };
        let Ok(name) = cells[0].text() else {
            return Ok(unknown("invalid-atom"));
        };
        if cells[1..]
            .iter()
            .any(|v| !matches!(v, Data::Integer(_) | Data::Bool(_) | Data::Text(_)))
        {
            return Ok(unknown("invalid-atom"));
        }
        if entry.arities.get(name) != Some(&(cells.len() - 1)) {
            return Ok(unknown("unknown-relation-or-arity"));
        }
        let present = rows_data(entry.closure.get(name).map_or(&[], Vec::as_slice))?
            .list()?
            .contains(&Data::List(cells[1..].to_vec()));
        let roots = if present {
            entry
                .support
                .iter()
                .filter_map(|n| n.list().ok())
                .filter(|n| n[2] == cells[0] && n[3] == Data::List(cells[1..].to_vec()))
                .map(|n| n[0].clone())
                .collect()
        } else {
            Vec::new()
        };
        Ok(Data::object([
            (
                "status",
                if present { "verified" } else { "finite-absent" }.into(),
            ),
            ("present", present.into()),
            ("atom", atom.clone()),
            ("handle", handle.into()),
            ("basis", "verified-finite-closure".into()),
            ("support-nodes", Data::List(roots)),
            ("scope", entry.scope.clone()),
        ]))
    }
    /// # Errors
    /// Rejects closed owners. Positive fragments include named ancestor-closed support only.
    pub fn fragment(
        &self,
        source: &Data,
        candidate: &Data,
        handle: u64,
        atom: &Data,
    ) -> Result<Data> {
        let answer = self.fact(source, candidate, handle, atom)?;
        if answer.field("status")?.text()? != "verified" {
            return Ok(answer);
        }
        let entry = self
            .bound(source, candidate, handle)
            .ok_or_else(|| invalid("missing admitted receipt"))?;
        let roots = answer.field("support-nodes")?.clone();
        let nodes = support::ancestors(&entry.support, &roots)?;
        Ok(Data::object([
            ("status", "verified".into()),
            ("fact", answer),
            ("roots", roots),
            ("nodes", Data::List(nodes)),
        ]))
    }
    /// # Errors
    /// Rejects closed owners.
    pub fn stats(&self) -> Result<Data> {
        self.check()?;
        Ok(Data::object([
            ("entries", self.entries.len().into()),
            ("attempts", self.attempts.into()),
            ("proof-builds", self.builds.into()),
            ("hits", self.hits.into()),
            ("evictions", self.evictions.into()),
        ]))
    }
    pub fn close(&mut self) {
        self.entries.clear();
        self.order.clear();
        self.closed = true;
    }
}
fn candidate_query(candidate: &Data) -> Result<Data> {
    candidate
        .list()?
        .iter()
        .skip(1)
        .find_map(|c| {
            c.list()
                .ok()
                .filter(|c| c.first() == Some(&Data::Text("query".into())))
                .map(|c| Data::List(c[1..].to_vec()))
        })
        .ok_or_else(|| invalid("missing candidate query"))
}
fn describe(entry: &Entry, reused: bool) -> Result<Data> {
    Ok(Data::object([
        ("status", "verified".into()),
        ("finite-complete", true.into()),
        ("handle", entry.handle.into()),
        ("reused", reused.into()),
        ("scope", entry.scope.clone()),
        ("rows", rows_data(&entry.rows)?),
    ]))
}
