use agentic_ai_lab_reasoning::{
    Cancellation, ComputationalEvidence, Data, EvidenceChain, FactLimits, Reachability, Runtime,
    Value, evidence_graph,
};
use std::collections::BTreeSet;
fn list(values: impl IntoIterator<Item = Data>) -> Data {
    Data::List(values.into_iter().collect())
}
fn relation(name: &str, source: bool, rows: Vec<Vec<&str>>) -> Data {
    Data::object([
        ("name", name.into()),
        ("source", source.into()),
        ("columns", list([Data::object([("kind", "symbol".into())])])),
        (
            "rows",
            list(
                rows.into_iter()
                    .map(|r| list(r.into_iter().map(Data::from))),
            ),
        ),
    ])
}
fn atom(name: &str, var: &str) -> Data {
    Data::object([
        ("relation", name.into()),
        ("terms", list([Data::object([("var", var.into())])])),
    ])
}
fn rule(head: &str, body: &str) -> Data {
    Data::object([
        ("head", list([atom(head, "x")])),
        ("body", list([atom(body, "x")])),
    ])
}
fn sources() -> Data {
    list([
        relation("input", true, vec![vec!["a"], vec!["b"]]),
        relation("blocked", true, vec![vec!["b"]]),
    ])
}
fn program(sources: &Data, answer: bool) -> Data {
    let mut relations = sources.list().unwrap().to_vec();
    relations.push(relation("proof", false, vec![]));
    let mut rules = vec![rule("proof", "input")];
    if answer {
        relations.push(relation("answer", false, vec![]));
        let mut blocked = atom("blocked", "x").map().unwrap().clone();
        blocked.insert("not".into(), true.into());
        rules.push(Data::object([
            ("head", list([atom("answer", "x")])),
            ("body", list([atom("proof", "x"), Data::Map(blocked)])),
        ]));
    }
    Data::object([
        ("relations", list(relations)),
        ("rules", list(rules)),
        (
            "queries",
            list([if answer { "answer" } else { "proof" }.into()]),
        ),
    ])
}
#[test]
fn current_component_receipts_and_continuation_preserve_all_conjuncts() {
    let engine = Runtime::new(1).unwrap();
    let s = sources();
    let mut chain = EvidenceChain::new(&engine, s.clone(), true, FactLimits::default()).unwrap();
    let base = program(&s, false);
    let first = chain.query(&base).unwrap();
    let reference = first.field("resultReference").unwrap().text().unwrap();
    let contract = program(&s, true);
    let mut weakened = contract.map().unwrap().clone();
    let mut rules = weakened["rules"].list().unwrap().to_vec();
    let mut last = rules[1].map().unwrap().clone();
    last.insert("body".into(), list([atom("proof", "x")]));
    rules[1] = Data::Map(last);
    weakened.insert("rules".into(), list(rules));
    assert!(
        !chain
            .consume(reference, &Data::Map(weakened), &contract, Data::Null)
            .unwrap()
            .field("accepted")
            .unwrap()
            .boolean()
            .unwrap()
    );
    let accepted = chain
        .consume(reference, &contract, &contract, Data::Null)
        .unwrap();
    assert_ne!(
        accepted.field("reusedComponents").unwrap().list().unwrap(),
        []
    );
    let answer = accepted.field("resultReference").unwrap().text().unwrap();
    assert_eq!(
        chain.answer(answer, "answer").unwrap(),
        list([list(["a".into()])])
    );
    chain
        .replace(list([
            relation("input", true, vec![vec!["c"]]),
            relation("blocked", true, vec![]),
        ]))
        .unwrap();
    assert!(chain.answer(answer, "answer").is_err());
    assert!(
        chain
            .consume(reference, &contract, &contract, Data::Null)
            .is_err()
    );
    assert!(chain.query(&contract).is_err());
}
#[test]
fn canonical_graph_is_dependency_first_without_mutating_rules() {
    let p = program(&sources(), true);
    let before = p.clone();
    assert_eq!(
        evidence_graph::components(&p).unwrap(),
        vec![vec!["proof"], vec!["answer"]]
    );
    let rules = p.field("rules").unwrap().list().unwrap();
    let canonical = evidence_graph::canonical_rule(&rules[1]).unwrap();
    assert_eq!(
        canonical.field("head").unwrap().list().unwrap()[0]
            .field("terms")
            .unwrap()
            .list()
            .unwrap()[0]
            .field("var")
            .unwrap(),
        &Data::from("0")
    );
    assert_eq!(p, before);
}
#[test]
fn repeated_completed_requests_do_not_reexecute_or_share_mutable_packets() {
    let engine = Runtime::new(1).unwrap();
    let s = sources();
    let mut chain = EvidenceChain::new(&engine, s.clone(), true, FactLimits::default()).unwrap();
    let p = program(&s, true);
    let first = chain.query(&p).unwrap();
    let second = chain.query(&p).unwrap();
    assert!(!first.field("retainedCompleted").unwrap().boolean().unwrap());
    assert!(
        second
            .field("retainedCompleted")
            .unwrap()
            .boolean()
            .unwrap()
    );
    let reference = first.field("resultReference").unwrap().text().unwrap();
    let intermediate = chain.intermediates(reference, &["proof".into()]).unwrap();
    assert_eq!(
        intermediate
            .field("facts")
            .unwrap()
            .field("proof")
            .unwrap()
            .list()
            .unwrap()
            .len(),
        2
    );
    assert!(chain.intermediates(reference, &["answer".into()]).is_err());
}
fn truth(edges: &[(i64, i64)]) -> BTreeSet<(i64, i64)> {
    let vertices = edges
        .iter()
        .flat_map(|(a, b)| [*a, *b])
        .collect::<BTreeSet<_>>();
    let mut out = edges
        .iter()
        .copied()
        .chain(vertices.iter().map(|n| (*n, *n)))
        .collect::<BTreeSet<_>>();
    loop {
        let before = out.len();
        let old = out.clone();
        for &(a, b) in &old {
            for &(c, d) in &old {
                if b == c {
                    out.insert((a, d));
                }
            }
        }
        if out.len() == before {
            return out;
        }
    }
}
#[test]
fn compressed_closure_matches_independent_finite_truth_and_exact_admission() {
    let choices = [(0, 1), (1, 2), (2, 0), (2, 3), (4, 3)];
    let cancel = Cancellation::default();
    for mask in 0..32 {
        let mut reach = Reachability::new();
        let mut edges = Vec::new();
        let mut total = 0;
        for (bit, &edge) in choices.iter().enumerate() {
            if mask & (1 << bit) == 0 {
                continue;
            }
            let before = reach.freeze();
            let physical = reach.resources();
            edges.push(edge);
            let expected = truth(&edges);
            let added = expected.len() - total;
            if added > 0 {
                assert!(
                    reach
                        .insert(&[edge.0.into(), edge.1.into()], added - 1, &cancel)
                        .is_err()
                );
                assert_eq!(reach.resources(), physical);
            }
            assert_eq!(
                reach
                    .insert(&[edge.0.into(), edge.1.into()], added, &cancel)
                    .unwrap(),
                added
            );
            assert_eq!(before.len(), total);
            assert!(reach.validate(&cancel).unwrap());
            total = expected.len();
            let rows = reach.freeze().rows(&[], 1000, &cancel).unwrap();
            let rows = rows
                .iter()
                .map(|r| (r[0].clone(), r[1].clone()))
                .collect::<BTreeSet<_>>();
            assert_eq!(
                rows,
                expected
                    .into_iter()
                    .map(|(a, b)| (Value::from(a), Value::from(b)))
                    .collect()
            );
        }
    }
}
#[test]
fn cancelled_closure_insertion_and_failed_exports_leave_cut_unchanged() {
    let mut reach = Reachability::new();
    let cancel = Cancellation::default();
    reach.insert(&[0.into(), 1.into()], 3, &cancel).unwrap();
    let held = reach.freeze();
    let resources = reach.resources();
    cancel.cancel();
    assert!(reach.insert(&[1.into(), 2.into()], 10, &cancel).is_err());
    assert_eq!(resources, reach.resources());
    let cancel = Cancellation::default();
    assert!(held.rows(&[], 2, &cancel).is_err());
    assert_eq!(held.len(), 3);
    assert_eq!(
        held.rows(&[(0, 0.into()), (0, 1.into())], 100, &cancel)
            .unwrap(),
        [] as [std::sync::Arc<[Value]>; 0]
    );
}
fn candidate() -> Data {
    list([
        "candidate".into(),
        list(["relation".into(), "path".into(), 2usize.into()]),
        list([
            "rule".into(),
            list(["path".into(), "?x".into(), "?y".into()]),
            list(["edge".into(), "?x".into(), "?y".into()]),
        ]),
        list([
            "rule".into(),
            list(["path".into(), "?x".into(), "?z".into()]),
            list(["path".into(), "?x".into(), "?y".into()]),
            list(["edge".into(), "?y".into(), "?z".into()]),
        ]),
        list(["query".into(), "path".into(), "?x".into(), "?y".into()]),
        list([
            "limits".into(),
            256usize.into(),
            1024usize.into(),
            1024usize.into(),
        ]),
    ])
}
fn snapshot(generation: usize, edges: &[[usize; 2]]) -> Data {
    Data::object([
        ("identity", "caller-owned".into()),
        ("generation", generation.into()),
        (
            "relations",
            list([list([
                "edge".into(),
                2usize.into(),
                list(
                    edges
                        .iter()
                        .map(|r| list(r.iter().copied().map(Data::from))),
                ),
            ])]),
        ),
    ])
}
#[test]
fn checked_receipts_are_owner_source_generation_and_candidate_bound() {
    let engine = Runtime::new(1).unwrap();
    let mut a = ComputationalEvidence::new(&engine).unwrap();
    let b = ComputationalEvidence::new(&engine).unwrap();
    let source = snapshot(0, &[[0, 1], [1, 2]]);
    let candidate = candidate();
    let resolved = a.resolve(&source, &candidate).unwrap();
    assert_eq!(
        resolved.field("status").unwrap(),
        &Data::from("verified"),
        "{resolved:?}"
    );
    let handle = u64::try_from(resolved.field("handle").unwrap().index().unwrap()).unwrap();
    let atom = list(["path".into(), 0usize.into(), 2usize.into()]);
    let observed = a
        .observe(&agentic_ai_lab_reasoning::ObservationRequest {
            source: &source,
            candidate: &candidate,
            handle,
            atoms: &list([atom.clone()]),
            support: true,
        })
        .unwrap();
    assert_ne!(observed.field("supportNodes").unwrap().list().unwrap(), []);
    assert_eq!(
        agentic_ai_lab_reasoning::expand_observation(
            &agentic_ai_lab_reasoning::compact_observation(&observed).unwrap()
        )
        .unwrap(),
        observed
    );
    assert_eq!(
        b.fact(&source, &candidate, handle, &atom)
            .unwrap()
            .field("status")
            .unwrap(),
        &Data::from("unknown")
    );
    let withdrawn = snapshot(1, &[[0, 1]]);
    assert_eq!(
        a.fact(&withdrawn, &candidate, handle, &atom)
            .unwrap()
            .field("status")
            .unwrap(),
        &Data::from("unknown")
    );
    let fresh = a.resolve(&withdrawn, &candidate).unwrap();
    let handle = u64::try_from(fresh.field("handle").unwrap().index().unwrap()).unwrap();
    let absent = a.fact(&withdrawn, &candidate, handle, &atom).unwrap();
    assert_eq!(
        absent.field("status").unwrap(),
        &Data::from("finite-absent")
    );
    assert_eq!(absent.field("support-nodes").unwrap().list().unwrap(), []);
}
