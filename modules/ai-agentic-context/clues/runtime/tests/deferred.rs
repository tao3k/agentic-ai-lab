use super::DeferredRelations;
use crate::Data;
#[test]
fn equal_removal_and_rollback_preserve_original_first_match_order() {
    let first = Data::object([("relation", "r".into()), ("body", 1usize.into())]);
    let second = Data::object([("relation", "r".into()), ("body", 2usize.into())]);
    let other = Data::object([("relation", "s".into())]);
    let mut pending = DeferredRelations::new(vec![
        first.clone(),
        other.clone(),
        first.clone(),
        second.clone(),
    ]);
    assert_eq!(pending.summary("r").unwrap(), first);
    pending.remove(&first);
    assert_eq!(pending.summary("r").unwrap(), second);
    pending.push(first.clone());
    assert_eq!(
        pending.data(),
        Data::List(vec![other, second.clone(), first])
    );
    pending.remove(&second);
    assert_eq!(
        pending.summary("r").unwrap().field("body").unwrap(),
        &Data::from(1usize)
    );
}
