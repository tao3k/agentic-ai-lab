//! Existing Agentic AI Lab Python runtime's assessment bindings; no ASCENT application exports.
mod clues;
mod computational;
mod context;
mod conversation;
mod derivations;
mod domain;
mod evidence_conversation;
mod interaction;
#[path = "transport.rs"]
mod packets;
mod review;
mod sources;
mod trajectory;
mod types {
    pub(super) use super::error;
    pub(super) fn source_error(error: crate::Error) -> pyo3::PyErr {
        super::error(error)
    }
}
mod bindings {
    pub(super) use super::context::Runtime as Engine;
}
use pyo3::{
    Bound, PyErr, PyResult, pymodule,
    types::{PyModule, PyModuleMethods},
    wrap_pyfunction,
};
pyo3::create_exception!(
    agentic_ai_lab_runtime,
    ReasoningError,
    pyo3::exceptions::PyValueError
);
fn error(error: impl std::fmt::Display) -> PyErr {
    ReasoningError::new_err(error.to_string())
}
#[pymodule]
fn _reasoning(module: &Bound<'_, PyModule>) -> PyResult<()> {
    module.add("ReasoningError", module.py().get_type::<ReasoningError>())?;
    module.add_function(wrap_pyfunction!(runtime_identity, module)?)?;
    module.add_class::<context::Runtime>()?;
    module.add_class::<context::Rules>()?;
    module.add_class::<context::RuleResult>()?;
    module.add_class::<sources::FactLimits>()?;
    module.add_class::<computational::ComputationalEvidence>()?;
    module.add_class::<derivations::EvidenceStore>()?;
    module.add_class::<derivations::EvidenceChain>()?;
    module.add_class::<trajectory::Trajectory>()?;
    module.add_class::<clues::ClueExchange>()?;
    module.add_class::<interaction::EvidenceOperation>()?;
    module.add_class::<interaction::EvidenceInteraction>()?;
    module.add_class::<evidence_conversation::EvidenceConversation>()?;
    module.add_class::<conversation::ResponseHistory>()?;
    module.add_class::<domain::DomainEvidence>()?;
    module.add_class::<review::EvidenceReview>()?;
    module.add_function(wrap_pyfunction!(derivations::identity, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::components, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::evidence_graph, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::canonical_rule, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::normalize_contract, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::check_continuation, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::slice_program, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::compact_observation, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::expand_observation, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::domain_check, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::domain_contract, module)?)?;
    module.add_function(wrap_pyfunction!(derivations::rows_equal, module)?)?;
    module.add_function(wrap_pyfunction!(interaction::compact_feedback, module)?)?;
    module.add_function(wrap_pyfunction!(interaction::expand_feedback, module)?)?;
    module.add_function(wrap_pyfunction!(review::review_sources, module)?)?;
    module.add_function(wrap_pyfunction!(domain::domain_checker_version, module)?)?;
    Ok(())
}

#[pyo3::pyfunction]
fn runtime_identity(py: pyo3::Python<'_>) -> PyResult<pyo3::Py<pyo3::PyAny>> {
    let receipt = crate::read_provider_arguments(include_str!(concat!(
        env!("OUT_DIR"),
        "/reasoning-build.json"
    )))
    .map_err(error)?;
    packets::write(py, &receipt)
}
