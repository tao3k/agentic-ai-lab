//! Structural dependency slicing validates supplied facts without executing clauses.
use super::{dependencies, heads, index, strings, texts};
use crate::{Data, Result, evidence_store::put, invalid_data as invalid};
use std::collections::{BTreeMap, BTreeSet};
/// Keep exactly query dependencies, including every head in selected multi-head rules.
/// # Errors
/// Rejects undefined/undeclared relations, missing source facts and ill-typed source tuples.
pub fn slice_program(program: &Data, facts: &Data, queries: &Data) -> Result<Data> {
    let queries = texts(queries)?.into_iter().collect::<BTreeSet<_>>();
    if queries.is_empty() {
        return Err(invalid("queries must name declared ASCENT relations"));
    }
    let declarations = index(program.field("relations")?)?;
    let rules = program.field("rules")?.list()?;
    let facts = facts.map()?;
    let definitions = definitions(rules, &declarations)?;
    let (used, selected) = select(&queries, &declarations, rules, &definitions)?;
    let relations = used
        .iter()
        .map(|name| materialize(name, &declarations, facts))
        .collect::<Result<Vec<_>>>()?;
    Ok(Data::object([
        ("relations", Data::List(relations)),
        (
            "rules",
            Data::List(selected.into_iter().map(|i| rules[i].clone()).collect()),
        ),
        ("queries", strings(queries)),
    ]))
}

fn definitions(
    rules: &[Data],
    declarations: &BTreeMap<String, Data>,
) -> Result<BTreeMap<String, Vec<usize>>> {
    let mut definitions = BTreeMap::<String, Vec<usize>>::new();
    for (i, r) in rules.iter().enumerate() {
        if r.map()?.len() != 2
            || r.field("head")?.list()?.is_empty()
            || r.field("body")?.list()?.is_empty()
        {
            return Err(invalid("ASCENT head/body rule required"));
        }
        for name in heads(r)? {
            if declarations.get(&name).and_then(|v| v.get("source")) != Some(&Data::Bool(false)) {
                return Err(invalid("rule head must name a derived relation"));
            }
            definitions.entry(name).or_default().push(i);
        }
    }
    Ok(definitions)
}
fn select(
    queries: &BTreeSet<String>,
    declarations: &BTreeMap<String, Data>,
    rules: &[Data],
    definitions: &BTreeMap<String, Vec<usize>>,
) -> Result<(BTreeSet<String>, BTreeSet<usize>)> {
    let mut used = BTreeSet::new();
    let mut selected = BTreeSet::new();
    let mut pending = queries.iter().cloned().collect::<Vec<_>>();
    while let Some(name) = pending.pop() {
        if !used.insert(name.clone()) {
            continue;
        }
        let r = declarations
            .get(&name)
            .ok_or_else(|| invalid("undeclared ASCENT dependency"))?;
        if !r.field("source")?.boolean()? && !definitions.contains_key(&name) {
            return Err(invalid("derived relation has no rule"));
        }
        for &i in definitions.get(&name).into_iter().flatten() {
            selected.insert(i);
            pending.extend(heads(&rules[i])?);
            pending.extend(dependencies(rules[i].field("body")?.list()?)?);
        }
    }
    Ok((used, selected))
}
fn materialize(
    name: &str,
    declarations: &BTreeMap<String, Data>,
    facts: &BTreeMap<String, Data>,
) -> Result<Data> {
    let mut r = declarations[name].clone();
    let source = r.field("source")?.boolean()?;
    let rows = facts
        .get(name)
        .cloned()
        .unwrap_or_else(|| Data::List(Vec::new()));
    if source && !facts.contains_key(name) {
        return Err(invalid("undeclared source facts"));
    }
    if !source && !rows.list()?.is_empty() {
        return Err(invalid("derived relation cannot contain source facts"));
    }
    put(&mut r, "rows", rows)?;
    let relation = gerbil_ascent::Catalog::read_relation(&r)?;
    if relation.rows.iter().any(|row| !relation.accepts(row)) {
        return Err(invalid(
            "source row violates native relation type or domain",
        ));
    }
    Ok(r)
}
