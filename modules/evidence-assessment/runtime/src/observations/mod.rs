//! Public owner boundary.
mod expand;
pub use expand::expand_observation;
mod compact;
pub use compact::compact_observation;
pub(crate) use compact::remove;
