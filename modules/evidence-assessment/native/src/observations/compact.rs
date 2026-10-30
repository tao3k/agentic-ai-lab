//! Lossless projections of already checked observations; no inference or admission.
use crate::{Data, Result, evidence_store::put, invalid_data as invalid};
use std::collections::BTreeMap;
pub(crate) fn remove(value: &mut Data, key: &str) -> Result<Data> {
    let Data::Map(fields) = value else {
        return Err(invalid("observation object required"));
    };
    fields
        .remove(key)
        .ok_or_else(|| invalid("missing observation field"))
}
/// Factor equal conclusion fields and support roots without changing any native assertion.
/// # Errors
/// Rejects malformed observation/node fields.
pub fn compact_observation(packet: &Data) -> Result<Data> {
    let mut packet = packet.clone();
    let observations = remove(&mut packet, "observations")?;
    let observations = observations.list()?;
    let facts = observations
        .iter()
        .map(|o| o.field("conclusion")?.map())
        .collect::<Result<Vec<_>>>()?;
    if facts.is_empty() || facts.iter().any(|f| f.keys().ne(facts[0].keys())) {
        put(
            &mut packet,
            "observations",
            Data::List(observations.to_vec()),
        )?;
        return Ok(Data::object([
            ("encoding", "native-objects".into()),
            ("packet", packet),
        ]));
    }
    compact_columns(packet, observations, &facts)
}
fn compact_columns(
    mut packet: Data,
    observations: &[Data],
    facts: &[&BTreeMap<String, Data>],
) -> Result<Data> {
    let common = facts[0]
        .iter()
        .filter(|(k, v)| facts.iter().all(|f| f.get(*k) == Some(*v)))
        .map(|(k, v)| (k.clone(), v.clone()))
        .collect::<BTreeMap<_, _>>();
    let fields = facts[0]
        .keys()
        .filter(|k| !common.contains_key(*k))
        .cloned()
        .collect::<Vec<_>>();
    let rows = facts
        .iter()
        .map(|f| Data::List(fields.iter().map(|k| f[k].clone()).collect()))
        .collect();
    let mut extras = Vec::new();
    let mut linked = Vec::new();
    for (observation, fact) in observations.iter().zip(facts) {
        let mut extra = observation.map()?.clone();
        extra.remove("conclusion");
        let roots = fact.get("support-nodes");
        let same = roots.is_some_and(|r| {
            extra == BTreeMap::from([("support".into(), Data::object([("roots", r.clone())]))])
        });
        linked.push(Data::Bool(same));
        if same {
            extra.clear();
        }
        extras.push(Data::Map(extra));
    }
    put(&mut packet, "encoding", "native-columns".into())?;
    put(&mut packet, "commonConclusion", Data::Map(common))?;
    put(
        &mut packet,
        "conclusionFields",
        Data::List(fields.into_iter().map(Data::from).collect()),
    )?;
    put(&mut packet, "conclusions", Data::List(rows))?;
    if linked.contains(&Data::Bool(true)) {
        put(
            &mut packet,
            "supportRootsFromConclusion",
            Data::List(linked),
        )?;
    }
    if extras
        .iter()
        .any(|e| !e.map().is_ok_and(BTreeMap::is_empty))
    {
        put(&mut packet, "observationExtras", Data::List(extras))?;
    }
    if let Some(nodes) = packet.get("supportNodes").cloned() {
        compact_nodes(&mut packet, &nodes)?;
    }
    Ok(packet)
}
fn compact_nodes(packet: &mut Data, nodes: &Data) -> Result<()> {
    let nodes = nodes.list()?;
    let original = ["id", "kind", "atom", "ruleLabel", "parents"];
    for node in nodes {
        validate_node(node)?;
    }
    let predicates = atom_predicates(nodes)?;
    let factor = predicates.is_some();
    let fields = if factor {
        ["id", "kind", "arguments", "ruleLabel", "parents"]
    } else {
        original
    };
    let rows = nodes
        .iter()
        .map(|n| {
            fields
                .iter()
                .map(|k| {
                    if *k == "arguments" {
                        Ok(Data::List(n.field("atom")?.list()?[1..].to_vec()))
                    } else {
                        n.field(k).cloned()
                    }
                })
                .collect::<Result<Vec<_>>>()
                .map(Data::List)
        })
        .collect::<Result<Vec<_>>>()?;
    put(
        packet,
        "nodeFields",
        Data::List(fields.into_iter().map(Data::from).collect()),
    )?;
    put(packet, "supportNodes", Data::List(rows))?;
    if factor {
        put(
            packet,
            "nodeAtomPredicates",
            Data::Map(predicates.ok_or_else(|| invalid("missing observed predicates"))?),
        )?;
    }
    Ok(())
}

fn validate_node(node: &Data) -> Result<()> {
    if !node
        .map()?
        .keys()
        .map(String::as_str)
        .eq(["atom", "id", "kind", "parents", "ruleLabel"])
    {
        return Err(invalid("unknown native node fields"));
    }
    Ok(())
}
fn atom_predicates(nodes: &[Data]) -> Result<Option<BTreeMap<String, Data>>> {
    if nodes.is_empty() {
        return Ok(None);
    }
    let mut predicates = BTreeMap::new();
    for node in nodes {
        let atom = node.field("atom")?.list()?;
        let Some(predicate) = atom.first().filter(|v| v.text().is_ok()) else {
            return Ok(None);
        };
        let kind = node.field("kind")?.text()?;
        if predicates
            .insert(kind.into(), predicate.clone())
            .is_some_and(|p| p != *predicate)
        {
            return Ok(None);
        }
    }
    Ok(Some(predicates))
}
