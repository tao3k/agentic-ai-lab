//! Review bindings expose Rust-owned policy receipts, not mutable evaluator internals.
use super::{bindings::Engine, packets, types::error};
use crate::EvidenceReview as Review;
use pyo3::{Bound, Py, PyAny, PyRef, PyResult, Python, pyclass, pyfunction, pymethods};
use std::sync::Mutex;
#[pyclass(name = "EvidenceReview", frozen)]
pub(super) struct EvidenceReview(Mutex<Review>);
impl EvidenceReview {
    fn lock(&self) -> PyResult<std::sync::MutexGuard<'_, Review>> {
        self.0
            .lock()
            .map_err(|_| pyo3::exceptions::PyRuntimeError::new_err("review lock poisoned"))
    }
}
#[pymethods]
impl EvidenceReview {
    #[new]
    fn new(engine: &Engine, facts: &Bound<'_, PyAny>) -> PyResult<Self> {
        Review::new(&engine.0, &packets::read(facts)?)
            .map(|r| Self(Mutex::new(r)))
            .map_err(error)
    }
    fn replace(&self, facts: &Bound<'_, PyAny>) -> PyResult<()> {
        self.lock()?.replace(&packets::read(facts)?).map_err(error)
    }
    fn review(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        let result = py.detach(|| self.lock()?.review().map_err(error))?;
        packets::write(py, &result)
    }
    fn answer(&self, py: Python<'_>, reference: &str, relation: &str) -> PyResult<Py<PyAny>> {
        packets::write(
            py,
            &self.lock()?.answer(reference, relation).map_err(error)?,
        )
    }
    fn close(&self) -> PyResult<()> {
        self.lock()?.close();
        Ok(())
    }
    fn __enter__(slf: PyRef<'_, Self>) -> PyRef<'_, Self> {
        slf
    }
    fn __exit__(
        &self,
        _a: &Bound<'_, PyAny>,
        _b: &Bound<'_, PyAny>,
        _c: &Bound<'_, PyAny>,
    ) -> PyResult<()> {
        self.close()
    }
}
#[pyfunction]
pub(super) fn review_sources(facts: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
    packets::write(
        facts.py(),
        &crate::review_sources(&packets::read(facts)?).map_err(error)?,
    )
}
