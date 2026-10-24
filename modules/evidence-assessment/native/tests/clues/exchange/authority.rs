use super::{
    Cancellation, ClueExchange, ClueProjection, ClueSelector, Data, Limits, PROJECTION, Runtime,
    at, clue_sexpr, exchange, facts, list, rows,
};

#[test]
fn clues_observation_counter_and_unknown_are_distinct() {
    let engine = Runtime::new(1).unwrap();
    let mut owner = exchange(&engine);
    let result = owner
        .read(
            &["old-is-unexplored".into(), "novel".into()],
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    assert_eq!(rows(&result, &["counterevidence"]).len(), 1);
    assert_eq!(rows(&result, &["support"]), []);
    assert_eq!(at(&result, &["unknown"]), &list(&[&["novel"]]));
    assert!(clue_sexpr(&result).contains("not-same-cause"));
}
#[test]
fn clues_source_mismatch_is_rejected() {
    let engine = Runtime::new(1).unwrap();
    assert!(
        ClueExchange::new(
            &engine,
            ClueProjection {
                sources: &[PROJECTION],
                constructor: "project",
                supplied: &facts(),
                attestations: &Data::object([("receipt", "other".into())])
            },
            &Limits::default(),
            &Cancellation::default()
        )
        .is_err()
    );
}
#[test]
fn clues_novel_hypothesis_selects_without_promotion_or_closed_vocabulary() {
    let engine = Runtime::new(1).unwrap();
    let mut owner = exchange(&engine);
    let hint = Data::object([
        ("id", "new".into()),
        ("claim", "novel".into()),
        ("polarity", "support".into()),
        ("source", "agent".into()),
        ("factors", list(&[&["unlisted-factor", "unlisted-value"]])),
    ]);
    owner.submit(&Data::List(vec![hint.clone()])).unwrap();
    let selected = owner
        .select(
            ClueSelector {
                sources: &[PROJECTION],
                constructor: "select",
            },
            &list(&[&["unlisted-factor", "unlisted-value"]]),
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    assert_eq!(at(&selected, &["question"]), &list(&[&["novel"]]));
    let result = owner
        .read(
            &["novel".into()],
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    assert_eq!(rows(&result, &["support"]), []);
    assert_eq!(rows(&result, &["conditional"]).len(), 1);
    assert_eq!(at(&result, &["unknown"]), &list(&[&["novel"]]));
    assert!(owner.submit(&Data::List(vec![hint])).is_err());
}
#[test]
fn clues_failed_batch_does_not_partially_publish() {
    let engine = Runtime::new(1).unwrap();
    let mut owner = exchange(&engine);
    let hint = Data::object([
        ("id", "new".into()),
        ("claim", "novel".into()),
        ("polarity", "support".into()),
        ("source", "agent".into()),
    ]);
    assert!(owner.submit(&Data::List(vec![hint.clone(), hint])).is_err());
    let result = owner
        .read(
            &["novel".into()],
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    assert_eq!(rows(&result, &["conditional"]), []);
}

#[test]
fn clues_collision_cancellation_and_close_do_not_create_authority() {
    let engine = Runtime::new(1).unwrap();
    let mut owner = exchange(&engine);
    assert!(owner.include(exchange(&engine)).is_err());
    let canceled = Cancellation::default();
    canceled.cancel();
    assert!(
        owner
            .read(&["old-is-unexplored".into()], &Limits::default(), &canceled)
            .is_err()
    );
    let result = owner
        .read(
            &["old-is-unexplored".into()],
            &Limits::default(),
            &Cancellation::default(),
        )
        .unwrap();
    assert_eq!(rows(&result, &["counterevidence"]).len(), 1);
    owner.close();
    assert!(
        owner
            .read(
                &["novel".into()],
                &Limits::default(),
                &Cancellation::default()
            )
            .is_err()
    );
    assert!(owner.inventory().is_err());
    assert!(owner.submit(&Data::List(vec![])).is_err());
}
