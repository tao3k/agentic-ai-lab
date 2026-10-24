//! No dispatcher: proof storage is a typed Rust owner, exposed directly through `PyO3`.
use super::{bindings::Engine, packets, types::source_error};
use crate::ComputationalEvidence as Store;
use pyo3::{Bound, Py, PyAny, PyRef, PyResult, Python, pyclass, pymethods};
use std::sync::Mutex;
#[pyclass(name = "ComputationalEvidence", frozen)]
pub(super) struct ComputationalEvidence(Mutex<Store>);
impl ComputationalEvidence {
    fn lock(&self) -> PyResult<std::sync::MutexGuard<'_, Store>> {
        self.0
            .lock()
            .map_err(|_| pyo3::exceptions::PyRuntimeError::new_err("proof owner lock poisoned"))
    }
}
#[pymethods]
impl ComputationalEvidence {
    #[new]
    fn new(engine: &Engine) -> PyResult<Self> {
        Store::new(&engine.0)
            .map(|s| Self(Mutex::new(s)))
            .map_err(source_error)
    }
    fn resolve(
        &self,
        py: Python<'_>,
        source: &Bound<'_, PyAny>,
        candidate: &Bound<'_, PyAny>,
    ) -> PyResult<Py<PyAny>> {
        let source = packets::read(source)?;
        let candidate = packets::read(candidate)?;
        let result = py.detach(|| {
            self.lock()?
                .resolve(&source, &candidate)
                .map_err(source_error)
        })?;
        packets::write(py, &result)
    }
    fn fact(
        &self,
        py: Python<'_>,
        source: &Bound<'_, PyAny>,
        candidate: &Bound<'_, PyAny>,
        handle: u64,
        atom: &Bound<'_, PyAny>,
    ) -> PyResult<Py<PyAny>> {
        let result = self
            .lock()?
            .fact(
                &packets::read(source)?,
                &packets::read(candidate)?,
                handle,
                &packets::read(atom)?,
            )
            .map_err(source_error)?;
        packets::write(py, &result)
    }
    fn fragment(
        &self,
        py: Python<'_>,
        source: &Bound<'_, PyAny>,
        candidate: &Bound<'_, PyAny>,
        handle: u64,
        atom: &Bound<'_, PyAny>,
    ) -> PyResult<Py<PyAny>> {
        let result = self
            .lock()?
            .fragment(
                &packets::read(source)?,
                &packets::read(candidate)?,
                handle,
                &packets::read(atom)?,
            )
            .map_err(source_error)?;
        packets::write(py, &result)
    }
    #[pyo3(signature=(source,candidate,handle,atoms,*,support=false))]
    fn observe(
        &self,
        py: Python<'_>,
        source: &Bound<'_, PyAny>,
        candidate: &Bound<'_, PyAny>,
        handle: u64,
        atoms: &Bound<'_, PyAny>,
        support: bool,
    ) -> PyResult<Py<PyAny>> {
        let source = packets::read(source)?;
        let candidate = packets::read(candidate)?;
        let atoms = packets::read(atoms)?;
        let result = self
            .lock()?
            .observe(&crate::ObservationRequest {
                source: &source,
                candidate: &candidate,
                handle,
                atoms: &atoms,
                support,
            })
            .map_err(source_error)?;
        packets::write(py, &result)
    }
    fn stats(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        packets::write(py, &self.lock()?.stats().map_err(source_error)?)
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
