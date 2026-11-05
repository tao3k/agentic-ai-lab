//! Public owner boundary.
mod continuation;
mod reuse;
mod slice;
pub use continuation::{check_continuation, normalize_contract};
pub use reuse::query_graph;
pub use slice::slice_program;
mod structure;
pub use structure::{canonical_rule, components, evidence_graph};
pub(crate) use structure::{component_rules, dependencies, heads, index, strings, texts, used};
