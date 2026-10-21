//! Indexed lookup with the original ordered rendering and equal-summary removal.
use super::invalid;
use crate::{Data, Result};
use std::collections::BTreeMap;

pub(super) struct DeferredRelations {
    ordered: Vec<Data>,
    by_name: BTreeMap<String, Vec<Data>>,
}
impl DeferredRelations {
    pub(super) fn new(ordered: Vec<Data>) -> Self {
        let mut result = Self {
            ordered: Vec::with_capacity(ordered.len()),
            by_name: BTreeMap::new(),
        };
        for row in ordered {
            result.push(row);
        }
        result
    }
    pub(super) fn summary(&self, name: &str) -> Result<Data> {
        self.by_name
            .get(name)
            .and_then(|rows| rows.first())
            .cloned()
            .ok_or_else(|| invalid("missing relation summary"))
    }
    pub(super) fn remove(&mut self, summary: &Data) {
        self.ordered.retain(|row| row != summary);
        if let Ok(name) = summary.field("relation").and_then(Data::text)
            && let Some(rows) = self.by_name.get_mut(name)
        {
            rows.retain(|row| row != summary);
        }
    }
    pub(super) fn push(&mut self, summary: Data) {
        if let Ok(name) = summary.field("relation").and_then(Data::text) {
            self.by_name
                .entry(name.into())
                .or_default()
                .push(summary.clone());
        }
        self.ordered.push(summary);
    }
    pub(super) fn data(&self) -> Data {
        Data::List(self.ordered.clone())
    }
    pub(super) fn is_empty(&self) -> bool {
        self.ordered.is_empty()
    }
}

#[cfg(test)]
#[path = "tests/deferred.rs"]
mod tests;
