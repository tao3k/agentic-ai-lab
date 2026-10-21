//! Reconstruct every factored observation field without executing inference.
use super::remove;
use crate::{Data, Result, evidence_store::put, invalid_data as invalid};
use std::collections::BTreeMap;
/// Restore every field factored by `compact_observation` without evaluating evidence.
/// # Errors
/// Rejects ambiguous/invalid columns and conflicting support roots.
pub fn expand_observation(value: &Data) -> Result<Data> {
    let mut packet = value.clone();
    let encoding = remove(&mut packet, "encoding")?;
    match encoding.text()? {
        "native-objects" => return remove(&mut packet, "packet"),
        "native-columns" => {}
        _ => return Err(invalid("unknown observation encoding")),
    }
    let common = remove(&mut packet, "commonConclusion")?;
    let fields = remove(&mut packet, "conclusionFields")?;
    let rows = remove(&mut packet, "conclusions")?;
    let rows = rows.list()?;
    let extras = if packet.get("observationExtras").is_some() {
        remove(&mut packet, "observationExtras")?
    } else {
        Data::List(vec![Data::Map(BTreeMap::new()); rows.len()])
    };
    let linked = if packet.get("supportRootsFromConclusion").is_some() {
        remove(&mut packet, "supportRootsFromConclusion")?
    } else {
        Data::List(vec![Data::Bool(false); rows.len()])
    };
    if extras.list()?.len() != rows.len() || linked.list()?.len() != rows.len() {
        return Err(invalid("observation column shape"));
    }
    let fields = fields
        .list()?
        .iter()
        .map(|f| f.text().map(str::to_string))
        .collect::<Result<Vec<_>>>()?;
    let mut observations = Vec::new();
    for ((row, extra), link) in rows.iter().zip(extras.list()?).zip(linked.list()?) {
        let cells = row.list()?;
        if cells.len() != fields.len() {
            return Err(invalid("observation column shape"));
        }
        let mut fact = common.map()?.clone();
        fact.extend(fields.iter().cloned().zip(cells.iter().cloned()));
        let mut observation = extra.map()?.clone();
        if observation.contains_key("conclusion") {
            return Err(invalid("conflicting conclusion field"));
        }
        if link.boolean()? {
            if observation.contains_key("support") {
                return Err(invalid("conflicting support root reference"));
            }
            let roots = fact
                .get("support-nodes")
                .ok_or_else(|| invalid("missing support root reference"))?;
            observation.insert("support".into(), Data::object([("roots", roots.clone())]));
        }
        observation.insert("conclusion".into(), Data::Map(fact));
        observations.push(Data::Map(observation));
    }
    put(&mut packet, "observations", Data::List(observations))?;
    if let Some(nodes) = packet.get("supportNodes").cloned() {
        expand_nodes(&mut packet, &nodes)?;
    }
    Ok(packet)
}
fn expand_nodes(packet: &mut Data, nodes: &Data) -> Result<()> {
    let fields = remove(packet, "nodeFields")?;
    let fields = fields
        .list()?
        .iter()
        .map(|v| v.text().map(str::to_string))
        .collect::<Result<Vec<_>>>()?;
    let predicates = if packet.get("nodeAtomPredicates").is_some() {
        Some(remove(packet, "nodeAtomPredicates")?)
    } else {
        None
    };
    let nodes = nodes
        .list()?
        .iter()
        .map(|row| {
            let row = row.list()?;
            if row.len() != fields.len() {
                return Err(invalid("node column shape"));
            }
            let mut node = Data::Map(fields.iter().cloned().zip(row.iter().cloned()).collect());
            if let Some(predicates) = &predicates {
                let predicate = predicates.field(node.field("kind")?.text()?)?.clone();
                let args = remove(&mut node, "arguments")?;
                let mut atom = vec![predicate];
                atom.extend_from_slice(args.list()?);
                put(&mut node, "atom", Data::List(atom))?;
            }
            Ok(node)
        })
        .collect::<Result<Vec<_>>>()?;
    put(packet, "supportNodes", Data::List(nodes))
}
