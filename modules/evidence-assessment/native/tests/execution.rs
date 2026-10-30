// SPDX-FileCopyrightText: 2026 tao3k team and Contributors
// SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
//! Execution policy belongs to POO; rule execution and provenance remain native ASCENT APIs.
use gerbil_ascent::{
    Cancellation, Data, FactLimits, GraphItem, ObjectGraph, ObjectInput as Input, ObjectNode,
    ProvenanceLimits, SourceSession,
};
use std::collections::BTreeMap;

fn native_list(graph: &ObjectGraph, mut item: GraphItem) -> Vec<GraphItem> {
    let mut values = Vec::new();
    for _ in 0..=graph.nodes.len() {
        match item {
            GraphItem::Null => return values,
            GraphItem::Reference(id) => match &graph.nodes[&id] {
                ObjectNode::Pair(first, rest) => {
                    values.push(first.clone());
                    item = rest.clone();
                }
                _ => panic!("proper native tuple list required"),
            },
            _ => panic!("proper native tuple list required"),
        }
    }
    panic!("cyclic native tuple list");
}
fn text_rows(data: &Data) -> Vec<String> {
    let graph = ObjectGraph::read_scheme(data.field("value").unwrap()).unwrap();
    native_list(&graph, graph.root.clone())
        .into_iter()
        .map(|row| {
            let cells = native_list(&graph, row);
            assert_eq!(cells.len(), 1);
            let GraphItem::Reference(id) = cells[0] else {
                panic!("native text required")
            };
            let ObjectNode::Text(value) = &graph.nodes[&id] else {
                panic!("native text required")
            };
            value.as_str().to_string()
        })
        .collect()
}

#[test]
fn bundled_execution_evidence_uses_original_native_dsl_and_explicit_source_authority() {
    let engine = ascent_scheme::Engine::new(1).unwrap();
    const MODULE: &str = ":agentic-ai-lab/modules/evidence-assessment/execution";
    engine.register_module(MODULE, include_str!(
        "../../../../packages/python-runtime/src/agentic_ai_lab_runtime/reasoning_rules/execution.ss"
    )).unwrap();
    let module = engine.module(MODULE).unwrap();
    let value = module.call("make-execution-evidence", &[], None).unwrap();
    let session = value.open_session(FactLimits::default()).unwrap();
    module.close();
    let descriptors = session.program().unwrap().relations;
    assert!(
        descriptors
            .iter()
            .any(|r| r.name == "required_step" && r.source)
    );
    assert!(
        descriptors
            .iter()
            .any(|r| r.name == "checked_step" && !r.source)
    );
    let limits = SourceSession::default_limits();
    let cancel = Cancellation::default();
    session.run(None, &limits, &cancel).unwrap();
    session
        .replace(
            BTreeMap::from([
                (
                    "required_step".into(),
                    vec![
                        vec![Input::Text("finished".into())],
                        vec![Input::Text("missing".into())],
                    ],
                ),
                (
                    "observed_step".into(),
                    vec![vec![
                        Input::Text("finished".into()),
                        Input::Text("PASS".into()),
                        Input::Text("native.test".into()),
                    ]],
                ),
            ]),
            &limits,
            &cancel,
        )
        .unwrap();
    let observed = session.run(None, &limits, &cancel).unwrap();
    let handle = u64::try_from(observed.field("resultHandle").unwrap().index().unwrap()).unwrap();
    let result = session.result(handle).unwrap();
    assert_eq!(
        text_rows(&result.rows("checked_step").unwrap()),
        vec!["finished".to_string()]
    );
    assert_eq!(
        text_rows(&result.rows("missing_step").unwrap()),
        vec!["missing".to_string()]
    );
    let proof = session
        .provenance(
            handle,
            "missing_step",
            &ProvenanceLimits::default(),
            &cancel,
        )
        .unwrap();
    assert!(
        proof
            .verify(
                &proof.graph().unwrap(),
                &ProvenanceLimits::default(),
                &cancel
            )
            .unwrap()
    );
    let explanation = session.explain(handle, "missing_step").unwrap();
    assert!(format!("{:?}", explanation.graph().unwrap()).contains("source refinement"));
    assert!(
        session
            .replace(
                BTreeMap::from([(
                    "checked_step".into(),
                    vec![vec![Input::Text("forged".into())]]
                )]),
                &limits,
                &cancel
            )
            .is_err()
    );
    assert!(proof.graph().is_ok());
}
