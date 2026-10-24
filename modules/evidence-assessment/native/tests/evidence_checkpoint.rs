//! Shared Scheme semantics through the existing native Session, not a second scheduler.
use agentic_ai_lab_reasoning::{Cancellation, FactLimits, Limits, Row, Runtime, SourceSession};
use std::collections::BTreeMap;

const RULES: &str = include_str!(
    "../../../../packages/python-runtime/src/agentic_ai_lab_runtime/reasoning_rules/checkpoint_rules.ss"
);

fn row(values: &[&str]) -> Row {
    Row::from(values.iter().map(|v| (*v).into()).collect::<Vec<_>>())
}

fn declaration(
    requirement: &str,
    contract: &str,
    bindings: i64,
    commands: i64,
    dependencies: i64,
) -> Row {
    Row::from(vec![
        requirement.into(),
        contract.into(),
        "scope".into(),
        "manifest-sha".into(),
        "enumerator-sha".into(),
        bindings.into(),
        commands.into(),
        dependencies.into(),
    ])
}

fn witness(receipt: &str) -> Row {
    row(&[receipt, "scope", "manifest-sha", "enumerator-sha"])
}

fn facts() -> BTreeMap<String, Vec<Row>> {
    BTreeMap::from([
        (
            "requirement".into(),
            vec![row(&["build"]), row(&["test"]), row(&["independent"])],
        ),
        ("dependency".into(), vec![row(&["test", "build"])]),
        (
            "contract".into(),
            vec![
                row(&["build", "c"]),
                row(&["test", "c"]),
                row(&["independent", "c"]),
            ],
        ),
        (
            "receipt".into(),
            vec![
                row(&["b", "build", "c", "PASS"]),
                row(&["t", "test", "c", "PASS"]),
                row(&["i", "independent", "c", "PASS"]),
            ],
        ),
        ("completed_outcome".into(), vec![row(&["PASS"])]),
        (
            "required_binding".into(),
            vec![
                row(&["build", "c", "runtime"]),
                row(&["test", "c", "suite"]),
                row(&["independent", "c", "model"]),
            ],
        ),
        ("command".into(), vec![]),
        ("command_observation".into(), vec![]),
        (
            "verified".into(),
            vec![row(&["b"]), row(&["t"]), row(&["i"])],
        ),
        (
            "support_witness".into(),
            vec![witness("b"), witness("t"), witness("i")],
        ),
        (
            "support_declaration".into(),
            vec![
                declaration("build", "c", 1, 0, 0),
                declaration("test", "c", 1, 0, 1),
                declaration("independent", "c", 1, 0, 0),
            ],
        ),
        ("required_command".into(), vec![]),
        (
            "binding".into(),
            vec![
                row(&["b", "runtime", "old"]),
                row(&["t", "suite", "stable"]),
                row(&["i", "model", "stable"]),
            ],
        ),
        (
            "current_binding".into(),
            vec![
                row(&["runtime", "old"]),
                row(&["suite", "stable"]),
                row(&["model", "stable"]),
            ],
        ),
        ("prerequisite".into(), vec![row(&["t", "build", "b"])]),
        (
            "quiescent".into(),
            vec![row(&["b"]), row(&["t"]), row(&["i"])],
        ),
        ("material".into(), vec![row(&["b", "binary"])]),
        ("available".into(), vec![row(&["b", "binary"])]),
        ("withdrawn".into(), vec![]),
    ])
}

fn session() -> SourceSession {
    let workers = std::thread::available_parallelism().unwrap().get();
    Runtime::new(workers)
        .unwrap()
        .open_declaration_sources(
            &[RULES],
            Some("make-evidence-checkpoint"),
            FactLimits::default(),
        )
        .unwrap()
}

fn evaluate(
    session: &mut SourceSession,
    inputs: BTreeMap<String, Vec<Row>>,
) -> BTreeMap<String, Vec<Row>> {
    let limits = Limits::default();
    let cancel = Cancellation::default();
    session.replace(inputs, &limits, &cancel).unwrap();
    let result = session.run(None, &limits, &cancel).unwrap();
    assert!(result.complete);
    session.result(result.result_handle).unwrap().close();
    result.relations
}

