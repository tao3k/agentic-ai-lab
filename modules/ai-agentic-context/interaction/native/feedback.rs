//! Lossless branch metadata factoring preserves explicit verdicts and original presentation order.
use crate::{Data, Result, evidence_store::put, invalid_data as invalid};
use std::collections::{BTreeMap, BTreeSet};
const VISIBLE: &[&str] = &[
    "id",
    "status",
    "reference",
    "conditions",
    "reason",
    "requestedReference",
    "extendedReference",
];
fn remove(value: &mut Data, key: &str) -> Result<Data> {
    let Data::Map(fields) = value else {
        return Err(invalid("feedback object required"));
    };
    fields
        .remove(key)
        .ok_or_else(|| invalid("missing feedback field"))
}
/// Factor only observed equal metadata; every branch retains a visible status.
/// # Errors
/// Rejects malformed branch IDs or packet maps.
pub fn compact_feedback(value: &Data) -> Result<Data> {
    let mut packet = value.clone();
    let Some(branches) = packet.get("branches") else {
        return Ok(packet);
    };
    let Ok(branches) = branches.list() else {
        return Ok(packet);
    };
    if branches.is_empty() {
        return Ok(packet);
    }
    let mut groups = BTreeMap::<String, Vec<Data>>::new();
    let mut order = Vec::new();
    for branch in branches {
        let id = branch.field("id")?.identity()?;
        order.push(id.into());
        let key = branch
            .get("resultReference")
            .map(Data::text)
            .transpose()?
            .map_or_else(|| format!("unknown:{id}"), str::to_string);
        groups.entry(key).or_default().push(branch.clone());
    }
    let encoded = groups
        .values()
        .map(|rows| compact_group(rows))
        .collect::<Result<Vec<_>>>()?;
    remove(&mut packet, "branches")?;
    put(&mut packet, "encoding", "ascent.path-feedback.v2".into())?;
    put(&mut packet, "groups", Data::List(encoded))?;
    put(&mut packet, "branchOrder", Data::List(order))?;
    Ok(packet)
}
fn compact_group(rows: &[Data]) -> Result<Data> {
    let first = rows
        .first()
        .ok_or_else(|| invalid("nonempty feedback group required"))?
        .map()?;
    let common = first
        .iter()
        .filter(|(key, value)| {
            !VISIBLE.contains(&key.as_str()) && rows.iter().all(|r| r.get(key) == Some(*value))
        })
        .map(|(key, value)| (key.clone(), value.clone()))
        .collect::<BTreeMap<_, _>>();
    let branches = rows
        .iter()
        .map(|r| {
            Ok(Data::Map(
                r.map()?
                    .iter()
                    .filter(|(key, _)| !common.contains_key(*key))
                    .map(|(key, value)| (key.clone(), value.clone()))
                    .collect(),
            ))
        })
        .collect::<Result<Vec<_>>>()?;
    Ok(Data::object([
        ("sharedEvidence", Data::Map(common)),
        ("branches", Data::List(branches)),
    ]))
}
/// Restore exact fields and branch order without performing any new predicate evaluation.
/// # Errors
/// Rejects duplicate IDs, conflicting shared fields and omitted/repeated branch references.
pub fn expand_feedback(value: &Data) -> Result<Data> {
    if value.get("encoding") != Some(&Data::from("ascent.path-feedback.v2")) {
        return Ok(value.clone());
    }
    let mut packet = value.clone();
    remove(&mut packet, "encoding")?;
    let groups = remove(&mut packet, "groups")?;
    let order = remove(&mut packet, "branchOrder")?;
    let mut indexed = BTreeMap::new();
    for group in groups.list()? {
        expand_group(group, &mut indexed)?;
    }
    let names = order
        .list()?
        .iter()
        .map(Data::text)
        .collect::<Result<Vec<_>>>()?;
    if names.iter().collect::<BTreeSet<_>>().len() != names.len() || names.len() != indexed.len() {
        return Err(invalid("feedback branch order shape"));
    }
    let branches = names
        .into_iter()
        .map(|name| {
            indexed
                .remove(name)
                .ok_or_else(|| invalid("missing feedback branch"))
        })
        .collect::<Result<Vec<_>>>()?;
    put(&mut packet, "branches", Data::List(branches))?;
    Ok(packet)
}
fn expand_group(group: &Data, indexed: &mut BTreeMap<String, Data>) -> Result<()> {
    let common = group.field("sharedEvidence")?.map()?;
    for row in group.field("branches")?.list()? {
        let mut branch = common.clone();
        let row = row.map()?;
        if row.keys().any(|k| common.contains_key(k)) {
            return Err(invalid("conflicting feedback fields"));
        }
        branch.extend(row.clone());
        let branch = Data::Map(branch);
        let id = branch.field("id")?.identity()?.to_string();
        if indexed.insert(id, branch).is_some() {
            return Err(invalid("duplicate feedback branch identity"));
        }
    }
    Ok(())
}
