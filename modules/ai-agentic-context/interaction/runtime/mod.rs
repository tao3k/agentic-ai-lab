//! Registered local predicates, source-qualified path references and explicit epistemic outcomes.
mod feedback;
mod owner;
mod registry;
pub use feedback::{compact_feedback, expand_feedback};
pub use owner::{BranchEvaluation, EvidenceInteraction};
pub use registry::EvidenceOperation;

mod paths;

mod tools;
