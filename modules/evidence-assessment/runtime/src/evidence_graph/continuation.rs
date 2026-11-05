//! Bounded alpha-equivalence of closed relational continuations.
use crate::{Data, Result, evidence_store::put, invalid_data as invalid};
use std::collections::BTreeMap;
/// Normalize the accepted single-head shorthand without changing the caller's value.
/// # Errors
/// Rejects malformed contract maps/rules.
pub fn normalize_contract(value: &Data) -> Result<Data> {
    let mut out = value.clone();
    out.map()?;
    for field in ["relations", "rules"] {
        if out.get(field).is_none() {
            put(&mut out, field, Data::List(Vec::new()))?;
        }
    }
    let mut rules = out.field("rules")?.list()?.to_vec();
    for rule in &mut rules {
        if matches!(rule.get("head"), Some(Data::Map(_))) {
            let head = rule.field("head")?.clone();
            put(rule, "head", Data::List(vec![head]))?;
        }
    }
    put(&mut out, "rules", Data::List(rules))?;
    Ok(out)
}
type Names = BTreeMap<String, String>;
fn atom(a: &Data, b: &Data, forward: &mut Names, backward: &mut Names) -> Result<bool> {
    if a.map()?
        .keys()
        .chain(b.map()?.keys())
        .any(|k| !["relation", "terms", "not"].contains(&k.as_str()))
    {
        return Ok(false);
    }
    if a.get("relation") != b.get("relation")
        || a.get("not").unwrap_or(&Data::Bool(false)) != b.get("not").unwrap_or(&Data::Bool(false))
    {
        return Ok(false);
    }
    let at = a.field("terms")?.list()?;
    let bt = b.field("terms")?.list()?;
    if at.len() != bt.len() {
        return Ok(false);
    }
    for (x, y) in at.iter().zip(bt) {
        match (x, y) {
            (Data::Map(x), Data::Map(y))
                if x.len() == 1
                    && y.len() == 1
                    && x.contains_key("var")
                    && y.contains_key("var") =>
            {
                let x = x["var"].text()?;
                let y = y["var"].text()?;
                if forward.get(x).is_some_and(|v| v != y) || backward.get(y).is_some_and(|v| v != x)
                {
                    return Ok(false);
                }
                forward.insert(x.into(), y.into());
                backward.insert(y.into(), x.into());
            }
            _ if x == y => {}
            _ => return Ok(false),
        }
    }
    Ok(true)
}
fn body(a: &[Data], b: &[&Data], f: &Names, r: &Names, steps: &mut usize) -> Result<bool> {
    *steps += 1;
    if *steps > 10_000 {
        return Err(invalid("continuation equivalence search bound"));
    }
    if a.is_empty() {
        return Ok(b.is_empty());
    }
    for i in 0..b.len() {
        let mut f = f.clone();
        let mut r = r.clone();
        if atom(&a[0], b[i], &mut f, &mut r)? {
            let remaining = b
                .iter()
                .enumerate()
                .filter(|(j, _)| *j != i)
                .map(|(_, v)| *v)
                .collect::<Vec<_>>();
            if body(&a[1..], &remaining, &f, &r, steps)? {
                return Ok(true);
            }
        }
    }
    Ok(false)
}
fn same(a: &Data, b: &Data) -> Result<bool> {
    if a.map()?.len() != 2 || b.map()?.len() != 2 {
        return Ok(false);
    }
    let ah = a.field("head")?.list()?;
    let bh = b.field("head")?.list()?;
    let ab = a.field("body")?.list()?;
    let bb = b.field("body")?.list()?;
    if ah.len() != 1 || bh.len() != 1 || ab.len() > 16 || ab.len() != bb.len() {
        return Ok(false);
    }
    let mut f = Names::new();
    let mut r = Names::new();
    if !atom(&ah[0], &bh[0], &mut f, &mut r)? {
        return Ok(false);
    }
    body(ab, &bb.iter().collect::<Vec<_>>(), &f, &r, &mut 0)
}
fn signatures(rules: &[Data]) -> Result<Data> {
    rules
        .iter()
        .map(|r| {
            let mut values = r
                .field("body")?
                .list()?
                .iter()
                .map(|a| {
                    Ok(Data::List(vec![
                        a.get("relation").cloned().unwrap_or(Data::Bool(false)),
                        a.get("not").cloned().unwrap_or(Data::Bool(false)),
                        a.field("terms")?.list()?.len().into(),
                    ]))
                })
                .collect::<Result<Vec<_>>>()?;
            values.sort_by_cached_key(Data::digest);
            Ok(Data::List(values))
        })
        .collect::<Result<Vec<_>>>()
        .map(Data::List)
}
/// Admit only bijective variable renaming and conjunction permutation of trusted intent.
/// No query executes here; rejected intents carry diagnostic signatures.
/// # Errors
/// Rejects malformed contracts or equivalence-search exhaustion.
pub fn check_continuation(actual: &Data, expected: &Data) -> Result<Data> {
    let actual = normalize_contract(actual)?;
    let expected = normalize_contract(expected)?;
    let ar = actual.field("rules")?.list()?;
    let er = expected.field("rules")?.list()?;
    let mut accepted = actual.field("relations")? == expected.field("relations")?
        && actual.field("queries")? == expected.field("queries")?
        && ar.len() == er.len();
    if accepted {
        for (a, e) in ar.iter().zip(er) {
            if !same(a, e)? {
                accepted = false;
                break;
            }
        }
    }
    Ok(Data::object([
        ("accepted", accepted.into()),
        ("intentIdentity", actual.digest().into()),
        ("contractIdentity", expected.digest().into()),
        (
            "diagnostic",
            if accepted {
                Data::Bool(false)
            } else {
                Data::object([("reason","Preserve query projection, tuple-field bindings, every conjunct, negation and constant. Return the complete relation, not a delta.".into()),("requiredPredicateSignatures",signatures(er)?),("proposedPredicateSignatures",signatures(ar)?)])
            },
        ),
    ]))
}
