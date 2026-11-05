use super::exchange::{PROJECTION, anchored_exchange, at, list, rows};
use agentic_ai_lab_reasoning::{
    Cancellation, ClueExchange, Data, Limits, Runtime, clue_sexpr, read_clue_request,
};
use agentic_ai_lab_reasoning::{ClueProjection, ClueSelector};

const CONJUNCTIVE_SELECTOR: &str = r"(define-program (query)
      (sources clue factor binding)
      (outputs question matched unknown_binding conjunction_gap)
      (include clue-selection-schema)
      (relation question (claim))
      (relation matched (claim id digest role))
      (relation missing (id digest))
      (relation witnessed (id digest name value))
      (relation has_binding (name))
      (relation has_match (name value))
      (relation matched_binding (name value))
      (relation unknown_binding (name value))
      (relation conjunction_gap (name value))
      ((has_binding N) <-- (binding N _))
      ((witnessed I D N V) <-- (factor I D N V) (binding N V))
      ((missing I D) <-- (clue I D _ _ _ _) (binding N V)
        (not (witnessed I D N V)))
      ((matched C I D R) <-- (has_binding _) (clue I D C _ R _)
        (not (missing I D)))
      ((question C) <-- (matched C _ _ _))
      ((has_match N V) <-- (clue I D _ _ _ _) (factor I D N V) (binding N V))
      ((unknown_binding N V) <-- (binding N V) (not (has_match N V)))
      ((matched_binding N V) <-- (matched _ I D _) (factor I D N V) (binding N V))
      ((conjunction_gap N V) <-- (has_match N V) (not (matched_binding N V))))";

#[test]
fn scheme_request_reuses_the_bounded_reader_and_never_evaluates_forms() {
    let expected = Data::object([
        ("bindings", list(&[&["arbitrary-factor", "new-hypothesis"]])),
        ("expand", Data::List(vec!["unknown-claim".into()])),
        ("checkpoint", "clue-read:opaque".into()),
    ]);
    assert_eq!(read_clue_request(&clue_sexpr(&expected)).unwrap(), expected);
    assert_eq!(
        read_clue_request("((questions (\"a\" \"b\")))").unwrap(),
        Data::object([("questions", Data::List(vec!["a".into(), "b".into()]))])
    );
    for rejected in [
        "((checkpoint \"a\") (checkpoint \"b\"))",
        "((unknownField \"value\"))",
        "((bindings (system \"command\")))",
        "(begin (display \"not data\"))",
        "((bindings ())) ((expand ()))",
        "((questions 2))",
        "((bindings ((\"name\"))))",
        "((displayBytes 0))",
        "((constructor \"ignored\"))",
    ] {
        assert!(read_clue_request(rejected).is_err(), "{rejected}");
    }
}

#[test]
fn factor_conjunction_keeps_witness_identity_and_explains_incompatible_anchors() {
    let engine = Runtime::new(1).unwrap();
    let owner = anchored_exchange(&engine, "current");
    let selector = CONJUNCTIVE_SELECTOR;
    let limits = Limits::default();
    let cancel = Cancellation::default();
    let matched = owner
        .select(
            ClueSelector {
                sources: &[selector],
                constructor: "query",
            },
            &list(&[&["mechanism", "publication"], &["condition", "current"]]),
            &limits,
            &cancel,
        )
        .unwrap();
    assert_eq!(at(&matched, &["question"]), &list(&[&["header"]]));
    assert_eq!(
        at(&matched, &["matched"]),
        &list(&[&["header", "yes", "a", "observation"]])
    );
    assert_eq!(at(&matched, &["unknown_binding"]), &list(&[]));
    assert_eq!(at(&matched, &["conjunction_gap"]), &list(&[]));
    // An unknown value is a gap, not evidence of absence.
    let split = owner
        .select(
            ClueSelector {
                sources: &[selector],
                constructor: "query",
            },
            &list(&[
                &["mechanism", "publication"],
                &["condition", "current"],
                &["condition", "missing"],
            ]),
            &limits,
            &cancel,
        )
        .unwrap();
    assert_eq!(at(&split, &["question"]), &list(&[]));
    assert_eq!(
        at(&split, &["unknown_binding"]),
        &list(&[&["condition", "missing"]])
    );
    assert_eq!(rows(&split, &["conjunction_gap"]).len(), 2);
    let input = Data::object([
        (
            "clue",
            list(&[
                &["a", "x", "same", "support", "observation", "ra"],
                &["b", "y", "same", "counter", "observation", "rb"],
            ]),
        ),
        (
            "factor",
            list(&[
                &["a", "x", "mechanism", "publication"],
                &["b", "y", "condition", "current"],
            ]),
        ),
        ("link", list(&[])),
    ]);
    let split_owner = ClueExchange::new(
        &engine,
        ClueProjection {
            sources: &[PROJECTION],
            constructor: "project",
            supplied: &input,
            attestations: &Data::object([("ra", "x".into()), ("rb", "y".into())]),
        },
        &limits,
        &cancel,
    )
    .unwrap();
    let split = split_owner
        .select(
            ClueSelector {
                sources: &[selector],
                constructor: "query",
            },
            &list(&[&["mechanism", "publication"], &["condition", "current"]]),
            &limits,
            &cancel,
        )
        .unwrap();
    assert_eq!(at(&split, &["question"]), &list(&[]));
    assert_eq!(at(&split, &["unknown_binding"]), &list(&[]));
    assert_eq!(rows(&split, &["conjunction_gap"]).len(), 2);
}
