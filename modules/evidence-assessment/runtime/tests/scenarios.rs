//! Consumer policies exercise the published rule Library.
use gerbil_ascent::{Cancellation, Engine, Limits, Row, RuleProgram, Value};

#[test]
fn actual_investigation_links_rules_operator_sources_and_explanation() {
    let sources = [
        include_str!("fixtures/evidence/dependency.ss"),
        include_str!("fixtures/evidence/investigation.ss"),
    ];
    let program = RuleProgram::read_sources(&sources, Some("make-investigation")).unwrap();
    assert!(program.sources.contains("contracts"));
    assert!(!program.sources.contains("contract_dependencies"));
    let engine = Engine::new(1).unwrap();
    let mut session = engine
        .open_declaration_sources(
            &sources,
            Some("make-investigation"),
            gerbil_ascent::FactLimits::default(),
        )
        .unwrap();
    let row =
        |values: &[&str]| Row::from(values.iter().map(|s| Value::from(*s)).collect::<Vec<_>>());
    session
        .replace(
            std::collections::BTreeMap::from([(
                "contracts".into(),
                vec![row(&["a", "b", "one"]), row(&["b", "c", "two"])],
            )]),
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    let run = session
        .run(None, &Limits::default(), &Cancellation::default())
        .unwrap();
    assert_eq!(
        run.relations["ancestry"],
        vec![row(&["a", "b"]), row(&["a", "c"]), row(&["b", "c"])]
    );
    assert!(
        session
            .explanation_metadata(run.result_handle, "ancestry")
            .is_ok()
    );
    session
        .replace(
            std::collections::BTreeMap::from([("contracts".into(), vec![row(&["a", "b", "one"])])]),
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    let run = session
        .run(None, &Limits::default(), &Cancellation::default())
        .unwrap();
    assert_eq!(run.relations["ancestry"], vec![row(&["a", "b"])]);
    session.close();
    engine.shutdown();
}

#[test]
fn production_catalog_review_history_compile_in_rust() {
    let files = |names: &[&str]| {
        names
            .iter()
            .map(|name| {
                std::fs::read_to_string(
                    std::path::Path::new(env!("CARGO_MANIFEST_DIR"))
                        .join("tests/fixtures/evidence")
                        .join(name),
                )
                .unwrap()
            })
            .collect::<Vec<_>>()
    };
    for (names, constructor) in [
        (
            vec![
                "catalog.ss",
                "catalog/reports.ss",
                "catalog/observations.ss",
                "catalog/protocols.ss",
            ],
            "make-catalog",
        ),
        (vec!["review.ss", "review/receipts.ss"], "make-review"),
        (vec!["history.ss"], "make-history"),
    ] {
        let sources = files(&names);
        let entry = RuleProgram::read_sources(
            &sources.iter().map(String::as_str).collect::<Vec<_>>(),
            Some(constructor),
        )
        .unwrap();
        assert_ne!(entry.sources, std::collections::BTreeSet::<String>::new());
        assert_ne!(entry.outputs, Vec::<String>::new());
        let engine = Engine::new(1).unwrap();
        let mut session = engine.open(entry.program).unwrap();
        session
            .run(&Limits::default(), &Cancellation::default())
            .unwrap();
        session.close();
        engine.shutdown();
    }
}

#[test]
fn production_review_requires_matching_identity_and_withdraws_support() {
    let source = include_str!("fixtures/evidence/review.ss");
    let receipts = include_str!("fixtures/evidence/review/receipts.ss");
    let entry = RuleProgram::read_sources(&[source, receipts], None).unwrap();
    let engine = Engine::new(2).unwrap();
    let mut session = engine.open(entry.program).unwrap();
    let row = |names: &[&str]| {
        Row::from(
            names
                .iter()
                .map(|n| Value::Symbol((*n).into()))
                .collect::<Vec<_>>(),
        )
    };
    session
        .replace("Candidate", vec![row(&["candidate", "gc", "new-sha"])])
        .unwrap();
    session
        .replace("Requires", vec![row(&["candidate", "gc-correct"])])
        .unwrap();
    let denied = session
        .run(&Limits::default(), &Cancellation::default())
        .unwrap();
    assert_eq!(
        denied.relations["Decision"],
        vec![row(&["candidate", "DENY"])]
    );
    session
        .replace("Passed", vec![row(&["receipt", "gc-correct"])])
        .unwrap();
    session
        .replace("ReceiptInput", vec![row(&["receipt", "source", "new-sha"])])
        .unwrap();
    session
        .replace("CurrentInput", vec![row(&["source", "new-sha"])])
        .unwrap();
    let reviewed = session
        .run(&Limits::default(), &Cancellation::default())
        .unwrap();
    assert_eq!(
        reviewed.relations["Decision"],
        vec![row(&["candidate", "REVIEW_REQUIRED"])]
    );
    session
        .replace("CurrentInput", vec![row(&["source", "different-sha"])])
        .unwrap();
    let withdrawn = session
        .run(&Limits::default(), &Cancellation::default())
        .unwrap();
    assert_eq!(
        withdrawn.relations["Reusable"],
        Vec::<gerbil_ascent::Row>::new()
    );
    assert_eq!(
        withdrawn.relations["Decision"],
        denied.relations["Decision"]
    );
    session.close();
    engine.shutdown();
}

#[test]
fn declarative_projection_roundtrips_the_complete_review_rules() {
    let sources = [
        include_str!("fixtures/evidence/review.ss"),
        include_str!("fixtures/evidence/review/receipts.ss"),
    ];
    let entry = RuleProgram::read_sources(&sources, None).unwrap();
    let packet = gerbil_ascent::Catalog::encode(&entry.program, &entry.outputs).unwrap();
    let decoded = gerbil_ascent::Catalog::read(&packet).unwrap();
    assert_eq!(decoded.program.relations, entry.program.relations);
    assert_eq!(decoded.queries, entry.outputs);
    assert_eq!(decoded.program.rules.len(), entry.program.rules.len());
}

#[test]
fn actual_actions_and_lifecycle_dsl_execute_without_vm() {
    for (source, constructor) in [
        (
            include_str!("fixtures/evidence/actions.ss"),
            "make-actions",
        ),
        (
            include_str!("fixtures/evidence/lifecycle.ss"),
            "make-lifecycle-review",
        ),
    ] {
        let program = RuleProgram::read_sources(&[source], Some(constructor)).unwrap();
        let engine = Engine::new(1).unwrap();
        let mut session = engine
            .open_rule_program(program, gerbil_ascent::FactLimits::default())
            .unwrap();
        session
            .run(None, &Limits::default(), &Cancellation::default())
            .unwrap();
        session.close();
        engine.shutdown();
    }
}
