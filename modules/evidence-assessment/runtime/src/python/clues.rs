//! Transport only: clue semantics and declarative evaluation belong to the Library.
use super::{bindings::Engine as Owner, error, packets};
use crate::{
    Cancellation, ClueExchange as Exchange, ClueProjection, ClueSelector, SourceSession, clue_sexpr,
};
use pyo3::{
    Bound, IntoPyObject, Py, PyAny, PyResult, Python, exceptions::PyRuntimeError, pyclass,
    pymethods, types::PyAnyMethods,
};
use std::sync::Mutex;

#[pyclass(name = "ClueExchange", frozen)]
pub(super) struct ClueExchange(Mutex<Exchange>);

#[pymethods]
impl ClueExchange {
    #[staticmethod]
    fn parse_request(source: &str, py: Python<'_>) -> PyResult<Py<PyAny>> {
        let request = crate::read_clue_request(source).map_err(error)?;
        packets::write(py, &request)
    }
    fn close(&self) -> PyResult<()> {
        self.0
            .lock()
            .map_err(|_| PyRuntimeError::new_err("Clue exchange lock poisoned"))?
            .close();
        Ok(())
    }
    fn inventory(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        let result = self
            .0
            .lock()
            .map_err(|_| PyRuntimeError::new_err("Clue exchange lock poisoned"))?
            .inventory()
            .map_err(error)?;
        packets::write(py, &result)
    }
    #[new]
    fn new(
        engine: &Owner,
        sources: &Bound<'_, PyAny>,
        constructor: &str,
        facts: &Bound<'_, PyAny>,
        attestations: &Bound<'_, PyAny>,
        py: Python<'_>,
    ) -> PyResult<Self> {
        let sources = sources.extract::<Vec<String>>()?;
        let facts = packets::read(facts)?;
        let attestations = packets::read(attestations)?;
        py.detach(|| {
            Exchange::new(
                &engine.0,
                ClueProjection {
                    sources: &sources.iter().map(String::as_str).collect::<Vec<_>>(),
                    constructor,
                    supplied: &facts,
                    attestations: &attestations,
                },
                &SourceSession::default_limits(),
                &Cancellation::default(),
            )
        })
        .map(|v| Self(Mutex::new(v)))
        .map_err(error)
    }

    #[pyo3(signature = (questions, *, scheme=false))]
    fn read(
        &self,
        questions: &Bound<'_, PyAny>,
        scheme: bool,
        py: Python<'_>,
    ) -> PyResult<Py<PyAny>> {
        let questions = questions.extract::<Vec<String>>()?;
        let result = py
            .detach(|| {
                self.0
                    .lock()
                    .map_err(|_| "Clue exchange lock poisoned".to_string())?
                    .read(
                        &questions,
                        &SourceSession::default_limits(),
                        &Cancellation::default(),
                    )
                    .map_err(|e| e.to_string())
            })
            .map_err(error)?;
        if scheme {
            Ok(clue_sexpr(&result).into_pyobject(py)?.unbind().into())
        } else {
            packets::write(py, &result)
        }
    }

    fn select(
        &self,
        sources: &Bound<'_, PyAny>,
        constructor: &str,
        bindings: &Bound<'_, PyAny>,
        py: Python<'_>,
    ) -> PyResult<Py<PyAny>> {
        let sources = sources.extract::<Vec<String>>()?;
        let bindings = packets::read(bindings)?;
        let result = py
            .detach(|| {
                self.0
                    .lock()
                    .map_err(|_| "Clue exchange lock poisoned".to_string())?
                    .select(
                        ClueSelector {
                            sources: &sources.iter().map(String::as_str).collect::<Vec<_>>(),
                            constructor,
                        },
                        &bindings,
                        &SourceSession::default_limits(),
                        &Cancellation::default(),
                    )
                    .map_err(|e| e.to_string())
            })
            .map_err(error)?;
        packets::write(py, &result)
    }

