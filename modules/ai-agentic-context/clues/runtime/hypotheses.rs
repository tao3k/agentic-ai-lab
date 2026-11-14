//! Stage untrusted hypotheses atomically; only the owner commits the candidate.
use super::invalid;
use crate::{Data, Result, Row};
use std::collections::{BTreeMap, BTreeSet};

fn factor(pair: &Data, id: &str, digest: &str) -> Result<Row> {
    let pair = pair.list()?;
    if pair.len() != 2 {
        return Err(invalid("factor name/value pair required"));
    }
    Ok(Row::from(vec![
        id.into(),
        digest.into(),
        pair[0].identity()?.into(),
        pair[1].text()?.into(),
    ]))
}
fn append_factors(
    hint: &Data,
    id: &str,
    digest: &str,
    candidate: &mut BTreeMap<String, Vec<Row>>,
) -> Result<()> {
    let Some(factors) = hint.get("factors") else {
        return Ok(());
    };
    factors.list()?.iter().try_for_each(|pair| {
        candidate
            .entry("factor".into())
            .or_default()
            .push(factor(pair, id, digest)?);
        Ok(())
    })
}
pub(super) fn append_hypothesis(
    hint: &Data,
    ids: &mut BTreeSet<String>,
    candidate: &mut BTreeMap<String, Vec<Row>>,
) -> Result<()> {
    if hint.map()?.keys().any(|key| {
        !matches!(
            key.as_str(),
            "id" | "claim" | "polarity" | "source" | "factors"
        )
    }) {
        return Err(invalid("hypotheses cannot supply authority fields"));
    }
    let id = hint.field("id")?.identity()?;
    if !ids.insert(id.into()) {
        return Err(invalid("duplicate clue identity"));
    }
    let claim = hint.field("claim")?.identity()?;
    let polarity = hint.field("polarity")?.text()?;
    if !matches!(polarity, "support" | "counter") {
        return Err(invalid("unknown clue polarity"));
    }
    let source = hint.field("source")?.identity()?;
    let digest = hint.digest();
    candidate
        .entry("clue".into())
        .or_default()
        .push(Row::from(vec![
            id.into(),
            digest.as_str().into(),
            claim.into(),
            polarity.into(),
            "hypothesis".into(),
            source.into(),
        ]));
    append_factors(hint, id, &digest, candidate)
}
