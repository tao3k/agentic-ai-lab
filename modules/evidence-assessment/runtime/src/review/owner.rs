//! Review owns current sources and checked component receipts; it grants no permissions.
use super::policy::{program, review_sources};
use crate::{
    Data, Engine, EvidenceChain, FactLimits, Result, evidence_store::put, invalid_data as invalid,
};
use std::collections::BTreeSet;
/// Finite supplied observations and declared dependencies, with explicit source invalidation.
pub struct EvidenceReview {
    sources: Data,
    chain: EvidenceChain,
}
impl EvidenceReview {
    /// # Errors
    /// Rejects conflicting/invalid facts and closed engine owners.
    pub fn new(engine: &Engine, facts: &Data) -> Result<Self> {
        let sources = review_sources(facts)?;
        let chain = EvidenceChain::new(engine, sources.clone(), true, FactLimits::default())?;
        Ok(Self { sources, chain })
    }
    /// # Errors
    /// Validates the complete input before invalidating retained review results.
    pub fn replace(&mut self, facts: &Data) -> Result<()> {
        let sources = review_sources(facts)?;
        self.chain.replace(sources.clone())?;
        self.sources = sources;
        Ok(())
    }
    /// # Errors
    /// Fails without a receipt when evaluation is rejected, limited or the engine is closed.
    pub fn review(&mut self) -> Result<Data> {
        let mut receipt = self.chain.query(&program(&self.sources)?)?;
        let denied = receipt
            .field("result")?
            .field("relations")?
            .field("Denial")?
            .list()?
            .iter()
            .map(|r| r.list()?[0].text().map(str::to_string))
            .collect::<Result<BTreeSet<_>>>()?;
        let candidates = self
            .sources
            .list()?
            .iter()
            .find(|s| s.get("name") == Some(&Data::Text("Candidate".into())))
            .ok_or_else(|| invalid("missing review candidate source"))?
            .field("rows")?
            .list()?;
        let decisions = candidates
            .iter()
            .map(|r| {
                let row = r.list()?;
                let name = row[0].text()?;
                Ok(Data::object([
                    ("candidate", name.into()),
                    (
                        "decision",
                        if denied.contains(name) {
                            "DENY"
                        } else {
                            "REVIEW_REQUIRED"
                        }
                        .into(),
                    ),
                ]))
            })
            .collect::<Result<Vec<_>>>()?;
        put(&mut receipt, "schema", "ascent-evidence-review.v1".into())?;
        put(&mut receipt, "decisions", Data::List(decisions))?;
        put(&mut receipt, "executionAuthorized", false.into())?;
        put(&mut receipt,"scope","Finite supplied observations and declared dependencies; not implementation correctness or execution permission.".into())?;
        Ok(receipt)
    }
    /// # Errors
    /// Rejects stale references and nonunary review projections.
    pub fn answer(&self, reference: &str, relation: &str) -> Result<Data> {
        self.chain.answer(reference, relation)
    }
    pub fn close(&mut self) {
        self.chain.close();
    }
}