    fn slice(&self, request: &Bound<'_, PyAny>, py: Python<'_>) -> PyResult<Py<PyAny>> {
        let request = packets::read(request)?;
        let result = py
            .detach(|| {
                self.0
                    .lock()
                    .map_err(|_| "Clue exchange lock poisoned".to_string())?
                    .slice(
                        &request,
                        &SourceSession::default_limits(),
                        &Cancellation::default(),
                    )
                    .map_err(|e| e.to_string())
            })
            .map_err(error)?;
        packets::write(py, &result)
    }

    fn slice_selected(
        &self,
        sources: &Bound<'_, PyAny>,
        constructor: &str,
        request: &Bound<'_, PyAny>,
        py: Python<'_>,
    ) -> PyResult<Py<PyAny>> {
        let sources = sources.extract::<Vec<String>>()?;
        let request = packets::read(request)?;
        let result = py
            .detach(|| {
                self.0
                    .lock()
                    .map_err(|_| "Clue exchange lock poisoned".to_string())?
                    .slice_selected(
                        ClueSelector {
                            sources: &sources.iter().map(String::as_str).collect::<Vec<_>>(),
                            constructor,
                        },
                        &request,
                        &SourceSession::default_limits(),
                        &Cancellation::default(),
                    )
                    .map_err(|e| e.to_string())
            })
            .map_err(error)?;
        packets::write(py, &result)
    }

    fn submit(&self, hypotheses: &Bound<'_, PyAny>) -> PyResult<()> {
        let hypotheses = packets::read(hypotheses)?;
        self.0
            .lock()
            .map_err(|_| PyRuntimeError::new_err("Clue exchange lock poisoned"))?
            .submit(&hypotheses)
            .map_err(error)
    }

    #[pyo3(signature = (sources, constructor, bindings, *, scheme=false))]
    fn read_selected(
        &self,
        sources: &Bound<'_, PyAny>,
        constructor: &str,
        bindings: &Bound<'_, PyAny>,
        scheme: bool,
        py: Python<'_>,
    ) -> PyResult<Py<PyAny>> {
        let sources = sources.extract::<Vec<String>>()?;
        let bindings = packets::read(bindings)?;
        let result = py
            .detach(|| {
                self.0
                    .lock()
                    .map_err(|_| "Clue exchange lock poisoned".to_string())?
                    .read_selected(
                        ClueSelector {
                            sources: &sources.iter().map(String::as_str).collect::<Vec<_>>(),
                            constructor,
                        },
                        &bindings,
                        &SourceSession::default_limits(),
                        &Cancellation::default(),
                    )
                    .map_err(|e| e.to_string())
            })
            .map_err(error)?;
        if scheme {
            Ok(clue_sexpr(&result).into_pyobject(py)?.unbind().into())
        } else {
            packets::write(py, &result)
        }
    }

    fn include(
        &self,
        engine: &Owner,
        sources: &Bound<'_, PyAny>,
        constructor: &str,
        facts: &Bound<'_, PyAny>,
        attestations: &Bound<'_, PyAny>,
        py: Python<'_>,
    ) -> PyResult<()> {
        let sources = sources.extract::<Vec<String>>()?;
        let facts = packets::read(facts)?;
        let attestations = packets::read(attestations)?;
        py.detach(|| {
            let other = Exchange::new(
                &engine.0,
                ClueProjection {
                    sources: &sources.iter().map(String::as_str).collect::<Vec<_>>(),
                    constructor,
                    supplied: &facts,
                    attestations: &attestations,
                },
                &SourceSession::default_limits(),
                &Cancellation::default(),
            )
            .map_err(error)?;
            self.0
                .lock()
                .map_err(|_| PyRuntimeError::new_err("Clue exchange lock poisoned"))?
                .include(other)
                .map_err(error)
        })
    }

    #[staticmethod]
    fn render(value: &Bound<'_, PyAny>) -> PyResult<String> {
        Ok(clue_sexpr(&packets::read(value)?))
    }
}
