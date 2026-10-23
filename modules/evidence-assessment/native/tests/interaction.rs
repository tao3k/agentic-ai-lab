use agentic_ai_lab_reasoning::{
    Data, DatalogRequest, EvidenceInteraction, EvidenceOperation, Runtime, evaluate_datalog,
    read_datalog,
};
use std::collections::BTreeMap;
fn list(values: impl IntoIterator<Item = Data>) -> Data {
    Data::List(values.into_iter().collect())
}
fn graph() -> (Data, Data) {
    let facts = Data::object([("input", list([list(["a".into()]), list(["b".into()])]))]);
    let queries = Data::object([("answer", "out(X)".into())]);
    let graph = read_datalog(&DatalogRequest {
        facts: &facts,
        source: "out(X) <= input(X)",
        queries: &queries,
        schema: None,
    })
    .unwrap()
    .program;
    let sources = list(
        graph
            .field("relations")
            .unwrap()
            .list()
            .unwrap()
            .iter()
            .filter(|r| r.field("source").unwrap().boolean().unwrap())
            .cloned(),
    );
    (sources, graph)
}
fn tools(engine: &Runtime) -> EvidenceInteraction {
    let (sources, graph) = graph();
    let operations = BTreeMap::from([
        (
            "closed".into(),
            EvidenceOperation::new(&graph, "out", "complete finite predicate", true).unwrap(),
        ),
        (
            "open".into(),
            EvidenceOperation::new(&graph, "out", "positive support only", false).unwrap(),
        ),
    ]);
    EvidenceInteraction::new(engine, sources, operations, true).unwrap()
}
fn condition(operation: &str, value: &str) -> Data {
    Data::object([
        ("operation", operation.into()),
        ("arguments", list([value.into()])),
    ])
}
fn branch(id: &str, conditions: Vec<Data>) -> Data {
    Data::object([("id", id.into()), ("conditions", list(conditions))])
}
fn first(packet: &Data) -> &Data {
    &packet.field("branches").unwrap().list().unwrap()[0]
}
#[test]
fn complete_false_conjunct_refutes_even_when_another_domain_is_open() {
    let engine = Runtime::new(1).unwrap();
    let mut tools = tools(&engine);
    let result = tools
        .check(&list([branch(
            "candidate",
            vec![condition("closed", "missing"), condition("open", "unknown")],
        )]))
        .unwrap();
    let entry = first(&result.feedback);
    assert_eq!(entry.field("status").unwrap(), &Data::from("contradicted"));
    assert_eq!(entry.field("complete").unwrap(), &Data::Bool(true));
    assert_eq!(entry.field("domainComplete").unwrap(), &Data::Bool(false));
    assert_eq!(result.receipts.len(), 1);
    assert_eq!(
        result.feedback.field("taskCorrectnessCertified").unwrap(),
        &Data::Bool(false)
    );
}
#[test]
fn conjunction_order_is_irrelevant_but_owner_and_generation_are_required() {
    let engine = Runtime::new(1).unwrap();
    let mut left = tools(&engine);
    let mut right = tools(&engine);
    let one = left
        .check(&list([branch(
            "one",
            vec![condition("closed", "a"), condition("closed", "b")],
        )]))
        .unwrap();
    let reference = first(&one.feedback).field("reference").unwrap().clone();
    let mut reordered = branch(
        "two",
        vec![condition("closed", "b"), condition("closed", "a")],
    )
    .map()
    .unwrap()
    .clone();
    reordered.insert("reference".into(), reference.clone());
    assert_eq!(
        first(
            &left
                .check(&list([Data::Map(reordered.clone())]))
                .unwrap()
                .feedback
        )
        .field("status")
        .unwrap(),
        &Data::from("supported")
    );
    assert_eq!(
        first(&right.check(&list([Data::Map(reordered)])).unwrap().feedback)
            .field("status")
            .unwrap(),
        &Data::from("unknown")
    );
    let (sources, _) = graph();
    left.replace(sources).unwrap();
    assert_eq!(
        first(&left.reuse(&list([reference])).unwrap().feedback)
            .field("status")
            .unwrap(),
        &Data::from("unknown")
    );
}
#[test]
fn candidate_batch_shares_one_complete_relation_evaluation() {
    let engine = Runtime::new(2).unwrap();
    let mut tools = tools(&engine);
    let branches = list((0..128).map(|i| {
        branch(
            &i.to_string(),
            vec![condition(
                "closed",
                if i % 2 == 0 { "a" } else { "missing" },
            )],
        )
    }));
    for expected in [true, false] {
        let result = tools.check(&branches).unwrap();
        assert_eq!(result.receipts.len(), 1);
        assert_eq!(
            result.receipts[0].field("evaluated").unwrap(),
            &Data::Bool(expected)
        );
        let rows = result.feedback.field("branches").unwrap().list().unwrap();
        assert_eq!(
            rows.iter()
                .filter(|r| r.get("status") == Some(&Data::from("supported")))
                .count(),
            64
        );
    }
}
#[test]
fn native_datalog_types_preserve_boolean_integer_and_text_distinctions() {
    let engine = Runtime::new(1).unwrap();
    let facts = Data::object([(
        "input",
        list([
            list([true.into()]),
            list([Data::Integer(1.into())]),
            list(["1".into()]),
        ]),
    )]);
    let queries = Data::object([("answer", "out(X)".into())]);
    let request = DatalogRequest {
        facts: &facts,
        source: "out(X) <= input(X)",
        queries: &queries,
        schema: None,
    };
    let (answer, _) = evaluate_datalog(&engine, &request).unwrap();
    assert_eq!(answer.field("answer").unwrap().list().unwrap().len(), 3);
    assert!(
        read_datalog(&DatalogRequest {
            schema: Some(&Data::from("infer")),
            ..request
        })
        .is_err()
    );
}

