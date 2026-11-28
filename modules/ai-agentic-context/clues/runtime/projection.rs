//! Validate projected facts before publishing an exchange owner.
use super::{data_rows, invalid};
use crate::{Data, Result, Row};
use std::collections::{BTreeMap, BTreeSet};

type Identities = BTreeSet<(String, String)>;

pub(super) fn projection_facts(
    projected: &BTreeMap<String, Vec<Row>>,
) -> Result<BTreeMap<String, Vec<Row>>> {
    ["clue", "factor", "link"]
        .into_iter()
        .map(|name| {
            let rows = projected
                .get(name)
                .ok_or_else(|| invalid("projection requires clue, factor and link outputs"))?;
            Ok((name.into(), rows.clone()))
        })
        .collect()
}
fn attestation(fields: &[Data], attestations: &Data) -> Result<Option<Row>> {
    let id = fields[0].text()?;
    let digest = fields[1].identity()?;
    fields[2].identity()?;
    if !matches!(fields[3].text()?, "support" | "counter") {
        return Err(invalid("unknown clue polarity"));
    }
    match fields[4].text()? {
        "hypothesis" => Ok(None),
        "observation" => {
            let source = fields[5].identity()?;
            if attestations.get(source).map(Data::text).transpose()? != Some(digest) {
                return Err(invalid(
                    "observation does not match host source attestation",
                ));
            }
            let receipt =
                Data::object([("source", source.into()), ("digest", digest.into())]).digest();
            Ok(Some(Row::from(vec![
                id.into(),
                digest.into(),
                receipt.as_str().into(),
            ])))
        }
        _ => Err(invalid("unknown clue role")),
    }
}
pub(super) fn validate_clues(clues: &[Row], attestations: &Data) -> Result<(Identities, Vec<Row>)> {
    let mut ids = BTreeSet::new();
    let mut identities = BTreeSet::new();
    let mut attested = Vec::new();
    clues.iter().try_for_each(|row| {
        let packet = data_rows(std::slice::from_ref(row))?;
        let fields = packet.list()?[0].list()?;
        if fields.len() != 6 || !ids.insert(fields[0].identity()?.to_owned()) {
            return Err(invalid("unique six-field clues required"));
        }
        if let Some(receipt) = attestation(fields, attestations)? {
            attested.push(receipt);
        }
        identities.insert((
            fields[0].text()?.to_owned(),
            fields[1].identity()?.to_owned(),
        ));
        Ok(())
    })?;
    Ok((identities, attested))
}
fn reference(row: &Row, arity: usize, offset: usize, identities: &Identities) -> Result<()> {
    let packet = data_rows(std::slice::from_ref(row))?;
    let fields = packet.list()?[0].list()?;
    if fields.len() != arity
        || !identities.contains(&(
            fields[offset].text()?.into(),
            fields[offset + 1].text()?.into(),
        ))
    {
        return Err(invalid("factor or link lacks its clue identity"));
    }
    Ok(())
}
pub(super) fn validate_references(
    facts: &BTreeMap<String, Vec<Row>>,
    identities: &Identities,
) -> Result<()> {
    [("factor", 4, 0), ("link", 5, 3)]
        .into_iter()
        .try_for_each(|(name, arity, offset)| {
            facts[name]
                .iter()
                .try_for_each(|row| reference(row, arity, offset, identities))
        })
}
