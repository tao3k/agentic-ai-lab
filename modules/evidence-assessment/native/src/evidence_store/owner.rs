//! Source-authorized retained evaluation and immutable materialized relation aliases.
use super::admission;
use crate::{
    Cancellation, Catalog, Data, Engine, FactLimits, Limits, Result, Row, Session, Value,
    invalid_data as invalid,
};
use std::{
    collections::{BTreeMap, BTreeSet},
    sync::{
        Arc,
        atomic::{AtomicUsize, Ordering},
    },
};
struct Permit(Arc<AtomicUsize>);
impl Drop for Permit {
    fn drop(&mut self) {
        self.0.fetch_sub(1, Ordering::Relaxed);
    }
}
struct Cached {
    signature: Data,
    session: Session,
    used: BTreeSet<String>,
    result: Option<Data>,
    evaluations: u64,
    _permit: Permit,
}
/// Retained facts are usable only under the exact current source/schema and native limits.
pub struct EvidenceStore {
    pub(super) engine: Engine,
    pub(super) sources: Data,
    pub(super) limits: FactLimits,
    paths: BTreeMap<String, Cached>,
    pub(super) materialized: BTreeMap<String, Data>,
    alias_owners: BTreeMap<String, (String, String)>,
    closed: bool,
}
impl EvidenceStore {
    /// # Errors
    /// Rejects duplicate/non-source declarations, inadmissible facts or closed engines.
    pub fn new(engine: &Engine, sources: Data, limits: FactLimits) -> Result<Self> {
        admission::sources(engine, &sources, limits)?;
        Ok(Self {
            engine: engine.clone(),
            sources,
            limits,
            paths: BTreeMap::new(),
            materialized: BTreeMap::new(),
            alias_owners: BTreeMap::new(),
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
    #[must_use]
    pub fn source_identity(&self) -> String {
        self.sources.digest()
    }
    #[must_use]
    pub fn sources(&self) -> &Data {
        &self.sources
    }
    #[must_use]
    pub fn materialized(&self) -> &BTreeMap<String, Data> {
        &self.materialized
    }
    /// # Errors
    /// Rejects unknown names, revoked owners and stale materialized aliases.
    pub fn scan(&self, names: &[String]) -> Result<Data> {
        self.check()?;
        let trusted = self.trusted()?;
        let rows = names
            .iter()
            .map(|name| {
                trusted
                    .get(name)
                    .ok_or_else(|| invalid("unknown source scan"))
                    .map(|r| {
                        (
                            name.clone(),
                            r.get("rows")
                                .cloned()
                                .unwrap_or_else(|| Data::List(Vec::new())),
                        )
                    })
            })
            .collect::<Result<_>>()?;
        Ok(Data::object([
            ("sourceIdentity", self.source_identity().into()),
            ("relations", Data::Map(rows)),
        ]))
    }
    pub(super) fn trusted(&self) -> Result<BTreeMap<String, Data>> {
        let mut values = admission::index(&self.sources)?;
        values.extend(self.materialized.clone());
        Ok(values)
    }
    /// # Errors
    /// Rechecks source authority and admits every rule before evaluating or reusing completion.
    pub fn query(&mut self, supplied: Data) -> Result<Data> {
        self.check()?;
        let (value, used, signature) = self.prepare(supplied)?;
        let key = signature.digest();
        let reused = self.paths.contains_key(&key);
        if let Some(path) = self.paths.get(&key)
            && path.signature != signature
        {
            return Err(invalid("evidence fingerprint collision"));
        }
        let catalog = Catalog::read(&value)?;
        if !reused {
            self.engine
                .evidence_owners
                .try_update(Ordering::Relaxed, Ordering::Relaxed, |n| {
                    (n < 64).then_some(n + 1)
                })
                .map_err(|_| invalid("evidence path capacity"))?;
            let permit = Permit(self.engine.evidence_owners.clone());
            let mut program = catalog.program.clone();
            program.fact_limits = self.limits;
            let session = self.engine.open(program)?;
            self.paths.insert(
                key.clone(),
                Cached {
                    signature,
                    session,
                    used,
                    result: None,
                    evaluations: 0,
                    _permit: permit,
                },
            );
        }
        let hit = self.paths[&key].result.is_some();
        let result = match self.run_path(&key, &catalog.queries) {
            Ok(result) => result,
            Err(error) => {
                self.paths.remove(&key);
                return Err(error);
            }
        };
        let published = self.publish(&key, &value, &result)?;
        Ok(Data::object([
            ("sourceIdentity", self.source_identity().into()),
            ("pathIdentity", key.clone().into()),
            ("retainedPath", reused.into()),
            ("retainedCompleted", hit.into()),
            ("evaluated", (!hit).into()),
            ("evaluationCount", self.paths[&key].evaluations.into()),
            ("result", result),
            ("publishedEvidence", Data::List(published)),
        ]))
    }
    fn run_path(&mut self, key: &str, queries: &[String]) -> Result<Data> {
        let cached = self
            .paths
            .get_mut(key)
            .ok_or_else(|| invalid("missing evidence path"))?;
        if let Some(result) = &cached.result {
            return Ok(result.clone());
        }
        let result = cached
            .session
            .run(&Limits::default(), &Cancellation::default())?;
        let rows = queries
            .iter()
            .map(|name| {
                result
                    .relations
                    .get(name)
                    .ok_or_else(|| invalid("unknown completed query"))
                    .and_then(|rows| rows_data(rows).map(|rows| (name.clone(), rows)))
            })
            .collect::<Result<_>>()?;
        let result = Data::object([("complete", true.into()), ("relations", Data::Map(rows))]);
        cached.evaluations = cached
            .evaluations
            .checked_add(1)
            .ok_or(crate::Error::StateLimit)?;
        cached.result = Some(result.clone());
        Ok(result)
    }
    fn publish(&mut self, key: &str, program: &Data, result: &Data) -> Result<Vec<Data>> {
        let trusted = self.trusted()?;
        let declarations = admission::index(program.field("relations")?)?;
        let publications = result
            .field("relations")?
            .map()?
            .iter()
            .filter(|(name, _)| !trusted.contains_key(*name))
            .map(|(name, rows)| {
                let alias = format!(
                    "evidence_{}",
                    Data::List(vec![key.into(), name.clone().into()]).digest()
                );
                if trusted.contains_key(&alias) && !self.materialized.contains_key(&alias) {
                    return Err(invalid("evidence alias conflicts with source"));
                }
                let owner = (key.to_string(), name.clone());
                if self
                    .alias_owners
                    .get(&alias)
                    .is_some_and(|prior| prior != &owner)
                {
                    return Err(invalid("evidence alias digest collision"));
                }
                let mut relation = declarations
                    .get(name)
                    .ok_or_else(|| invalid("missing output declaration"))?
                    .clone();
                let columns = relation.field("columns")?.clone();
                put(&mut relation, "name", alias.clone().into())?;
                put(&mut relation, "source", true.into())?;
                put(&mut relation, "rows", rows.clone())?;
                let receipt = Data::object([
                    ("relation", alias.clone().into()),
                    ("originRelation", name.clone().into()),
                    ("columns", columns),
                ]);
                Ok((alias, owner, relation, receipt))
            })
            .collect::<Result<Vec<_>>>()?;
        let names = publications
            .iter()
            .map(|(alias, _, _, _)| alias)
            .collect::<BTreeSet<_>>();
        if names.len() != publications.len() {
            return Err(invalid("evidence alias digest collision"));
        }
        Ok(publications
            .into_iter()
            .map(|(alias, owner, relation, receipt)| {
                self.alias_owners.insert(alias.clone(), owner);
                self.materialized.insert(alias, relation);
                receipt
            })
            .collect())
    }

    /// # Errors
    /// Validates the whole replacement before altering any retained path or source identity.
    pub fn replace(&mut self, sources: Data) -> Result<()> {
        self.check()?;
        let previous = admission::index(&self.sources)?;
        let current = admission::index(&sources)?;
        if previous.keys().ne(current.keys())
            || current
                .iter()
                .any(|(name, r)| schema(r) != schema(&previous[name]))
        {
            return Err(invalid("source schema changed"));
        }
        let program = admission::sources(&self.engine, &sources, self.limits)?;
        let updates = program
            .relations
            .into_iter()
            .map(|r| (r.name, r.rows))
            .collect::<BTreeMap<_, _>>();
        self.paths.retain(|_, p| p.used.is_empty());
        for path in self.paths.values_mut() {
            path.session.replace_sources(updates.clone())?;
            path.result = None;
        }
        self.sources = sources;
        self.materialized.clear();
        self.alias_owners.clear();
        Ok(())
    }
    pub fn close(&mut self) {
        self.paths.clear();
        self.materialized.clear();
        self.alias_owners.clear();
        self.closed = true;
    }
}
pub(crate) fn put(value: &mut Data, key: &str, item: Data) -> Result<()> {
    let Data::Map(value) = value else {
        return Err(invalid("object required"));
    };
    value.insert(key.into(), item);
    Ok(())
}
pub(crate) fn schema(value: &Data) -> Data {
    match value {
        Data::Map(fields) => Data::Map(
            fields
                .iter()
                .filter(|(k, _)| k.as_str() != "rows")
                .map(|(k, v)| (k.clone(), v.clone()))
                .collect(),
        ),
        _ => value.clone(),
    }
}
pub(crate) fn rows_data(rows: &[Row]) -> Result<Data> {
    rows.iter()
        .map(|r| {
            r.iter()
                .map(value_data)
                .collect::<Result<Vec<_>>>()
                .map(Data::List)
        })
        .collect::<Result<Vec<_>>>()
        .map(Data::List)
}
pub(crate) fn value_data(value: &Value) -> Result<Data> {
    match value {
        Value::Integer(v) => Ok(Data::Integer(v.clone())),
        Value::Boolean(v) => Ok(Data::Bool(*v)),
        Value::Symbol(v) | Value::Text(v) => Ok(Data::Text(v.to_string())),
        Value::Object(_) => Err(invalid(
            "complex workflow cells require typed result observations",
        )),
    }
}