#[test]
fn journal_batch_rolls_back_receipts_when_checkpoint_is_invalid() {
    let engine = Runtime::new(1).unwrap();
    let mut ledger = agentic_ai_lab_reasoning::Trajectory::new(&engine, "task", "source").unwrap();
    let before = ledger.snapshot().unwrap();
    let receipt = Data::object([
        ("id", "evidence".into()),
        ("kind", "evidence".into()),
        ("sourceIdentity", "source".into()),
        ("resultReference", "result".into()),
        ("pathIdentity", "path".into()),
    ]);
    let checkpoint = Data::object([
        ("id", "checkpoint".into()),
        ("kind", "checkpoint".into()),
        ("sourceIdentity", "source".into()),
        ("modelCall", "call:missing".into()),
        ("branches", list([])),
    ]);
    assert!(ledger.append_batch(&[receipt.clone(), checkpoint]).is_err());
    assert_eq!(ledger.snapshot().unwrap(), before);
    ledger.append(receipt).unwrap();
    assert_eq!(
        ledger.snapshot().unwrap().field("eventCount").unwrap(),
        &Data::from(1usize)
    );
}

#[test]
fn trajectory_exploration_is_read_only_and_open_world() {
    let engine = Runtime::new(1).unwrap();
    let mut ledger = agentic_ai_lab_reasoning::Trajectory::new(&engine, "task", "source-a").unwrap();
    let attempt = Data::object([
        ("id", "attempt-1".into()),
        ("kind", "attempt".into()),
        ("sourceIdentity", "source-a".into()),
        ("questionIdentity", "question".into()),
        ("operationIdentity", "test".into()),
        ("inputIdentity", "input-a".into()),
        ("scopeIdentity", "scope".into()),
        ("toolIdentity", "tool".into()),
        ("modelIdentity", "model".into()),
    ]);
    ledger.append(attempt).unwrap();
    let context = ledger.context().unwrap();
    assert!(ledger.exploration_current(&context).unwrap());
    let mut other = agentic_ai_lab_reasoning::Trajectory::new(&engine, "task", "source-a").unwrap();
    other
        .append(Data::object([
            ("id", "attempt-1".into()),
            ("kind", "attempt".into()),
            ("sourceIdentity", "source-a".into()),
            ("questionIdentity", "question".into()),
            ("operationIdentity", "test".into()),
            ("inputIdentity", "input-b".into()),
        ]))
        .unwrap();
    assert_eq!(
        other.context().unwrap().field("eventCount").unwrap(),
        context.field("eventCount").unwrap()
    );
    assert_ne!(
        other.context().unwrap().field("prefixIdentity").unwrap(),
        context.field("prefixIdentity").unwrap()
    );
    let prefix = context.field("prefixIdentity").unwrap().text().unwrap();
    assert_eq!(prefix.len(), 64);
    assert_eq!(
        ledger
            .explore(&Data::object([
                ("questionIdentity", "question".into()),
                ("operationIdentity", "test".into()),
                ("inputIdentity", "input-a".into()),
            ]))
            .unwrap()
            .field("prefixIdentity")
            .unwrap(),
        &Data::from(prefix)
    );
    let mut forged = context.clone();
    if let Data::Map(fields) = &mut forged {
        fields.insert("prefixIdentity".into(), "different-content".into());
    }
    assert!(!ledger.exploration_current(&forged).unwrap());
    assert_eq!(context.field("actionSelected").unwrap(), &Data::Bool(false));
    let observed = &context.field("attempts").unwrap().list().unwrap()[0];
    assert_eq!(
        observed.field("earlierEvent").unwrap(),
        &Data::from("attempt-1")
    );
    assert!(observed.get("resultReference").is_none());
    let candidate = Data::object([
        ("questionIdentity", "question".into()),
        ("operationIdentity", "test".into()),
        ("inputIdentity", "input-a".into()),
        ("scopeIdentity", "scope".into()),
        ("toolIdentity", "tool".into()),
        ("modelIdentity", "model".into()),
    ]);
    let before = ledger.snapshot().unwrap();
    let packet = ledger.explore(&candidate).unwrap();
    assert_eq!(ledger.snapshot().unwrap(), before);
    assert_eq!(
        packet.field("executionAuthorized").unwrap(),
        &Data::Bool(false)
    );
    assert_eq!(packet.field("actionSelected").unwrap(), &Data::Bool(false));
    let comparisons = packet.field("comparisons").unwrap().list().unwrap();
    assert_eq!(
        comparisons[0].field("relation").unwrap(),
        &Data::from("exact-current")
    );
    assert_eq!(
        comparisons[0].field("currentEvidenceReference").unwrap(),
        &Data::Bool(false)
    );

    let unknown = Data::object([
        ("questionIdentity", "question".into()),
        ("operationIdentity", "test".into()),
        ("inputIdentity", "input-a".into()),
    ]);
    assert_eq!(
        ledger
            .explore(&unknown)
            .unwrap()
            .field("comparisons")
            .unwrap()
            .list()
            .unwrap()[0]
            .field("relation")
            .unwrap(),
        &Data::from("comparison-unknown")
    );
    let mut changed = candidate.clone();
    if let Data::Map(fields) = &mut changed {
        fields.insert("inputIdentity".into(), "input-b".into());
    }
    assert_eq!(
        ledger
            .explore(&changed)
            .unwrap()
            .field("comparisons")
            .unwrap()
            .list()
            .unwrap()[0]
            .field("relation")
            .unwrap(),
        &Data::from("changed-premise")
    );
    ledger
        .append(Data::object([
            ("id", "source-change".into()),
            ("kind", "invalidate".into()),
            ("sourceIdentity", "source-a".into()),
            ("nextSourceIdentity", "source-b".into()),
        ]))
        .unwrap();
    assert_eq!(
        ledger
            .explore(&candidate)
            .unwrap()
            .field("comparisons")
            .unwrap()
            .list()
            .unwrap()[0]
            .field("relation")
            .unwrap(),
        &Data::from("historical")
    );
}

