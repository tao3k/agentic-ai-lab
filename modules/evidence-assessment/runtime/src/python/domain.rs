//! Exact domain observations and immutable checker version are Rust-owned.
use super::{bindings::Engine, packets, types::error};
use crate::{Data, DomainEvidence as Memory};
use pyo3::{Bound, Py, PyAny, PyRef, PyResult, Python, pyclass, pyfunction, pymethods};
use std::sync::Mutex;
#[pyclass(name = "DomainEvidence", frozen)]
pub(super) struct DomainEvidence(Mutex<Memory>);
impl DomainEvidence {
    fn lock(&self) -> PyResult<std::sync::MutexGuard<'_, Memory>> {
        self.0.lock().map_err(|_| {
            pyo3::exceptions::PyRuntimeError::new_err("domain observation lock poisoned")
        })
    }
}
#[pymethods]
impl DomainEvidence {
    #[new]
    #[pyo3(signature=(engine,snapshot,retain=true))]
    fn new(engine: &Engine, snapshot: &str, retain: bool) -> PyResult<Self> {
        Memory::new(&engine.0, snapshot, retain)
            .map(|r| Self(Mutex::new(r)))
            .map_err(error)
    }
    fn replace_snapshot(&self, snapshot: &str) -> PyResult<()> {
        self.lock()?.replace_snapshot(snapshot).map_err(error)
    }
    fn observe(
        &self,
        py: Python<'_>,
        kind: &str,
        observations: &Bound<'_, PyAny>,
        observation_receipt: &str,
    ) -> PyResult<Py<PyAny>> {
        let observations = packets::read(observations)?;
        let result = py.detach(|| {
            self.lock()?
                .observe(kind, &observations, observation_receipt)
                .map_err(error)
        })?;
        packets::write(py, &result)
    }
    fn summary(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        let result = py.detach(|| self.lock()?.summary().map_err(error))?;
        packets::write(py, &result)
    }
    #[getter]
    fn journal(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        packets::write(py, &Data::List(self.lock()?.journal().to_vec()))
    }
    #[getter]
    fn checker_version(&self) -> PyResult<&'static str> {
        self.lock()?.checker_version().map_err(error)
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
pub(super) fn domain_checker_version() -> &'static str {
    crate::domain_checker_version()
}
