//! Exact source schemas and limits form the retained-path admission boundary.
use super::{EvidenceStore, put, schema};
use crate::{Catalog, Data, Engine, FactLimits, Program, Result, invalid_data as invalid};
use std::collections::{BTreeMap, BTreeSet};
pub(super) fn index(relations: &Data) -> Result<BTreeMap<String, Data>> {
    let mut out = BTreeMap::new();
    for relation in relations.list()? {
        let name = relation.field("name")?.identity()?.to_string();
        if out.insert(name, relation.clone()).is_some() {
            return Err(invalid("duplicate relation"));
        }
    }
    Ok(out)
}
pub(super) fn sources(engine: &Engine, sources: &Data, limits: FactLimits) -> Result<Program> {
    engine.check()?;
    index(sources)?;
    if sources
        .list()?
        .iter()
        .any(|r| r.get("source") != Some(&Data::Bool(true)))
    {
        return Err(invalid("trusted source declarations required"));
    }
    let mut program = Catalog::read(&Data::object([
        ("relations", sources.clone()),
        ("rules", Data::List(Vec::new())),
    ]))?
    .program;
    program.fact_limits = limits;
    engine.open(program.clone())?;
    Ok(program)
}
fn dependencies(program: &Data) -> Result<BTreeSet<String>> {
    let mut used = program
        .field("queries")?
        .list()?
        .iter()
        .map(|v| v.text().map(str::to_string))
        .collect::<Result<BTreeSet<_>>>()?;
    for rule in program.field("rules")?.list()? {
        for clause in rule.field("body")?.list()? {
            if let Some(name) = clause.get("relation") {
                used.insert(name.text()?.to_string());
            }
        }
    }
    Ok(used)
}
impl EvidenceStore {
    pub(super) fn prepare(&self, mut value: Data) -> Result<(Data, BTreeSet<String>, Data)> {
        let fields = value.map()?;
        if fields.len() != 3 || !fields.contains_key("queries") {
            return Err(invalid("evidence program fields"));
        }
        let trusted = self.trusted()?;
        let referenced = dependencies(&value)?;
        let used = referenced
            .into_iter()
            .filter(|n| self.materialized.contains_key(n))
            .collect::<BTreeSet<_>>();
        let mut declarations = value.field("relations")?.list()?.to_vec();
        let present = index(&Data::List(declarations.clone()))?;
        for name in used.iter().filter(|n| !present.contains_key(*n)) {
            declarations.push(self.materialized[name].clone());
        }
        let declared = index(&Data::List(declarations.clone()))?;
        let base = index(&self.sources)?;
        let mut derived = Vec::new();
        for (name, relation) in &declared {
            if let Some(authority) = trusted.get(name) {
                if relation != authority {
                    return Err(invalid("query changed source authority"));
                }
            } else {
                if relation.get("source") != Some(&Data::Bool(false))
                    || relation
                        .get("rows")
                        .map(Data::list)
                        .transpose()?
                        .is_some_and(|r| !r.is_empty())
                {
                    return Err(invalid("derived evidence cannot introduce source facts"));
                }
                derived.push(relation.clone());
            }
        }
        if base.keys().any(|name| !declared.contains_key(name)) {
            return Err(invalid("query omitted source authority"));
        }
        for rule in value.field("rules")?.list()? {
            for head in rule.field("head")?.list()? {
                if trusted.contains_key(head.field("relation")?.text()?) {
                    return Err(invalid("query defines source heads"));
                }
            }
        }
        put(&mut value, "relations", Data::List(declarations))?;
        let signature = Data::object([
            (
                "sourceSchema",
                Data::List(self.sources.list()?.iter().map(schema).collect()),
            ),
            (
                "factLimits",
                Data::List(
                    [self.limits.input, self.limits.derived, self.limits.output]
                        .into_iter()
                        .map(|v| v.map_or(Data::Null, Data::from))
                        .collect(),
                ),
            ),
            (
                "evidenceSchema",
                Data::List(used.iter().map(|n| schema(&self.materialized[n])).collect()),
            ),
            ("derived", Data::List(derived)),
            ("rules", value.field("rules")?.clone()),
            ("queries", value.field("queries")?.clone()),
        ]);
        Ok((value, used, signature))
    }
}
