//! Agentic AI Lab assessment, evidence reuse and agent context over a rules Library.
#[path = "../../../ai-agentic-context/clues/native/mod.rs"]
mod clues;
mod computational;
mod conversation;
mod derivations;
mod domain;
mod domain_memory;
pub mod evidence_graph;
mod evidence_store;
#[path = "../../../ai-agentic-context/interaction/native/mod.rs"]
mod interaction;
mod observations;
mod provider;
mod review;
#[path = "../../../temporal-causality/trajectory/native/mod.rs"]
mod trajectory;

pub use clues::{ClueExchange, ClueProjection, ClueSelector, clue_sexpr, read_clue_request};
pub use computational::{ComputationalEvidence, ObservationRequest};
pub use conversation::{ResponseHistory, ToolCallId};
pub use derivations::EvidenceChain;
pub use domain::{domain_check, domain_contract};
pub use domain_memory::{DomainEvidence, domain_checker_version};
pub use evidence_store::EvidenceStore;
pub use gerbil_ascent::{
    Atom, Cancellation, Catalog, Clause, Data, DatalogRequest, Error, Expression, FactLimits,
    Limits, Operator, Program, ProvenanceEdge, ProvenanceGraph, ProvenanceLimits, ProvenanceStatus,
    Reachability, Reducer, Relation, Result, Row, Rule, Session, SourceSession, Term, Type, Value,
    evaluate_datalog, read_datalog, rows_equal,
};
pub use interaction::{
    BranchEvaluation, EvidenceInteraction, EvidenceOperation, compact_feedback, expand_feedback,
};
pub use observations::{compact_observation, expand_observation};
pub use provider::read_provider_arguments;
pub use review::{EvidenceReview, review_sources};
pub use trajectory::Trajectory;

mod runtime;
use Runtime as Engine;
pub use runtime::Runtime;
use runtime::invalid_data;

#[cfg(feature = "python")]
mod python;
