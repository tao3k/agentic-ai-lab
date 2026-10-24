//! Source-bound packets assemble already checked facts and optional named support.
use super::ComputationalEvidence;
use crate::{Data, Result, evidence_store::put, invalid_data as invalid};
use std::collections::BTreeMap;
/// Scheme observation request. Source and candidate are checked against the private receipt.
pub struct ObservationRequest<'a> {
    pub source: &'a Data,
    pub candidate: &'a Data,
    pub handle: u64,
    pub atoms: &'a Data,
    pub support: bool,
}
#[derive(Default)]
struct Packet {
    observations: Vec<Data>,
    scope: Option<Data>,
    nodes: BTreeMap<usize, Data>,
}
impl ComputationalEvidence {
    /// One detached packet; stale/unknown atoms never acquire positive support.
    /// # Errors
    /// Rejects invalid atom counts and closed owners.
    pub fn observe(&self, request: &ObservationRequest<'_>) -> Result<Data> {
        let atoms = request.atoms.list()?;
        if atoms.is_empty() || atoms.len() > 32 {
            return Err(invalid("one to 32 atoms required"));
        }
        let mut packet = Packet::default();
        for atom in atoms {
            let fact = self.fact(request.source, request.candidate, request.handle, atom)?;
            let fragment = checked_fragment(self, request, atom, &fact)?;
            packet.append(fact, fragment.as_ref())?;
        }
        packet.finish()
    }
}
fn checked_fragment(
    store: &ComputationalEvidence,
    request: &ObservationRequest<'_>,
    atom: &Data,
    fact: &Data,
) -> Result<Option<Data>> {
    if !request.support || fact.field("status")?.text()? != "verified" {
        return Ok(None);
    }
    let fragment = store.fragment(request.source, request.candidate, request.handle, atom)?;
    if fragment.field("status")?.text()? != "verified" {
        return Err(invalid("proof changed during observation"));
    }
    Ok(Some(fragment))
}
fn scope_map(current: &Data) -> Result<Data> {
    current
        .list()?
        .iter()
        .map(|pair| {
            let pair = pair.list()?;
            if pair.len() != 2 {
                return Err(invalid("observation scope shape"));
            }
            Ok((pair[0].text()?.to_string(), pair[1].clone()))
        })
        .collect::<Result<BTreeMap<_, _>>>()
        .map(Data::Map)
}
impl Packet {
    fn append(&mut self, mut fact: Data, fragment: Option<&Data>) -> Result<()> {
        let mut observation = BTreeMap::new();
        self.admit_scope(&mut fact)?;
        if let Some(fragment) = fragment {
            observation.insert(
                "support".into(),
                Data::object([("roots", fragment.field("roots")?.clone())]),
            );
            self.support(fragment.field("nodes")?)?;
        }
        observation.insert("conclusion".into(), fact);
        self.observations.push(Data::Map(observation));
        Ok(())
    }
    fn admit_scope(&mut self, fact: &mut Data) -> Result<()> {
        let Data::Map(fields) = fact else {
            return Err(invalid("observation fact object required"));
        };
        let Some(current) = fields.remove("scope") else {
            return Ok(());
        };
        let current = scope_map(&current)?;
        if self.scope.as_ref().is_some_and(|old| old != &current) {
            return Err(invalid("mixed observation scopes"));
        }
        self.scope = Some(current);
        Ok(())
    }
    fn support(&mut self, nodes: &Data) -> Result<()> {
        for n in nodes.list()? {
            let (id, node) = proof_node(n)?;
            if self
                .nodes
                .insert(id, node.clone())
                .is_some_and(|old| old != node)
            {
                return Err(invalid("mixed proof nodes"));
            }
        }
        Ok(())
    }
    fn finish(self) -> Result<Data> {
        let mut result = Data::object([("observations", Data::List(self.observations))]);
        if let Some(scope) = self.scope {
            put(&mut result, "scope", scope)?;
        }
        if !self.nodes.is_empty() {
            put(
                &mut result,
                "supportNodes",
                Data::List(self.nodes.into_values().collect()),
            )?;
        }
        Ok(result)
    }
}
fn proof_node(value: &Data) -> Result<(usize, Data)> {
    let n = value.list()?;
    if n.len() != 6 {
        return Err(invalid("native proof node shape"));
    }
    let mut atom = vec![n[2].clone()];
    atom.extend_from_slice(n[3].list()?);
    Ok((
        n[0].index()?,
        Data::object([
            ("id", n[0].clone()),
            ("kind", n[1].clone()),
            ("atom", Data::List(atom)),
            ("ruleLabel", n[4].clone()),
            ("parents", n[5].clone()),
        ]),
    ))
}
