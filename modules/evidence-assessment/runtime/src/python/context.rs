//! Application owner and accounting; relational execution is supplied by ASCENT.
use super::{packets, sources::FactLimits};
use crate::{Cancellation, Catalog, Data, SourceSession};
use pyo3::{Bound, Py, PyAny, Python};
use pyo3::{PyRef, PyResult, pyclass, pymethods};
use std::{collections::BTreeMap, sync::Mutex};

#[pyclass(
    name = "ReasoningRuntime",
    module = "agentic_ai_lab_runtime.reasoning",
    frozen
)]
pub(super) struct Runtime(pub(super) crate::Runtime);
#[pymethods]
impl Runtime {
    #[new]
    #[pyo3(signature=(*,workers=1))]
    fn new(workers: usize) -> PyResult<Self> {
        crate::Runtime::new(workers).map(Self).map_err(super::error)
    }
    fn close(&self) {
        self.0.shutdown();
    }
    #[getter]
    fn closed(&self) -> bool {
        self.0.is_closed()
    }
    fn __enter__(slf: PyRef<'_, Self>) -> PyRef<'_, Self> {
        slf
    }
    fn __exit__(
        &self,
        _t: &pyo3::Bound<'_, pyo3::PyAny>,
        _v: &pyo3::Bound<'_, pyo3::PyAny>,
        _b: &pyo3::Bound<'_, pyo3::PyAny>,
    ) {
        self.close();
    }
    #[pyo3(signature=(source,constructor=None,*,trusted=false,limits=None))]
    fn rules(
        &self,
        source: &str,
        constructor: Option<&str>,
        trusted: bool,
        limits: Option<PyRef<'_, FactLimits>>,
        py: Python<'_>,
    ) -> PyResult<Rules> {
        if !trusted {
            return Err(super::error("explicit trusted rule declaration required"));
        }
        let limits = limits.map(|l| l.0).unwrap_or_default();
        py.detach(|| {
            self.0
                .open_declaration_sources(&[source], constructor, limits)
        })
        .map(|v| Rules(Mutex::new(v)))
        .map_err(super::error)
    }
    #[pyo3(signature=(program,*,limits=None))]
    fn open(
        &self,
        program: &Bound<'_, PyAny>,
        limits: Option<PyRef<'_, FactLimits>>,
        py: Python<'_>,
    ) -> PyResult<Rules> {
        let catalog = Catalog::read(&packets::read(program)?).map_err(super::error)?;
        let limits = limits.map(|l| l.0).unwrap_or_default();
        py.detach(|| {
            self.0
                .open_catalog(catalog.program, BTreeMap::new(), catalog.queries, limits)
        })
        .map(|v| Rules(Mutex::new(v)))
        .map_err(super::error)
    }
}
#[pyclass(name = "RuleSession", module = "agentic_ai_lab_runtime.reasoning", frozen)]
pub(super) struct Rules(Mutex<SourceSession>);
impl Rules {
    fn lock(&self) -> PyResult<std::sync::MutexGuard<'_, SourceSession>> {
        self.0
            .lock()
            .map_err(|_| super::error("rule session lock poisoned"))
    }
}
#[pymethods]
impl Rules {
    fn replace(&self, facts: &Bound<'_, PyAny>, py: Python<'_>) -> PyResult<u64> {
        let supplied = packets::read(facts)?;
        py.detach(|| {
            let mut session = self.lock()?;
            let mut rows = BTreeMap::new();
            for (name, values) in supplied.map().map_err(super::error)? {
                let descriptor = session
                    .descriptors()
                    .iter()
                    .find(|d| &d.name == name)
                    .ok_or_else(|| super::error("unknown source relation"))?;
                let converted = values
                    .list()
                    .map_err(super::error)?
                    .iter()
                    .map(|row| {
                        let values = row.list().map_err(super::error)?;
                        if values.len() != descriptor.columns.len() {
                            return Err(super::error("source tuple arity"));
                        }
                        let fields = values
                            .iter()
                            .zip(&descriptor.columns)
                            .map(|(v, t)| Catalog::scalar(v, *t).map_err(super::error))
                            .collect::<PyResult<Vec<_>>>()?;
                        Ok(crate::Row::from(fields))
                    })
                    .collect::<PyResult<Vec<_>>>()?;
                rows.insert(name.clone(), converted);
            }
            session
                .replace(
                    rows,
                    &SourceSession::default_limits(),
                    &Cancellation::default(),
                )
                .map_err(super::error)
        })
    }
    fn run(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        let data = py.detach(|| {
            let result = self
                .lock()?
                .run(
                    None,
                    &SourceSession::default_limits(),
                    &Cancellation::default(),
                )
                .map_err(super::error)?;
            let rows = result
                .relations
                .iter()
                .map(|(n, r)| Ok((n.clone(), observed_rows(r)?)))
                .collect::<PyResult<BTreeMap<_, _>>>()?;
            Ok::<_, pyo3::PyErr>(Data::object([
                ("relations", Data::Map(rows)),
                ("complete", result.complete.into()),
                ("resultHandle", result.result_handle.into()),
                ("sourceGeneration", result.source_generation.into()),
                ("runIndex", result.run_index.into()),
                ("reused", result.reused.into()),
            ]))
        })?;
        packets::write(py, &data)
    }
    fn result(&self, receipt: &Bound<'_, PyAny>) -> PyResult<RuleResult> {
        let handle = packets::read(receipt)?
            .field("resultHandle")
            .map_err(super::error)?
            .index()
            .map_err(super::error)?;
        self.lock()?
            .result(handle as u64)
            .map(RuleResult)
            .map_err(super::error)
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
        _t: &Bound<'_, PyAny>,
        _v: &Bound<'_, PyAny>,
        _b: &Bound<'_, PyAny>,
    ) -> PyResult<()> {
        self.close()
    }
}
#[pyclass(name = "RuleResult", module = "agentic_ai_lab_runtime.reasoning", frozen)]
pub(super) struct RuleResult(gerbil_ascent::SourceResult);
#[pymethods]
impl RuleResult {
    fn close(&self) {
        self.0.close();
    }
}

// The observation protocol is shared with the generic Datalog query projection.
fn observed_rows(rows: &[crate::Row]) -> PyResult<Data> {
    Ok(Catalog::project_rows(rows))
}
