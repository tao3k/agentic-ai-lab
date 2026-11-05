//! Generated provider-history bindings keep all pairing state in the Rust library.
use super::{packets, types::error};
use crate::ResponseHistory as History;
use pyo3::{Bound, Py, PyAny, PyResult, Python, pyclass, pymethods};
use std::sync::Mutex;
#[pyclass(name = "ResponseHistory", frozen)]
pub(super) struct ResponseHistory(pub(super) Mutex<History>);
impl ResponseHistory {
    pub(super) fn lock(&self) -> PyResult<std::sync::MutexGuard<'_, History>> {
        self.0.lock().map_err(|_| {
            pyo3::exceptions::PyRuntimeError::new_err("provider history lock poisoned")
        })
    }
}
#[pymethods]
impl ResponseHistory {
    #[new]
    fn new(question: &Bound<'_, PyAny>) -> PyResult<Self> {
        Ok(Self(Mutex::new(History::new(packets::read(question)?))))
    }
    #[staticmethod]
    fn restore(input: &Bound<'_, PyAny>) -> PyResult<Self> {
        History::restore(&packets::read(input)?)
            .map(|history| Self(Mutex::new(history)))
            .map_err(error)
    }
    fn snapshot(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        packets::write(py, &self.lock()?.snapshot())
    }
    #[getter]
    fn seen(&self) -> PyResult<std::collections::BTreeSet<String>> {
        Ok(self.lock()?.seen())
    }
    fn input(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        packets::write(py, &self.lock()?.input().map_err(error)?)
    }
    fn append_response(&self, py: Python<'_>, response: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
        let result = self
            .lock()?
            .append_response(&packets::read(response)?)
            .map_err(error)?;
        packets::write(py, &result)
    }
    fn append_result(&self, call_id: &str, result: &Bound<'_, PyAny>) -> PyResult<()> {
        self.lock()?
            .append_result(
                &crate::ToolCallId::new(call_id).map_err(error)?,
                &packets::read(result)?,
            )
            .map_err(error)
    }
    fn append_feedback(&self, result: &Bound<'_, PyAny>) -> PyResult<()> {
        self.lock()?
            .append_feedback(&packets::read(result)?)
            .map_err(error)
    }
    #[getter]
    fn reasoning_items(&self) -> PyResult<usize> {
        Ok(self.lock()?.reasoning_items())
    }
}
