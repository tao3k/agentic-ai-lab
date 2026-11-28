//! Closed review policy is compiled by the same relational engine as caller programs.
use crate::{Data, Result, invalid_data as invalid};
use std::collections::{BTreeMap, BTreeSet};
const INPUTS: &[(&str, usize)] = &[
    ("Candidate", 3),
    ("Failure", 4),
    ("Passed", 2),
    ("ReceiptInput", 3),
    ("CurrentInput", 2),
    ("ReceiptDepends", 2),
    ("Requires", 2),
    ("ClaimDepends", 2),
    ("Cause", 3),
];
pub(super) const OUTPUTS: &[(&str, usize)] = &[
    ("KnownFailure", 3),
    ("Established", 2),
    ("Reusable", 2),
    ("Missing", 2),
    ("Unusable", 2),
    ("Denial", 2),
    ("Need", 2),
    ("ReceiptPath", 2),
    ("CausalEvidence", 3),
];
fn list(values: impl IntoIterator<Item = Data>) -> Data {
    Data::List(values.into_iter().collect())
}
fn relation(name: &str, width: usize, source: bool, rows: Data) -> Data {
    Data::object([
        ("name", name.into()),
        ("source", source.into()),
        (
            "columns",
            list((0..width).map(|_| Data::object([("kind", "symbol".into())]))),
        ),
        ("rows", rows),
    ])
}
/// Validate the complete review schema and reject conflicting logical input identities.
/// # Errors
/// Rejects unknown relations, non-symbol fields and conflicting keys.
pub fn review_sources(facts: &Data) -> Result<Data> {
    let facts = facts.map()?;
    let widths = INPUTS.iter().copied().collect::<BTreeMap<_, _>>();
    if facts.keys().any(|k| !widths.contains_key(k.as_str())) {
        return Err(invalid("unknown review relation"));
    }
    INPUTS
        .iter()
        .map(|(name, width)| review_relation(name, *width, facts.get(*name)))
        .collect::<Result<Vec<_>>>()
        .map(Data::List)
}
fn review_relation(name: &str, width: usize, rows: Option<&Data>) -> Result<Data> {
    let empty = Data::List(Vec::new());
    let rows = rows
        .unwrap_or(&empty)
        .list()?
        .iter()
        .map(|row| symbols(row, width))
        .collect::<Result<BTreeSet<_>>>()?;
    if matches!(name, "Candidate" | "Failure" | "CurrentInput")
        && rows.iter().map(|r| &r[0]).collect::<BTreeSet<_>>().len() != rows.len()
    {
        return Err(invalid(&format!("conflicting identity: {name}")));
    }
    Ok(relation(
        name,
        width,
        true,
        list(
            rows.into_iter()
                .map(|r| list(r.into_iter().map(Data::from))),
        ),
    ))
}
fn symbols(row: &Data, width: usize) -> Result<Vec<String>> {
    let values = row.list()?;
    if values.len() != width {
        return Err(invalid("review tuple arity"));
    }
    values
        .iter()
        .map(|v| v.identity().map(str::to_string))
        .collect()
}
fn atom(name: &str, terms: &[&str], negative: bool) -> Data {
    Data::object([
        ("relation", name.into()),
        ("not", negative.into()),
        (
            "terms",
            list(terms.iter().map(|t| {
                t.strip_prefix('=').map_or_else(
                    || Data::object([("var", (*t).into())]),
                    |c| Data::object([("const", c.into())]),
                )
            })),
        ),
    ])
}
fn a(name: &str, terms: &[&str]) -> Data {
    atom(name, terms, false)
}
fn n(name: &str, terms: &[&str]) -> Data {
    atom(name, terms, true)
}
fn rule(head: Data, body: impl IntoIterator<Item = Data>) -> Data {
    Data::object([("head", list([head])), ("body", list(body))])
}
pub(super) fn program(sources: &Data) -> Result<Data> {
    let mut declarations = sources.list()?.to_vec();
    declarations.extend(
        OUTPUTS
            .iter()
            .chain(&[
                ("PassedId", 1),
                ("Bound", 1),
                ("Bad", 1),
                ("Claim", 1),
                ("HasRequirement", 1),
                ("Relevant", 4),
                ("HasCause", 2),
            ])
            .map(|(name, width)| relation(name, *width, false, list([]))),
    );
    Ok(Data::object([
        ("relations", list(declarations)),
        ("rules", list(rules())),
        ("queries", list(OUTPUTS.iter().map(|(n, _)| Data::from(*n)))),
    ]))
}
fn rules() -> Vec<Data> {
    receipt_rules()
        .into_iter()
        .chain(candidate_rules())
        .collect()
}
fn receipt_rules() -> Vec<Data> {
    vec![
        rule(a("PassedId", &["r"]), [a("Passed", &["r", "p"])]),
        rule(a("Bound", &["r"]), [a("ReceiptInput", &["r", "k", "v"])]),
        rule(
            a("ReceiptPath", &["r", "d"]),
            [a("ReceiptDepends", &["r", "d"])],
        ),
        rule(
            a("ReceiptPath", &["r", "d"]),
            [
                a("ReceiptPath", &["r", "x"]),
                a("ReceiptDepends", &["x", "d"]),
            ],
        ),
        rule(
            a("Unusable", &["r", "=unbound-inputs"]),
            [a("PassedId", &["r"]), n("Bound", &["r"])],
        ),
        rule(
            a("Unusable", &["r", "=stale-or-missing-input"]),
            [
                a("ReceiptInput", &["r", "k", "v"]),
                n("CurrentInput", &["k", "v"]),
            ],
        ),
        rule(
            a("Unusable", &["r", "=missing-dependency"]),
            [a("ReceiptPath", &["r", "d"]), n("PassedId", &["d"])],
        ),
        rule(
            a("Unusable", &["r", "=circular-justification"]),
            [a("ReceiptPath", &["r", "r"])],
        ),
        rule(
            a("Unusable", &["r", "=invalid-dependency"]),
            [
                a("ReceiptPath", &["r", "d"]),
                a("Unusable", &["d", "reason"]),
            ],
        ),
        rule(a("Bad", &["r"]), [a("Unusable", &["r", "reason"])]),
        rule(
            a("Reusable", &["r", "p"]),
            [a("Passed", &["r", "p"]), n("Bad", &["r"])],
        ),
        rule(a("Established", &["p", "r"]), [a("Reusable", &["r", "p"])]),
        rule(a("Claim", &["p"]), [a("Established", &["p", "r"])]),
    ]
}
fn candidate_rules() -> Vec<Data> {
    vec![
        rule(a("Need", &["c", "p"]), [a("Requires", &["c", "p"])]),
        rule(
            a("Need", &["c", "q"]),
            [a("Need", &["c", "p"]), a("ClaimDepends", &["p", "q"])],
        ),
        rule(a("HasRequirement", &["c"]), [a("Requires", &["c", "p"])]),
        rule(
            a("Missing", &["c", "p"]),
            [a("Need", &["c", "p"]), n("Claim", &["p"])],
        ),
        rule(
            a("Relevant", &["c", "f", "i", "report"]),
            [
                a("Candidate", &["c", "s", "ci"]),
                a("Failure", &["f", "s", "i", "report"]),
            ],
        ),
        rule(
            a("KnownFailure", &["c", "f", "report"]),
            [a("Relevant", &["c", "f", "i", "report"])],
        ),
        rule(
            a("CausalEvidence", &["c", "f", "r"]),
            [a("Cause", &["c", "f", "r"]), a("Reusable", &["r", "p"])],
        ),
        rule(
            a("HasCause", &["c", "f"]),
            [a("CausalEvidence", &["c", "f", "r"])],
        ),
        rule(
            a("Denial", &["c", "=unchanged-failed-inputs"]),
            [
                a("Candidate", &["c", "s", "i"]),
                a("Failure", &["f", "s", "i", "report"]),
            ],
        ),
        rule(
            a("Denial", &["c", "=missing-causal-evidence"]),
            [
                a("Relevant", &["c", "f", "i", "report"]),
                n("HasCause", &["c", "f"]),
            ],
        ),
        rule(
            a("Denial", &["c", "=missing-premise"]),
            [a("Missing", &["c", "p"])],
        ),
        rule(
            a("Denial", &["c", "=missing-requirement-set"]),
            [
                a("Candidate", &["c", "s", "i"]),
                n("HasRequirement", &["c"]),
            ],
        ),
    ]
}