#[test]
fn evidence_checkpoint_source_replacement_preserves_history_and_independent_support() {
    let mut owner = session();
    let mut inputs = facts();
    let before = evaluate(&mut owner, inputs.clone());
    assert_eq!(before["applicable"].len(), 3);
    assert_eq!(before["reusable"].len(), 3);
    inputs.get_mut("current_binding").unwrap()[0] = row(&["runtime", "new"]);
    let changed = evaluate(&mut owner, inputs.clone());
    assert_eq!(
        changed["historical_complete"],
        before["historical_complete"]
    );
    assert_eq!(changed["applicable"], vec![row(&["independent", "i"])]);
    assert_eq!(changed["unclosed"], vec![row(&["build"]), row(&["test"])]);
    assert!(changed["invalidated_by"].contains(&row(&["t", "b", "binding"])));
    inputs.get_mut("current_binding").unwrap()[0] = row(&["runtime", "old"]);
    assert_eq!(
        evaluate(&mut owner, inputs)["applicable"],
        before["applicable"]
    );
}

#[test]
fn evidence_checkpoint_missing_bindings_are_not_absence_of_invalidations() {
    let mut inputs = facts();
    inputs.get_mut("binding").unwrap().remove(0);
    let result = evaluate(&mut session(), inputs);
    assert_eq!(result["historical_complete"].len(), 3);
    assert_eq!(result["applicable"], vec![row(&["independent", "i"])]);
    assert!(result["invalidated_by"].contains(&row(&["t", "b", "missing-binding"])));
}

#[test]
fn evidence_checkpoint_omitted_declarations_do_not_become_empty_success() {
    let mut inputs = facts();
    inputs.insert("required_binding".into(), vec![]);
    inputs.insert("binding".into(), vec![]);
    inputs.insert("current_binding".into(), vec![]);
    let result = evaluate(&mut session(), inputs);
    assert_eq!(result["reusable"], []);
    assert_eq!(result["enumeration_gap"].len(), 3);

    let mut inputs = facts();
    inputs.get_mut("support_witness").unwrap()[0] =
        row(&["b", "other-scope", "manifest-sha", "enumerator-sha"]);
    let result = evaluate(&mut session(), inputs);
    assert_eq!(result["reusable"], vec![row(&["independent", "i"])]);
}

#[test]
fn evidence_checkpoint_declared_command_survives_erased_receipt_commands() {
    let mut inputs = facts();
    inputs.get_mut("support_declaration").unwrap()[0] = declaration("build", "c", 1, 1, 0);
    inputs.insert(
        "required_command".into(),
        vec![Row::from(vec![
            "build".into(),
            "c".into(),
            "0".into(),
            0_i64.into(),
        ])],
    );
    let result = evaluate(&mut session(), inputs);
    assert_eq!(result["reusable"], vec![row(&["independent", "i"])]);
}

#[test]
fn evidence_checkpoint_accepted_contracts_keep_separate_input_obligations() {
    let mut inputs = facts();
    inputs
        .get_mut("contract")
        .unwrap()
        .push(row(&["build", "other-checker"]));
    inputs
        .get_mut("receipt")
        .unwrap()
        .push(row(&["other", "build", "other-checker", "PASS"]));
    inputs.get_mut("required_binding").unwrap().push(row(&[
        "build",
        "other-checker",
        "alternative-runtime",
    ]));
    inputs
        .get_mut("binding")
        .unwrap()
        .push(row(&["other", "alternative-runtime", "sha"]));
    inputs
        .get_mut("current_binding")
        .unwrap()
        .push(row(&["alternative-runtime", "sha"]));
    inputs
        .get_mut("support_declaration")
        .unwrap()
        .push(declaration("build", "other-checker", 1, 0, 0));
    inputs
        .get_mut("support_witness")
        .unwrap()
        .push(witness("other"));
    for name in ["verified", "quiescent"] {
        inputs.get_mut(name).unwrap().push(row(&["other"]));
    }
    let result = evaluate(&mut session(), inputs);
    assert!(result["applicable"].contains(&row(&["build", "b"])));
    assert!(result["applicable"].contains(&row(&["build", "other"])));
    assert_eq!(result["binding_gap"], []);
}

