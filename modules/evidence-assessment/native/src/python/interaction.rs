//! Typed native local tools, with optional observation journaling owned by Rust.
use super::{bindings::Engine, packets, trajectory::Trajectory, types::error};
use crate::{Data, EvidenceInteraction as Tools, EvidenceOperation as Operation};
use pyo3::{
    Bound, Py, PyAny, PyRef, PyResult, Python, pyclass, pyfunction, pymethods,
    types::{PyAnyMethods, PyDict, PyDictMethods},
};
use std::{collections::BTreeMap, sync::Mutex};
#[pyclass(name = "EvidenceOperation", frozen)]
pub(super) struct EvidenceOperation(Operation);
#[pymethods]
impl EvidenceOperation {
    #[new]
    #[pyo3(signature=(program,relation,description,complete=None))]
    fn new(
        program: &Bound<'_, PyAny>,
        relation: &str,
        description: &str,
        complete: Option<&Bound<'_, PyAny>>,
    ) -> PyResult<Self> {
        let complete = complete
            .map(packets::read)
            .transpose()?
            .map(|v| v.boolean())
            .transpose()
            .map_err(error)?
            .unwrap_or(false);
        Operation::new(&packets::read(program)?, relation, description, complete)
            .map(Self)
            .map_err(error)
    }
    #[getter]
    fn program(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        packets::write(py, self.0.program())
    }
    #[getter]
    fn relation(&self) -> &str {
        self.0.relation()
    }
    #[getter]
    fn description(&self) -> &str {
        self.0.description()
    }
    #[getter]
    fn complete(&self) -> bool {
        self.0.complete()
    }
}
#[pyclass(name = "EvidenceInteraction", frozen)]
pub(super) struct EvidenceInteraction {
    state: Mutex<Tools>,
    pub(super) trajectory: Option<Py<Trajectory>>,
}
impl EvidenceInteraction {
    fn lock(&self) -> PyResult<std::sync::MutexGuard<'_, Tools>> {
        self.state
            .lock()
            .map_err(|_| pyo3::exceptions::PyRuntimeError::new_err("interaction lock poisoned"))
    }
    pub(super) fn run(
        &self,
        py: Python<'_>,
        mode: &str,
        arguments: &Data,
        model_call: &str,
    ) -> PyResult<Data> {
        if let Some(ledger) = &self.trajectory {
            ledger.borrow(py).require_call(model_call)?;
        }
        let result = py.detach(|| {
            let mut state = self.lock()?;
            match mode {
                "check_branches" => state.check(arguments),
                "reuse_paths" => state.reuse(arguments),
                "extend_paths" => state.extend(arguments),
                _ => {
                    return Err(pyo3::exceptions::PyValueError::new_err(
                        "unknown evidence tool",
                    ));
                }
            }
            .map_err(error)
        })?;
        self.journal(py, &result, model_call)?;
        Ok(result.feedback)
    }
    fn journal(
        &self,
        py: Python<'_>,
        result: &crate::BranchEvaluation,
        model_call: &str,
    ) -> PyResult<()> {
        let Some(ledger) = &self.trajectory else {
            return Ok(());
        };
        let ledger = ledger.borrow(py);
        let mut events = result
            .receipts
            .iter()
            .map(|receipt| evidence_fields(receipt).map(|fields| ("evidence", fields)))
            .collect::<crate::Result<Vec<_>>>()
            .map_err(error)?;
        events.push((
            "checkpoint",
            BTreeMap::from([
                ("modelCall".into(), format!("call:{model_call}").into()),
                (
                    "branches".into(),
                    result.feedback.field("branches").map_err(error)?.clone(),
                ),
            ]),
        ));
        ledger.emit_batch(events)?;
        Ok(())
    }
    pub(super) fn dispatch_data(&self, py: Python<'_>, call: &Data, model_call: &str) -> Data {
        match self.dispatch_checked(py, call, model_call) {
            Ok(value) => value,
            Err(error) => Data::object([
                ("schema", "ascent.branch-feedback.v2".into()),
                ("status", "unknown".into()),
                ("reason", error.to_string().into()),
                ("taskCorrectnessCertified", false.into()),
            ]),
        }
    }
    fn dispatch_checked(&self, py: Python<'_>, call: &Data, model_call: &str) -> PyResult<Data> {
        let name = call.field("name").map_err(error)?.text().map_err(error)?;
        let empty = Data::from("{}");
        let arguments = call.get("arguments").unwrap_or(&empty);
        let arguments = match arguments {
            Data::Text(text) => crate::read_provider_arguments(text).map_err(error)?,
            Data::Map(_) => arguments.clone(),
            _ => {
                return Err(pyo3::exceptions::PyValueError::new_err(
                    "tool arguments must be native data or provider JSON text",
                ));
            }
        };
        let field = match name {
            "check_branches" => "branches",
            "reuse_paths" => "references",
            "extend_paths" => "paths",
            _ => {
                return Err(pyo3::exceptions::PyValueError::new_err(
                    "unknown evidence tool",
                ));
            }
        };
        if arguments.map().map_err(error)?.len() != 1 {
            return Err(pyo3::exceptions::PyValueError::new_err(
                "exact tool argument fields required",
            ));
        }
        self.run(py, name, arguments.field(field).map_err(error)?, model_call)
    }
}
fn evidence_fields(receipt: &Data) -> crate::Result<BTreeMap<String, Data>> {
    [
        "resultReference",
        "pathIdentity",
        "reusedComponents",
        "freshComponents",
        "retainedCompleted",
    ]
    .into_iter()
    .map(|key| receipt.field(key).map(|v| (key.into(), v.clone())))
    .collect()
}
#[pymethods]
impl EvidenceInteraction {
    #[new]
    #[pyo3(signature=(engine,sources,operations,*,trajectory=None,retain=true))]
    fn new(
        engine: &Engine,
        sources: &Bound<'_, PyAny>,
        operations: &Bound<'_, PyDict>,
        trajectory: Option<Py<Trajectory>>,
        retain: bool,
    ) -> PyResult<Self> {
        let operations = operations
            .iter()
            .map(|(key, value)| {
                let value = value.extract::<PyRef<'_, EvidenceOperation>>()?;
                Ok((key.extract::<String>()?, value.0.clone()))
            })
            .collect::<PyResult<BTreeMap<_, _>>>()?;
        let tools =
            Tools::new(&engine.0, packets::read(sources)?, operations, retain).map_err(error)?;
        if let Some(ledger) = &trajectory {
            let ledger = ledger.borrow(sources.py());
            if !ledger.engine.same_owner(&engine.0)
                || ledger.source_identity()? != tools.source_identity()
            {
                return Err(pyo3::exceptions::PyValueError::new_err(
                    "trajectory belongs to another engine or source",
                ));
            }
        }
        Ok(Self {
            state: Mutex::new(tools),
            trajectory,
        })
    }
    #[getter]
    fn tools(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        packets::write(py, &self.lock()?.tools())
    }
    #[getter]
    fn source_identity(&self) -> PyResult<String> {
        Ok(self.lock()?.source_identity())
    }
    #[pyo3(signature=(branches,*,model_call))]
    fn check(
        &self,
        py: Python<'_>,
        branches: &Bound<'_, PyAny>,
        model_call: &str,
    ) -> PyResult<Py<PyAny>> {
        packets::write(
            py,
            &self.run(py, "check_branches", &packets::read(branches)?, model_call)?,
        )
    }
    #[pyo3(signature=(references,*,model_call))]
    fn reuse(
        &self,
        py: Python<'_>,
        references: &Bound<'_, PyAny>,
        model_call: &str,
    ) -> PyResult<Py<PyAny>> {
        packets::write(
            py,
            &self.run(py, "reuse_paths", &packets::read(references)?, model_call)?,
        )
    }
    #[pyo3(signature=(paths,*,model_call))]
    fn extend(
        &self,
        py: Python<'_>,
        paths: &Bound<'_, PyAny>,
        model_call: &str,
    ) -> PyResult<Py<PyAny>> {
        packets::write(
            py,
            &self.run(py, "extend_paths", &packets::read(paths)?, model_call)?,
        )
    }
    #[pyo3(signature=(call,*,model_call))]
    fn dispatch(
        &self,
        py: Python<'_>,
        call: &Bound<'_, PyAny>,
        model_call: &str,
    ) -> PyResult<Py<PyAny>> {
        packets::write(
            py,
            &self.dispatch_data(py, &packets::read(call)?, model_call),
        )
    }
    fn replace(&self, py: Python<'_>, sources: &Bound<'_, PyAny>) -> PyResult<()> {
        let mut state = self.lock()?;
        state.replace(packets::read(sources)?).map_err(error)?;
        if let Some(ledger) = &self.trajectory {
            ledger.borrow(py).emit(
                "invalidate",
                None,
                BTreeMap::from([
                    ("nextSourceIdentity".into(), state.source_identity().into()),
                    ("reason".into(), "source-replaced".into()),
                ]),
            )?;
        }
        Ok(())
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
pub(super) fn compact_feedback(value: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
    packets::write(
        value.py(),
        &crate::compact_feedback(&packets::read(value)?).map_err(error)?,
    )
}
#[pyfunction]
pub(super) fn expand_feedback(value: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
    packets::write(
        value.py(),
        &crate::expand_feedback(&packets::read(value)?).map_err(error)?,
    )
}
