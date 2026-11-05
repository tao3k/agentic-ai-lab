//! Reference reuse and path extension always recheck current source-qualified predicates.
use super::owner::{BranchEvaluation, EvidenceInteraction};
use crate::{Data, Result, evidence_store::put, invalid_data as invalid};
use std::collections::BTreeSet;
impl EvidenceInteraction {
    /// # Errors
    /// Rejects malformed/duplicate references; unknown and stale references remain unknown.
    pub fn reuse(&mut self, references: &Data) -> Result<BranchEvaluation> {
        let references = references.list()?;
        if references.is_empty() || references.len() > 128 {
            return Err(invalid("select one to 128 path references"));
        }
        let names = references
            .iter()
            .map(Data::text)
            .collect::<Result<BTreeSet<_>>>()?;
        if names.len() != references.len() {
            return Err(invalid("select distinct references"));
        }
        let branches = references
            .iter()
            .enumerate()
            .map(|(i, r)| self.reused_branch(i, r))
            .collect::<Result<Vec<_>>>()?;
        let mut result = self.check(&Data::List(branches))?;
        annotate(
            &mut result.feedback,
            references,
            "requestedReference",
            false,
        )?;
        Ok(result)
    }
    fn reused_branch(&self, index: usize, reference: &Data) -> Result<Data> {
        let reference = reference.text()?;
        Ok(match self.paths.get(reference) {
            Some(path) => Data::object([
                ("id", format!("{}:reuse:{index}", path.id).into()),
                ("conditions", path.conditions.clone()),
                ("reference", reference.into()),
            ]),
            None => Data::object([
                ("id", format!("unknown:{index}").into()),
                ("operation", "".into()),
                ("arguments", Data::List(Vec::new())),
                ("reference", reference.into()),
            ]),
        })
    }
    /// # Errors
    /// Rejects malformed paths. Every prior and new condition is checked in the same generation.
    pub fn extend(&mut self, paths: &Data) -> Result<BranchEvaluation> {
        let paths = paths.list()?;
        if paths.is_empty() || paths.len() > 128 {
            return Err(invalid("select one to 128 paths"));
        }
        let branches = paths
            .iter()
            .map(|p| self.extended_branch(p))
            .collect::<Result<Vec<_>>>()?;
        let mut result = self.check(&Data::List(branches))?;
        annotate(&mut result.feedback, paths, "extendedReference", true)?;
        Ok(result)
    }
    fn extended_branch(&self, path: &Data) -> Result<Data> {
        let id = path.field("id")?.identity()?;
        let previous = path
            .get("reference")
            .and_then(|r| r.text().ok())
            .and_then(|r| self.paths.get(r));
        let conditions = path
            .get("conditions")
            .and_then(|c| c.list().ok())
            .filter(|c| !c.is_empty());
        match (previous, conditions) {
            (Some(previous), Some(conditions)) => {
                let mut all = previous.conditions.list()?.to_vec();
                all.extend_from_slice(conditions);
                Ok(Data::object([
                    ("id", id.into()),
                    ("conditions", Data::List(all)),
                ]))
            }
            _ => Ok(Data::object([
                ("id", id.into()),
                ("operation", "".into()),
                ("arguments", Data::List(Vec::new())),
            ])),
        }
    }
}
fn annotate(result: &mut Data, inputs: &[Data], field: &str, extended: bool) -> Result<()> {
    let mut branches = result.field("branches")?.list()?.to_vec();
    for (branch, input) in branches.iter_mut().zip(inputs) {
        let reference = if extended {
            input.get("reference").cloned().unwrap_or(Data::Null)
        } else {
            input.clone()
        };
        put(branch, field, reference)?;
    }
    put(result, "branches", Data::List(branches))
}
