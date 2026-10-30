use super::{
    Cancellation, ClueExchange, ClueProjection, ClueSelector, Data, Limits, PROJECTION, Runtime,
    at, exchange, facts, list, rows,
};

#[test]
fn clues_projection_accepts_typed_observations_without_truthiness_coercion() {
    let source = "(define-program (project)
      (sources observed) (outputs clue factor link)
      (relation observed (flag count))
      (relation clue (id digest claim polarity role source))
      (relation factor (id digest name value))
      (relation link (claim target label id digest))
      ((clue (lit \"id\") (lit \"sha\") (lit \"claim\") (lit \"support\")
             (lit \"observation\") (lit \"receipt\")) <-- (observed (lit #f) (lit 1))))";
    let engine = Runtime::new(std::thread::available_parallelism().unwrap().get()).unwrap();
    for (flag, expected) in [
        (Data::Bool(false), 1),
        (Data::from(0usize), 0),
        (Data::from("false"), 0),
    ] {
        let supplied = Data::object([(
            "observed",
            Data::List(vec![Data::List(vec![flag, Data::from(1usize)])]),
        )]);
        let mut owner = ClueExchange::new(
            &engine,
            ClueProjection {
                sources: &[source],
                constructor: "project",
                supplied: &supplied,
                attestations: &Data::object([("receipt", "sha".into())]),
            },
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
        assert_eq!(
            owner
                .inventory()
                .unwrap()
                .field("claims")
                .unwrap()
                .list()
                .unwrap()
                .len(),
            expected
        );
        owner.close();
    }
}

#[test]
fn clues_checkpoint_only_restores_declared_query_in_a_new_owner() {
    let engine = Runtime::new(1).unwrap();
    let mut owner = exchange(&engine);
    let first = owner
        .slice_selected(
            ClueSelector {
                sources: &[PROJECTION],
                constructor: "select",
            },
            &Data::object([("bindings", list(&[&["mechanism", "old"]]))]),
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    owner.close();
    let request = Data::object([("checkpoint", at(&first, &["checkpoint"]).clone())]);
    let mut owner = exchange(&engine);
    let resumed = owner
        .slice(&request, &Limits::default(), &Cancellation::default())
        .unwrap();
    assert_eq!(at(&resumed, &["brief", "mode"]), &Data::from("incremental"));
    assert_eq!(rows(&resumed, &["brief", "families"]), []);
    assert_eq!(
        at(&resumed, &["brief", "delta", "added"]),
        &Data::from(0usize)
    );
    assert_eq!(
        at(&resumed, &["brief", "executionAuthorized"]),
        &Data::from(false)
    );

    let mut supplied = facts().map().unwrap().clone();
    let mut clues = supplied["clue"].list().unwrap().to_vec();
    clues.push(
        list(&[&[
            "added",
            "sha",
            "newly-discovered",
            "support",
            "observation",
            "receipt",
        ]])
        .list()
        .unwrap()[0]
            .clone(),
    );
    supplied.insert("clue".into(), Data::List(clues));
    supplied.insert(
        "factor".into(),
        list(&[
            &["known", "sha", "mechanism", "old"],
            &["added", "sha", "mechanism", "old"],
        ]),
    );
    let mut changed = ClueExchange::new(
        &engine,
        ClueProjection {
            sources: &[PROJECTION],
            constructor: "project",
            supplied: &Data::Map(supplied),
            attestations: &Data::object([("receipt", "sha".into())]),
        },
        &Limits::default(),
        &Cancellation::default(),
    )
    .unwrap();
    let refreshed = changed
        .slice(&request, &Limits::default(), &Cancellation::default())
        .unwrap();
    assert_eq!(at(&refreshed, &["brief", "mode"]), &Data::from("refresh"));
    assert_eq!(
        at(&refreshed, &["brief", "counts", "support"]),
        &Data::from(1usize)
    );
    assert_eq!(
        at(&refreshed, &["brief", "counts", "counter"]),
        &Data::from(1usize)
    );
    let claims = rows(&refreshed, &["brief", "families"])
        .iter()
        .map(|family| family.field("claim").unwrap().text().unwrap())
        .collect::<Vec<_>>();
    assert!(claims.contains(&"newly-discovered"));
}

#[test]
fn clues_unconfirmed_carrier_preserves_query_only_resume_without_sticky_replay() {
    let engine = Runtime::new(1).unwrap();
    let mut owner = exchange(&engine);
    let first = owner
        .slice_selected(
            ClueSelector {
                sources: &[PROJECTION],
                constructor: "select",
            },
            &Data::object([("bindings", list(&[&["mechanism", "old"]]))]),
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    let hint = at(&first, &["checkpoint"]).clone();
    let replayed = owner
        .slice(
            &Data::object([
                ("checkpoint", hint.clone()),
                ("readConfirmed", false.into()),
            ]),
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    assert_eq!(
        rows(&replayed, &["brief", "families"]),
        rows(&first, &["brief", "families"])
    );
    assert_eq!(
        at(&replayed, &["checkpoint", "body", "query"]),
        at(&first, &["checkpoint", "body", "query"])
    );
    let resumed = owner
        .slice(
            &Data::object([("checkpoint", at(&replayed, &["checkpoint"]).clone())]),
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    assert_eq!(rows(&resumed, &["brief", "families"]), []);
    assert_eq!(
        at(&resumed, &["brief", "delta", "added"]),
        &Data::from(0usize)
    );
    assert!(
        owner
            .slice(
                &Data::object([("checkpoint", hint), ("readConfirmed", "false".into()),]),
                &Limits::default(),
                &Cancellation::default()
            )
            .is_err()
    );
}

#[test]
fn clues_checkpoint_query_is_overridable_and_its_digest_is_checked() {
    let engine = Runtime::new(1).unwrap();
    let mut owner = exchange(&engine);
    let first = owner
        .slice_selected(
            ClueSelector {
                sources: &[PROJECTION],
                constructor: "select",
            },
            &Data::object([("bindings", list(&[&["mechanism", "old"]]))]),
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    let checkpoint = at(&first, &["checkpoint"]).clone();
    let explicit = owner
        .slice(
            &Data::object([
                ("checkpoint", checkpoint.clone()),
                (
                    "questions",
                    Data::List(vec!["outside-original-scope".into()]),
                ),
            ]),
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    assert_eq!(at(&explicit, &["brief", "mode"]), &Data::from("rescope"));
    assert_eq!(
        rows(&explicit, &["brief", "families"])[0]
            .field("claim")
            .unwrap(),
        &Data::from("outside-original-scope")
    );
    let other = owner
        .slice(
            &Data::object([
                ("checkpoint", checkpoint.clone()),
                ("bindings", list(&[&["mechanism", "unseen"]])),
            ]),
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    assert_eq!(
        at(&other, &["brief", "counts", "counter"]),
        &Data::from(0usize)
    );

    let mut body = checkpoint.field("body").unwrap().map().unwrap().clone();
    body.insert(
        "query".into(),
        Data::object([("questions", Data::List(vec!["forged".into()]))]),
    );
    let forged = Data::object([
        ("body", Data::Map(body)),
        ("digest", checkpoint.field("digest").unwrap().clone()),
    ]);
    assert!(
        owner
            .slice(
                &Data::object([("checkpoint", forged)]),
                &Limits::default(),
                &Cancellation::default()
            )
            .is_err()
    );

    let mut body = checkpoint.field("body").unwrap().map().unwrap().clone();
    body.remove("query");
    let body = Data::Map(body);
    let incomplete = Data::object([("digest", body.digest().into()), ("body", body)]);
    assert!(
        owner
            .slice(
                &Data::object([("checkpoint", incomplete.clone())]),
                &Limits::default(),
                &Cancellation::default()
            )
            .is_err()
    );
    assert!(
        owner
            .slice(
                &Data::object([
                    ("checkpoint", incomplete),
                    ("questions", Data::List(vec!["old-is-unexplored".into()]))
                ]),
                &Limits::default(),
                &Cancellation::default()
            )
            .is_ok()
    );
}
