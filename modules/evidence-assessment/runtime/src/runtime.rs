//! POO application lifetime; relational execution is delegated to ASCENT.
use crate::{Error, Result};
use std::sync::{Arc, atomic::AtomicUsize};
/// POO application lifetime and accounting; evaluation belongs to ASCENT.
#[derive(Clone)]
pub struct Runtime {
    execution: gerbil_ascent::Engine,
    pub(crate) evidence_owners: Arc<AtomicUsize>,
    pub(crate) trajectory_owners: Arc<AtomicUsize>,
}
impl Runtime {
    /// # Errors
    /// Propagates rule-engine pool and process admission errors.
    pub fn new(workers: usize) -> Result<Self> {
        Ok(Self {
            execution: gerbil_ascent::Engine::new(workers)?,
            evidence_owners: Arc::default(),
            trajectory_owners: Arc::default(),
        })
    }
}
impl std::ops::Deref for Runtime {
    type Target = gerbil_ascent::Engine;
    fn deref(&self) -> &Self::Target {
        &self.execution
    }
}
pub(crate) fn invalid_data(message: &str) -> Error {
    Error::InvalidProgram(message.into())
}