#[test]
fn evidence_checkpoint_raw_command_observations_are_checked_by_scheme() {
    for (exit, timeout, reaped, quiet, accepted) in [
        (0, false, true, true, true),
        (1, false, true, true, false),
        (0, true, true, true, false),
        (0, false, false, true, false),
        (0, false, true, false, false),
    ] {
        let mut inputs = facts();
        inputs.insert(
            "command".into(),
            vec![Row::from(vec!["b".into(), "child".into(), 0.into()])],
        );
        inputs.insert(
            "command_observation".into(),
            vec![Row::from(vec![
                "b".into(),
                "child".into(),
                exit.into(),
                timeout.into(),
                reaped.into(),
                quiet.into(),
            ])],
        );
        let result = evaluate(&mut session(), inputs.clone());
        assert_eq!(
            result["applicable"].contains(&row(&["build", "b"])),
            accepted
        );
        assert!(result["applicable"].contains(&row(&["independent", "i"])));
        inputs.insert("command_observation".into(), vec![]);
        assert!(
            !evaluate(&mut session(), inputs)["historical_complete"]
                .contains(&row(&["build", "b"]))
        );
    }
}

#[test]
fn evidence_checkpoint_cleanup_and_unknown_exit_are_not_lost_progress() {
    let mut inputs = facts();
    inputs.insert("available".into(), vec![]);
    inputs.insert("quiescent".into(), vec![]);
    let result = evaluate(&mut session(), inputs);
    assert_eq!(result["historical_complete"].len(), 3);
    assert_eq!(result["applicable"].len(), 3);
    assert_eq!(result["reusable"], []);
    assert_eq!(result["material_gap"], vec![row(&["build", "b", "binary"])]);
    assert_eq!(result["completion_gap"].len(), 3);
    assert_eq!(result["unclosed"], []);
}

#[test]
fn evidence_checkpoint_incomplete_manifests_failures_and_withdrawal_do_not_promote_support() {
    for field in [
        "verified",
        "support_witness",
        "support_declaration",
        "prerequisite",
    ] {
        let mut inputs = facts();
        inputs.insert(field.into(), vec![]);
        let result = evaluate(&mut session(), inputs);
        assert!(!result["applicable"].contains(&row(&["test", "t"])));
    }
    let mut inputs = facts();
    inputs.get_mut("receipt").unwrap()[0] = row(&["b", "build", "c", "TIMEOUT"]);
    let result = evaluate(&mut session(), inputs);
    assert_eq!(result["applicable"], vec![row(&["independent", "i"])]);
    let mut inputs = facts();
    inputs.insert("withdrawn".into(), vec![row(&["b", "superseded-support"])]);
    let result = evaluate(&mut session(), inputs);
    assert_eq!(result["historical_complete"].len(), 3);
    assert_eq!(result["applicable"], vec![row(&["independent", "i"])]);
}

#[test]
fn evidence_checkpoint_cycles_and_ambiguous_current_bindings_are_not_reusable() {
    let mut inputs = facts();
    inputs
        .get_mut("dependency")
        .unwrap()
        .push(row(&["build", "test"]));
    inputs
        .get_mut("prerequisite")
        .unwrap()
        .push(row(&["b", "test", "t"]));
    let result = evaluate(&mut session(), inputs);
    assert_eq!(
        result["historical_complete"],
        vec![row(&["independent", "i"])]
    );
    let mut inputs = facts();
    inputs
        .get_mut("current_binding")
        .unwrap()
        .push(row(&["runtime", "other"]));
    let result = evaluate(&mut session(), inputs);
    assert_eq!(result["applicable"], vec![row(&["independent", "i"])]);
}

#[test]
fn evidence_checkpoint_new_failure_does_not_erase_an_applicable_pass() {
    let mut inputs = facts();
    inputs
        .get_mut("receipt")
        .unwrap()
        .push(row(&["failed-test", "test", "c", "TIMEOUT"]));
    inputs
        .get_mut("verified")
        .unwrap()
        .push(row(&["failed-test"]));
    inputs
        .get_mut("support_witness")
        .unwrap()
        .push(witness("failed-test"));
    let result = evaluate(&mut session(), inputs);
    assert_eq!(result["applicable"].len(), 3);
    assert_eq!(result["unclosed"], []);
    assert!(!result.contains_key("next"));
    assert!(!result.contains_key("execution_authorized"));
}

