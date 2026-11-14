//! Public owner boundary.
mod admission;
mod owner;
pub use owner::EvidenceStore;
pub(crate) use owner::{put, rows_data, schema};
