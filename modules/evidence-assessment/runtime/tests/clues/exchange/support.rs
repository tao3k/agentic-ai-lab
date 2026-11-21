use super::{Cancellation, ClueExchange, ClueProjection, Data, Limits, Runtime};

pub(in crate::clues) const PROJECTION: &str = r"
(define-program (project)
 (sources clue factor link) (outputs clue factor link)
 (relation clue (id digest claim polarity role source))
 (relation factor (id digest name value))
 (relation link (claim target label id digest)))
(define-program (select)
 (sources clue factor binding) (outputs question)
 (relation clue (id digest claim polarity role source))
 (relation factor (id digest name value))
 (relation binding (name value))
 (relation question (claim))
 ((question C) <-- (clue I D C _ _ _) (factor I D N V) (binding N V)))
";

pub(in crate::clues) fn list(rows: &[&[&str]]) -> Data {
    Data::List(
        rows.iter()
            .map(|r| Data::List(r.iter().map(|v| (*v).into()).collect()))
            .collect(),
    )
}
pub(super) fn facts() -> Data {
    Data::object([
        (
            "clue",
            list(&[&[
                "known",
                "sha",
                "old-is-unexplored",
                "counter",
                "observation",
                "receipt",
            ]]),
        ),
        ("factor", list(&[&["known", "sha", "mechanism", "old"]])),
        (
            "link",
            list(&[&[
                "old-is-unexplored",
                "open",
                "not-same-cause",
                "known",
                "sha",
            ]]),
        ),
    ])
}
pub(super) fn exchange(engine: &Runtime) -> ClueExchange {
    ClueExchange::new(
        engine,
        ClueProjection {
            sources: &[PROJECTION],
            constructor: "project",
            supplied: &facts(),
            attestations: &Data::object([("receipt", "sha".into())]),
        },
        &Limits::default(),
        &Cancellation::default(),
    )
    .unwrap()
}

pub(super) const ANCHORED_SELECTOR: &str = r#"
(define-program (anchored)
 (sources clue factor binding)
 (outputs question associated association_gap applicability_gap)
 (relation clue (id digest claim polarity role source))
 (relation factor (id digest name value))
 (relation binding (name value))
 (relation associated (claim))
 (relation applicable (claim))
 (relation question (claim))
 (relation has_association (name value))
 (relation association_gap (name value))
 (relation applicability_gap (claim))
 ((associated C) <-- (clue I D C _ _ _) (factor I D N V) (binding N V))
 ((applicable C) <-- (clue I D C _ _ _)
   (factor I D (lit "condition") (lit "current")))
 ((question C) <-- (associated C) (applicable C))
 ((has_association N V) <-- (clue I D C _ _ _) (factor I D N V) (binding N V))
 ((association_gap N V) <-- (binding N V) (not (has_association N V)))
 ((applicability_gap C) <-- (associated C) (not (applicable C))))
"#;

pub(in crate::clues) fn anchored_exchange(engine: &Runtime, condition: &str) -> ClueExchange {
    let input = Data::object([
        (
            "clue",
            list(&[
                &["yes", "a", "header", "support", "observation", "trace-a"],
                &["no", "b", "header", "counter", "observation", "trace-b"],
                &["far", "c", "unrelated", "support", "observation", "trace-c"],
            ]),
        ),
        (
            "factor",
            list(&[
                &["yes", "a", "mechanism", "publication"],
                &["yes", "a", "condition", condition],
            ]),
        ),
        (
            "link",
            list(&[&["header", "open-writer", "producer-unidentified", "yes", "a"]]),
        ),
    ]);
    ClueExchange::new(
        engine,
        ClueProjection {
            sources: &[PROJECTION],
            constructor: "project",
            supplied: &input,
            attestations: &Data::object([
                ("trace-a", "a".into()),
                ("trace-b", "b".into()),
                ("trace-c", "c".into()),
            ]),
        },
        &Limits::default(),
        &Cancellation::default(),
    )
    .unwrap()
}

pub(in crate::clues) fn at<'a>(value: &'a Data, path: &[&str]) -> &'a Data {
    path.iter()
        .fold(value, |value, key| value.field(key).unwrap())
}

pub(in crate::clues) fn rows<'a>(value: &'a Data, path: &[&str]) -> &'a [Data] {
    at(value, path).list().unwrap()
}
