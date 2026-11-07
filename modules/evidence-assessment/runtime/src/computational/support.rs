//! Acyclic positive witnesses selected from an independently checked finite equation graph.
use crate::{Data, ProvenanceGraph, Result, evidence_store::rows_data, invalid_data as invalid};
use std::collections::{BTreeMap, BTreeSet};
pub(super) fn acyclic(graph: &ProvenanceGraph) -> Result<Vec<Data>> {
    let mut completed = BTreeMap::new();
    let mut nodes = Vec::new();
    loop {
        let before = completed.len();
        for edge in &graph.edges {
            if !ready(edge, &completed) {
                continue;
            }
            let fact = graph
                .nodes
                .get(edge.output)
                .ok_or_else(|| invalid("proof output node"))?;
            let id = nodes.len();
            let row = rows_data(std::slice::from_ref(&fact.row))?.list()?[0].clone();
            let parents = edge
                .inputs
                .iter()
                .map(|p| Data::from(completed[p]))
                .collect();
            let kind = if edge.rule.is_none() {
                "source"
            } else {
                "rule"
            };
            nodes.push(Data::List(vec![
                id.into(),
                kind.into(),
                fact.relation.clone().into(),
                row,
                edge.rule.map_or(Data::Bool(false), |n| Data::from(n + 1)),
                Data::List(parents),
            ]));
            completed.insert(edge.output, id);
        }
        if completed.len() == before {
            break;
        }
    }
    if completed.len() != graph.nodes.len() {
        return Err(invalid("finite graph lacks grounded acyclic witnesses"));
    }
    Ok(nodes)
}
pub(super) fn ancestors(nodes: &[Data], roots: &Data) -> Result<Vec<Data>> {
    let mut pending = roots
        .list()?
        .iter()
        .map(Data::index)
        .collect::<Result<Vec<_>>>()?;
    let mut selected = BTreeSet::new();
    while let Some(id) = pending.pop() {
        if !selected.insert(id) {
            continue;
        }
        let node = nodes
            .get(id)
            .ok_or_else(|| invalid("missing proof ancestor"))?
            .list()?;
        pending.extend(
            node[5]
                .list()?
                .iter()
                .map(Data::index)
                .collect::<Result<Vec<_>>>()?,
        );
    }
    Ok(selected.into_iter().map(|i| nodes[i].clone()).collect())
}

fn ready(edge: &crate::ProvenanceEdge, completed: &BTreeMap<usize, usize>) -> bool {
    !completed.contains_key(&edge.output) && edge.inputs.iter().all(|n| completed.contains_key(n))
}
