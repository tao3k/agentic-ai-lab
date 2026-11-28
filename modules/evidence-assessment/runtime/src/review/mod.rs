//! Source-qualified review observations and declarative policy; never execution authorization.
mod owner;
mod policy;
pub use owner::EvidenceReview;
pub use policy::review_sources;