#[test]
fn trajectory_brief_reports_bound_changes_without_attempt_payloads() {
    let engine = Runtime::new(1).unwrap();
    let mut ledger = agentic_ai_lab_reasoning::Trajectory::new(&engine, "task", "source-a").unwrap();
    let first = ledger.brief(None).unwrap();
    assert_eq!(
        first.field("readSurfaces").unwrap(),
        &list([
            Data::from("context"),
            Data::from("explore"),
            Data::from("focus"),
            Data::from("exact-prefix"),
            Data::from("snapshot")
        ])
    );
    assert_eq!(first.field("status").unwrap(), &Data::from("unread"));
    assert!(first.get("attempts").is_none());
    assert!(first.get("comparisons").is_none());
    assert!(ledger.exploration_current(&first).unwrap());
    assert_eq!(
        ledger.brief(Some(&first)).unwrap().field("status").unwrap(),
        &Data::from("unchanged")
    );
    ledger
        .append(Data::object([
            ("id", "attempt-1".into()),
            ("kind", "attempt".into()),
            ("sourceIdentity", "source-a".into()),
            ("questionIdentity", "question".into()),
            ("operationIdentity", "test".into()),
            ("inputIdentity", "input".into()),
        ]))
        .unwrap();
    let changed = ledger.brief(Some(&first)).unwrap();
    assert_eq!(changed.field("status").unwrap(), &Data::from("changed"));
    assert_eq!(
        changed.field("changeKinds").unwrap(),
        &list([Data::from("attempt")])
    );
    assert!(changed.get("attempts").is_none());
    let mut forged = changed.clone();
    let Data::Map(fields) = &mut forged else {
        unreachable!()
    };
    fields.insert("prefixIdentity".into(), "wrong".into());
    assert!(ledger.brief(Some(&forged)).is_err());
    let foreign = agentic_ai_lab_reasoning::Trajectory::new(&engine, "other", "source-a").unwrap();
    assert!(foreign.brief(Some(&changed)).is_err());
    ledger
        .append(Data::object([
            ("id", "replace".into()),
            ("kind", "invalidate".into()),
            ("sourceIdentity", "source-a".into()),
            ("nextSourceIdentity", "source-b".into()),
        ]))
        .unwrap();
    let replaced = ledger.brief(Some(&changed)).unwrap();
    assert!(
        replaced
            .field("changeKinds")
            .unwrap()
            .list()
            .unwrap()
            .contains(&Data::from("source-replacement"))
    );
}

