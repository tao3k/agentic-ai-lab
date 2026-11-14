use super::{Data, defer_families, present_relations, rows};
use std::collections::BTreeMap;

#[test]
fn scope_reference_yields_space_to_a_complete_family() {
    let mut brief = BTreeMap::from([
        (
            "scopeReference".into(),
            Data::object([
                ("sourceIdentity", "source".into()),
                (
                    "claims",
                    Data::List(
                        (0..64)
                            .map(|i| Data::from(format!("claim-{i}-{}", "x".repeat(56))))
                            .collect(),
                    ),
                ),
            ]),
        ),
        (
            "families".into(),
            Data::List(vec![Data::object([
                ("claim", "retained-family".into()),
                ("body", "y".repeat(4000).into()),
            ])]),
        ),
    ]);
    let original = brief["families"].clone();
    assert!(super::super::clue_sexpr(&Data::Map(brief.clone())).len() > 8192);
    assert!(defer_families("source", &[], &mut brief, 8192).unwrap());
    assert_eq!(brief["families"], original);
    assert!(
        brief["scopeReference"]
            .map()
            .unwrap()
            .contains_key("contentIdentity")
    );
    assert!(
        !brief["scopeReference"]
            .map()
            .unwrap()
            .contains_key("claims")
    );
}

#[test]
fn scope_reference_yields_space_to_a_derived_relation() {
    let mut brief = BTreeMap::from([
        (
            "scopeReference".into(),
            Data::object([
                ("sourceIdentity", "source".into()),
                (
                    "claims",
                    Data::List(
                        (0..64)
                            .map(|i| Data::from(format!("claim-{i}-{}", "x".repeat(56))))
                            .collect(),
                    ),
                ),
            ]),
        ),
        ("families".into(), Data::List(vec![])),
        ("deferred".into(), Data::List(vec![])),
        (
            "deferredRelations".into(),
            Data::List(vec![Data::object([("relation", "derived".into())])]),
        ),
    ]);
    let traces = BTreeMap::from([(
        "derived".into(),
        Data::List(vec![Data::List(vec!["z".repeat(4000).into()])]),
    )]);
    let pending = rows(&Data::List(vec![Data::List(vec![
        "selector".into(),
        "derived".into(),
        "digest".into(),
    ])]))
    .unwrap();
    let acknowledged =
        present_relations(BTreeMap::new(), &traces, &pending, &mut brief, 8192).unwrap();
    assert_eq!(acknowledged, pending);
    assert_eq!(
        brief["association"].field("derived").unwrap(),
        &traces["derived"]
    );
    assert!(super::super::clue_sexpr(&Data::Map(brief)).len() <= 8192);
}
