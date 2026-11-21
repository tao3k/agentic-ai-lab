//! Ordered presentation of witnesses, with auxiliary rows indexed once.
use super::cells::text;
use crate::{Data, Result};
use std::collections::BTreeMap;

#[derive(Default)]
struct Family {
    observations: Vec<Data>,
    hypotheses: Vec<Data>,
    factors: BTreeMap<String, BTreeMap<String, Vec<Data>>>,
    links: Vec<Data>,
    conflict: bool,
    unknown: bool,
}
impl Family {
    fn index(&mut self, row: &Data) -> Result<()> {
        match text(row, 0)? {
            "factor" => self
                .factors
                .entry(text(row, 2)?.into())
                .or_default()
                .entry(text(row, 4)?.into())
                .or_default()
                .push(text(row, 5)?.into()),
            "link" => self.links.push(Data::object([
                ("claim", text(row, 4)?.into()),
                ("relation", text(row, 5)?.into()),
                ("witness", text(row, 2)?.into()),
            ])),
            "conflict" => self.conflict = true,
            "unknown" => self.unknown = true,
            _ => {}
        }
        Ok(())
    }
    fn witness(&mut self, row: &Data) -> Result<()> {
        let kind = text(row, 0)?;
        if !matches!(kind, "support" | "counter" | "hypothesis") {
            return Ok(());
        }
        let fs = self.factors.remove(text(row, 2)?).unwrap_or_default();
        let mut witness = BTreeMap::from([
            ("id".into(), text(row, 2)?.into()),
            ("digest".into(), text(row, 3)?.into()),
            (
                "polarity".into(),
                (if kind == "hypothesis" {
                    text(row, 4)?
                } else {
                    kind
                })
                .into(),
            ),
            (
                "factors".into(),
                Data::Map(fs.into_iter().map(|(k, v)| (k, Data::List(v))).collect()),
            ),
        ]);
        if kind == "hypothesis" {
            witness.insert("source".into(), text(row, 5)?.into());
            self.hypotheses.push(Data::Map(witness));
        } else {
            witness.insert("source".into(), text(row, 4)?.into());
            witness.insert("receipt".into(), text(row, 5)?.into());
            self.observations.push(Data::Map(witness));
        }
        Ok(())
    }
}
pub(super) fn family(source: &str, claim: &str, items: &[Data]) -> Result<Data> {
    let mut family = Family::default();
    items.iter().try_for_each(|row| family.index(row))?;
    items.iter().try_for_each(|row| family.witness(row))?;
    Ok(Data::object([
        ("claim", claim.into()),
        ("observations", Data::List(family.observations)),
        ("hypotheses", Data::List(family.hypotheses)),
        ("links", Data::List(family.links)),
        ("conflict", family.conflict.into()),
        ("unknown", family.unknown.into()),
        (
            "reference",
            Data::object([
                ("claim", claim.into()),
                ("sourceIdentity", source.into()),
                (
                    "contentIdentity",
                    Data::List(items.to_vec()).digest().into(),
                ),
            ]),
        ),
    ]))
}
pub(super) fn counts(items: &[Data]) -> Result<Data> {
    let counts = items
        .iter()
        .try_fold([0usize; 3], |mut counts, row| -> Result<_> {
            match text(row, 0)? {
                "support" => counts[0] += 1,
                "counter" => counts[1] += 1,
                "hypothesis" => counts[2] += 1,
                _ => {}
            }
            Ok(counts)
        })?;
    Ok(Data::object([
        ("support", counts[0].into()),
        ("counter", counts[1].into()),
        ("hypotheses", counts[2].into()),
    ]))
}