#[test]
fn trajectory_focus_and_exact_prefix_bind_caller_selected_reads() {
    let engine = Runtime::new(1).unwrap();
    let mut ledger = agentic_ai_lab_reasoning::Trajectory::new(&engine, "task", "source-a").unwrap();
    let candidate = Data::object([
        ("questionIdentity", "q".into()),
        ("operationIdentity", "probe".into()),
        ("inputIdentity", "input".into()),
    ]);
    let first = ledger.focus(&candidate, None).unwrap();
    for (id, question) in [("other", "other"), ("matching", "q")] {
        ledger
            .append(Data::object([
                ("id", id.into()),
                ("kind", "attempt".into()),
                ("sourceIdentity", "source-a".into()),
                ("questionIdentity", question.into()),
                ("operationIdentity", "probe".into()),
                ("inputIdentity", "input".into()),
            ]))
            .unwrap();
    }
    let changed = ledger.focus(&candidate, Some(&first)).unwrap();
    assert_eq!(changed.field("status").unwrap(), &Data::from("changed"));
    assert_eq!(
        changed.field("comparisons").unwrap().list().unwrap().len(),
        1
    );
    assert_eq!(changed.field("actionSelected").unwrap(), &Data::Bool(false));
    let prefix = changed.field("prefixIdentity").unwrap().text().unwrap();
    let exact = ledger.exact_prefix(2, prefix).unwrap();
    assert_eq!(exact.field("events").unwrap().list().unwrap().len(), 2);
    assert!(ledger.exploration_current(&exact).unwrap());
    assert!(ledger.exact_prefix(2, "wrong").is_err());
    let wrong = Data::object([
        ("questionIdentity", "other".into()),
        ("operationIdentity", "probe".into()),
        ("inputIdentity", "input".into()),
    ]);
    assert!(ledger.focus(&wrong, Some(&changed)).is_err());
    ledger
        .append(Data::object([
            ("id", "replace".into()),
            ("kind", "invalidate".into()),
            ("sourceIdentity", "source-a".into()),
            ("nextSourceIdentity", "source-b".into()),
        ]))
        .unwrap();
    let historical = ledger.exact_prefix(2, prefix).unwrap();
    assert_eq!(
        historical.field("sourceIdentity").unwrap(),
        &Data::from("source-a")
    );
    assert_eq!(historical.field("generation").unwrap(), &Data::from(0usize));
    assert!(!ledger.exploration_current(&historical).unwrap());
}