#[test]
fn evidence_checkpoint_matches_independent_closure_for_every_three_node_dag() {
    let mut owner = session();
    let names = ["build", "test", "independent"];
    let receipts = ["b", "t", "i"];
    let possible = [(1, 0), (2, 0), (2, 1)];
    for mask in 0..8 {
        for changed in 0..3 {
            let mut inputs = facts();
            let edges: Vec<_> = possible
                .iter()
                .enumerate()
                .filter(|(bit, _)| mask & (1 << bit) != 0)
                .map(|(_, edge)| *edge)
                .collect();
            inputs.insert(
                "dependency".into(),
                edges
                    .iter()
                    .map(|&(c, p)| row(&[names[c], names[p]]))
                    .collect(),
            );
            inputs.insert(
                "support_declaration".into(),
                (0..3)
                    .map(|i| {
                        declaration(
                            names[i],
                            "c",
                            1,
                            0,
                            i64::try_from(edges.iter().filter(|(c, _)| *c == i).count())
                                .expect("three-node degree fits i64"),
                        )
                    })
                    .collect(),
            );
            inputs.insert(
                "prerequisite".into(),
                edges
                    .iter()
                    .map(|&(c, p)| row(&[receipts[c], names[p], receipts[p]]))
                    .collect(),
            );
            inputs.insert(
                "binding".into(),
                (0..3)
                    .map(|i| row(&[receipts[i], names[i], "old"]))
                    .collect(),
            );
            inputs.insert(
                "required_binding".into(),
                (0..3).map(|i| row(&[names[i], "c", names[i]])).collect(),
            );
            inputs.insert(
                "current_binding".into(),
                (0..3)
                    .map(|i| row(&[names[i], if i == changed { "new" } else { "old" }]))
                    .collect(),
            );
            let mut affected = std::collections::BTreeSet::from([changed]);
            loop {
                let before = affected.len();
                for &(child, parent) in &edges {
                    if affected.contains(&parent) {
                        affected.insert(child);
                    }
                }
                if before == affected.len() {
                    break;
                }
            }
            let mut expected: Vec<_> = (0..3)
                .filter(|i| !affected.contains(i))
                .map(|i| row(&[names[i], receipts[i]]))
                .collect();
            expected.sort();
            let result = evaluate(&mut owner, inputs);
            assert_eq!(
                result["applicable"], expected,
                "graph={mask}, changed={changed}"
            );
            assert_eq!(result["historical_complete"].len(), 3);
        }
    }
}

#[test]
fn evidence_checkpoint_domain_names_outcomes_and_projection_remain_caller_owned() {
    let mut inputs = BTreeMap::from([
        (
            "requirement".into(),
            vec![row(&["new-open-research-obligation"])],
        ),
        (
            "contract".into(),
            vec![row(&["new-open-research-obligation", "decoded-control"])],
        ),
        (
            "receipt".into(),
            vec![row(&[
                "witness",
                "new-open-research-obligation",
                "decoded-control",
                "COUNTEREXAMPLE",
            ])],
        ),
        ("completed_outcome".into(), vec![row(&["COUNTEREXAMPLE"])]),
        ("verified".into(), vec![row(&["witness"])]),
        ("support_witness".into(), vec![witness("witness")]),
        (
            "support_declaration".into(),
            vec![declaration(
                "new-open-research-obligation",
                "decoded-control",
                0,
                0,
                0,
            )],
        ),
        ("quiescent".into(), vec![row(&["witness"])]),
    ]);
    let mut owner = session();
    assert_eq!(
        evaluate(&mut owner, inputs.clone())["reusable"],
        vec![row(&["new-open-research-obligation", "witness"])]
    );
    inputs.insert("completed_outcome".into(), vec![]);
    assert_eq!(evaluate(&mut owner, inputs)["applicable"], []);

    // Caller extension uses ordinary Scheme relations, not a new callback API.
    let extension = "(define-program (custom-checkpoint)
        (sources requirement) (outputs open_research reusable)
        (include evidence-checkpoint-fragment)
        (relation open_research (requirement))
        ((open_research R) <-- (requirement R)))";
    let engine = Runtime::new(std::thread::available_parallelism().unwrap().get()).unwrap();
    let mut owner = engine
        .open_declaration_sources(
            &[RULES, extension],
            Some("custom-checkpoint"),
            FactLimits::default(),
        )
        .unwrap();
    let result = evaluate(
        &mut owner,
        BTreeMap::from([("requirement".into(), vec![row(&["arbitrary-hypothesis"])])]),
    );
    assert_eq!(
        result["open_research"],
        vec![row(&["arbitrary-hypothesis"])]
    );
    assert_eq!(result["reusable"], []);
}