#[test]
fn trajectory_exploration_reference_requires_current_successful_review() {
    let engine = Runtime::new(1).unwrap();
    let mut ledger = agentic_ai_lab_reasoning::Trajectory::new(&engine, "task", "source").unwrap();
    let event = |id: &str, kind: &str, fields: Vec<(&str, Data)>| {
        let mut base = vec![
            ("id", id.into()),
            ("kind", kind.into()),
            ("sourceIdentity", "source".into()),
        ];
        base.extend(fields);
        Data::Map(
            base.into_iter()
                .map(|(key, value)| (key.into(), value))
                .collect(),
        )
    };
    ledger
        .append(event(
            "evidence",
            "evidence",
            vec![
                ("resultReference", "result".into()),
                ("pathIdentity", "path".into()),
            ],
        ))
        .unwrap();
    ledger
        .append(event(
            "attempt",
            "attempt",
            vec![
                ("questionIdentity", "question".into()),
                ("operationIdentity", "test".into()),
                ("inputIdentity", "input".into()),
                ("resultReference", "result".into()),
                ("contractIdentity", "contract".into()),
            ],
        ))
        .unwrap();
    let candidate = Data::object([
        ("questionIdentity", "question".into()),
        ("operationIdentity", "test".into()),
        ("inputIdentity", "input".into()),
        ("contractIdentity", "contract".into()),
    ]);
    let reference = |ledger: &agentic_ai_lab_reasoning::Trajectory| {
        ledger
            .explore(&candidate)
            .unwrap()
            .field("comparisons")
            .unwrap()
            .list()
            .unwrap()[0]
            .field("currentEvidenceReference")
            .unwrap()
            .clone()
    };
    assert_eq!(reference(&ledger), Data::Bool(false));
    ledger
        .append(event(
            "consumption",
            "consumption",
            vec![
                ("consumedReference", "result".into()),
                ("resultReference", "result".into()),
                ("intentIdentity", "intent".into()),
                ("contractIdentity", "contract".into()),
            ],
        ))
        .unwrap();
    assert_eq!(reference(&ledger), Data::Bool(false));
    ledger
        .append(event(
            "verified",
            "verification",
            vec![
                ("verifier", "independent-check".into()),
                ("correct", true.into()),
                ("consumptionReference", "result".into()),
            ],
        ))
        .unwrap();
    assert_eq!(reference(&ledger), Data::from("result"));
    let reviewed_packet = ledger.explore(&candidate).unwrap();
    assert!(ledger.exploration_current(&reviewed_packet).unwrap());
    let mut other = agentic_ai_lab_reasoning::Trajectory::new(&engine, "task", "source").unwrap();
    for recorded in ledger
        .snapshot()
        .unwrap()
        .field("events")
        .unwrap()
        .list()
        .unwrap()
    {
        other.append(recorded.clone()).unwrap();
    }
    assert_eq!(
        ledger.context().unwrap().field("prefixIdentity").unwrap(),
        other.context().unwrap().field("prefixIdentity").unwrap()
    );
    assert!(!other.exploration_current(&reviewed_packet).unwrap());
    let mismatched = Data::object([
        ("questionIdentity", "question".into()),
        ("operationIdentity", "test".into()),
        ("inputIdentity", "input".into()),
        ("contractIdentity", "other-contract".into()),
    ]);
    assert_eq!(
        ledger
            .explore(&mismatched)
            .unwrap()
            .field("comparisons")
            .unwrap()
            .list()
            .unwrap()[0]
            .field("currentEvidenceReference")
            .unwrap(),
        &Data::Bool(false)
    );
    ledger
        .append(event(
            "rejected",
            "verification",
            vec![
                ("verifier", "independent-check".into()),
                ("correct", false.into()),
                ("consumptionReference", "result".into()),
            ],
        ))
        .unwrap();
    assert_eq!(reference(&ledger), Data::Bool(false));
    assert!(!ledger.exploration_current(&reviewed_packet).unwrap());
}

#[test]
fn observed_set_equality_preserves_types_multiplicity_and_tuple_shape() {
    let one = list([list([Data::Integer(1.into())])]);
    assert!(
        agentic_ai_lab_reasoning::rows_equal(
            &one,
            &list([
                list([Data::Integer(1.into())]),
                list([Data::Integer(1.into())])
            ])
        )
        .unwrap()
    );
    assert!(!agentic_ai_lab_reasoning::rows_equal(&one, &list([list([true.into()])])).unwrap());
    assert!(!agentic_ai_lab_reasoning::rows_equal(&one, &list([list(["1".into()])])).unwrap());
    assert!(agentic_ai_lab_reasoning::rows_equal(&one, &list([list([]), list(["x".into()])])).is_err());
}

#[test]
fn restored_provider_history_keeps_opaque_items_and_rejects_duplicate_or_unpaired_tools() {
    use agentic_ai_lab_reasoning::{Data, ResponseHistory};
    let question = Data::object([
        ("role", Data::from("user")),
        ("content", Data::from("original")),
    ]);
    let call = Data::object([
        ("type", Data::from("function_call")),
        ("call_id", Data::from("one")),
        ("name", Data::from("check")),
        ("arguments", Data::from("{}")),
    ]);
    let result = Data::object([
        ("type", Data::from("function_call_output")),
        ("call_id", Data::from("one")),
        ("output", Data::from("finite facts")),
    ]);
    let reasoning = Data::object([
        ("type", Data::from("reasoning")),
        ("opaque", Data::from("unchanged")),
    ]);
    let input = Data::List(vec![
        question.clone(),
        reasoning,
        call.clone(),
        result.clone(),
    ]);
    let mut history = ResponseHistory::restore(&input).unwrap();
    assert_eq!(history.input().unwrap(), input);
    assert_eq!(history.reasoning_items(), 1);
    assert!(
        history
            .append_response(&Data::object([("output", Data::List(vec![call.clone()]))]))
            .is_err()
    );
    assert_eq!(history.input().unwrap(), input);
    assert!(ResponseHistory::restore(&Data::List(vec![question.clone(), call.clone()])).is_err());
    assert!(ResponseHistory::restore(&Data::List(vec![question.clone(), result.clone()])).is_err());
    assert!(
        ResponseHistory::restore(&Data::List(vec![question, call, result.clone(), result]))
            .is_err()
    );
}
