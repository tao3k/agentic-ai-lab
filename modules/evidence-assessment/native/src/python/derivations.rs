//! Thin generated bindings around Rust-owned evidence and continuation semantics.
use super::{
    bindings::Engine, packets, sources::FactLimits, trajectory::Trajectory,
    types::error as source_error,
};
use crate::{Data, EvidenceChain as Chain, EvidenceStore as Store, evidence_graph as graph};
use pyo3::types::PyAnyMethods;
use pyo3::{Bound, Py, PyAny, PyRef, PyResult, Python, pyclass, pyfunction, pymethods};
use std::{collections::BTreeMap, sync::Mutex};
fn lock<T>(value: &Mutex<T>) -> PyResult<std::sync::MutexGuard<'_, T>> {
    value
        .lock()
        .map_err(|_| pyo3::exceptions::PyRuntimeError::new_err("evidence owner lock poisoned"))
}
#[pyclass(name = "EvidenceStore", frozen)]
pub(super) struct EvidenceStore(Mutex<Store>);
#[pymethods]
impl EvidenceStore {
    #[new]
    #[pyo3(signature=(engine,sources,*,limits=None))]
    fn new(
        engine: &Engine,
        sources: &Bound<'_, PyAny>,
        limits: Option<PyRef<'_, FactLimits>>,
    ) -> PyResult<Self> {
        let value = packets::read(sources)?;
        Store::new(&engine.0, value, limits.map(|l| l.0).unwrap_or_default())
            .map(|s| Self(Mutex::new(s)))
            .map_err(source_error)
    }
    #[getter]
    fn source_identity(&self) -> PyResult<String> {
        Ok(lock(&self.0)?.source_identity())
    }
    #[getter]
    fn materialized(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        packets::write(py, &Data::Map(lock(&self.0)?.materialized().clone()))
    }
    fn scan(&self, py: Python<'_>, names: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
        let names: Vec<String> = names.extract()?;
        let result = lock(&self.0)?.scan(&names).map_err(source_error)?;
        packets::write(py, &result)
    }
    fn query(&self, py: Python<'_>, program: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
        let value = packets::read(program)?;
        let result = py.detach(|| lock(&self.0)?.query(value).map_err(source_error))?;
        packets::write(py, &result)
    }
    fn replace(&self, sources: &Bound<'_, PyAny>) -> PyResult<()> {
        lock(&self.0)?
            .replace(packets::read(sources)?)
            .map_err(source_error)
    }
    fn close(&self) -> PyResult<()> {
        lock(&self.0)?.close();
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
#[pyclass(name = "EvidenceChain", frozen)]
pub(super) struct EvidenceChain {
    state: Mutex<Chain>,
    trajectory: Option<Py<Trajectory>>,
}
impl EvidenceChain {
    fn evidence(&self, py: Python<'_>, feedback: &Data) -> PyResult<()> {
        if let Some(t) = &self.trajectory {
            let t = t.borrow(py);
            let fields = [
                "resultReference",
                "pathIdentity",
                "reusedComponents",
                "freshComponents",
                "retainedCompleted",
            ]
            .into_iter()
            .map(|k| feedback.field(k).map(|v| (k.into(), v.clone())))
            .collect::<crate::Result<_>>()
            .map_err(source_error)?;
            t.emit("evidence", None, fields)?;
        }
        Ok(())
    }
    fn event(&self, py: Python<'_>, kind: &str, fields: BTreeMap<String, Data>) -> PyResult<()> {
        if let Some(t) = &self.trajectory {
            t.borrow(py).emit(kind, None, fields)?;
        }
        Ok(())
    }
}
#[pymethods]
impl EvidenceChain {
    #[new]
    #[pyo3(signature=(engine,sources,retain=true,*,limits=None,trajectory=None))]
    fn new(
        engine: &Engine,
        sources: &Bound<'_, PyAny>,
        retain: bool,
        limits: Option<PyRef<'_, FactLimits>>,
        trajectory: Option<Py<Trajectory>>,
    ) -> PyResult<Self> {
        let chain = Chain::new(
            &engine.0,
            packets::read(sources)?,
            retain,
            limits.map(|l| l.0).unwrap_or_default(),
        )
        .map_err(source_error)?;
        if let Some(t) = &trajectory {
            let t = t.borrow(sources.py());
            if !t.engine.same_owner(&engine.0) || t.source_identity()? != chain.source_identity() {
                return Err(pyo3::exceptions::PyValueError::new_err(
                    "trajectory must belong to this engine and source identity",
                ));
            }
        }
        Ok(Self {
            state: Mutex::new(chain),
            trajectory,
        })
    }
    #[getter]
    fn source_identity(&self) -> PyResult<String> {
        Ok(lock(&self.state)?.source_identity())
    }
    #[getter]
    fn sources(&self, py: Python<'_>) -> PyResult<Py<PyAny>> {
        packets::write(py, lock(&self.state)?.sources())
    }
    fn scan(&self, py: Python<'_>, names: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
        packets::write(
            py,
            &lock(&self.state)?
                .scan(&names.extract::<Vec<String>>()?)
                .map_err(source_error)?,
        )
    }
    fn query(&self, py: Python<'_>, program: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
        let value = packets::read(program)?;
        let result = py.detach(|| lock(&self.state)?.query(&value).map_err(source_error))?;
        self.evidence(py, &result)?;
        packets::write(py, &result)
    }
    fn answer(&self, py: Python<'_>, reference: &str, relation: &str) -> PyResult<Py<PyAny>> {
        let result = lock(&self.state)?
            .answer(reference, relation)
            .map_err(source_error)?;
        self.event(
            py,
            "direct-answer",
            BTreeMap::from([("resultReference".into(), reference.into())]),
        )?;
        packets::write(py, &result)
    }
    fn intermediates(
        &self,
        py: Python<'_>,
        reference: &str,
        names: &Bound<'_, PyAny>,
    ) -> PyResult<Py<PyAny>> {
        packets::write(
            py,
            &lock(&self.state)?
                .intermediates(reference, &names.extract::<Vec<String>>()?)
                .map_err(source_error)?,
        )
    }
    fn replace(&self, py: Python<'_>, sources: &Bound<'_, PyAny>) -> PyResult<()> {
        let mut state = lock(&self.state)?;
        state
            .replace(packets::read(sources)?)
            .map_err(source_error)?;
        self.event(
            py,
            "invalidate",
            BTreeMap::from([
                ("nextSourceIdentity".into(), state.source_identity().into()),
                ("reason".into(), "source-replaced".into()),
            ]),
        )
    }
    #[pyo3(signature=(reference,program,contract,*,interpretation=None))]
    fn consume(
        &self,
        py: Python<'_>,
        reference: &str,
        program: &Bound<'_, PyAny>,
        contract: &Bound<'_, PyAny>,
        interpretation: Option<&Bound<'_, PyAny>>,
    ) -> PyResult<Py<PyAny>> {
        let program = packets::read(program)?;
        let contract = packets::read(contract)?;
        let interpretation = interpretation
            .map(packets::read)
            .transpose()?
            .unwrap_or(Data::Null);
        let result = py.detach(|| {
            lock(&self.state)?
                .consume(reference, &program, &contract, interpretation)
                .map_err(source_error)
        })?;
        if result
            .field("accepted")
            .map_err(source_error)?
            .boolean()
            .map_err(source_error)?
        {
            self.evidence(py, &result)?;
            let fields = [
                "consumedReference",
                "resultReference",
                "intentIdentity",
                "contractIdentity",
                "interpretation",
            ]
            .into_iter()
            .map(|k| result.field(k).map(|v| (k.into(), v.clone())))
            .collect::<crate::Result<_>>()
            .map_err(source_error)?;
            self.event(py, "consumption", fields)?;
        }
        packets::write(py, &result)
    }
    fn close(&self) -> PyResult<()> {
        lock(&self.state)?.close();
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
pub(super) fn identity(value: &Bound<'_, PyAny>) -> PyResult<String> {
    Ok(packets::read(value)?.digest())
}
#[pyfunction]
pub(super) fn components(program: &Bound<'_, PyAny>) -> PyResult<Vec<Vec<String>>> {
    let value = packets::read(program)?;
    program
        .py()
        .detach(|| graph::components(&value).map_err(source_error))
}
#[pyfunction]
pub(super) fn evidence_graph(program: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
    let value = packets::read(program)?;
    let graph = program
        .py()
        .detach(|| graph::evidence_graph(&value).map_err(source_error))?;
    packets::write(program.py(), &graph)
}
#[pyfunction]
pub(super) fn canonical_rule(rule: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
    packets::write(
        rule.py(),
        &graph::canonical_rule(&packets::read(rule)?).map_err(source_error)?,
    )
}
#[pyfunction]
pub(super) fn normalize_contract(contract: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
    packets::write(
        contract.py(),
        &graph::normalize_contract(&packets::read(contract)?).map_err(source_error)?,
    )
}
#[pyfunction]
pub(super) fn check_continuation(
    program: &Bound<'_, PyAny>,
    contract: &Bound<'_, PyAny>,
) -> PyResult<Py<PyAny>> {
    packets::write(
        program.py(),
        &graph::check_continuation(&packets::read(program)?, &packets::read(contract)?)
            .map_err(source_error)?,
    )
}
#[pyfunction]
pub(super) fn slice_program(
    program: &Bound<'_, PyAny>,
    facts: &Bound<'_, PyAny>,
    queries: &Bound<'_, PyAny>,
) -> PyResult<Py<PyAny>> {
    packets::write(
        program.py(),
        &graph::slice_program(
            &packets::read(program)?,
            &packets::read(facts)?,
            &packets::read(queries)?,
        )
        .map_err(source_error)?,
    )
}

#[pyfunction]
pub(super) fn compact_observation(value: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
    packets::write(
        value.py(),
        &crate::compact_observation(&packets::read(value)?).map_err(source_error)?,
    )
}
#[pyfunction]
pub(super) fn expand_observation(value: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
    packets::write(
        value.py(),
        &crate::expand_observation(&packets::read(value)?).map_err(source_error)?,
    )
}
#[pyfunction]
pub(super) fn domain_check(kind: &str, observations: &Bound<'_, PyAny>) -> PyResult<Py<PyAny>> {
    packets::write(
        observations.py(),
        &crate::domain_check(kind, &packets::read(observations)?).map_err(source_error)?,
    )
}
#[pyfunction]
pub(super) fn domain_contract(kind: &str) -> PyResult<&'static str> {
    crate::domain_contract(kind).map_err(source_error)
}

#[pyo3::pyfunction]
pub(super) fn rows_equal(left: &Bound<'_, PyAny>, right: &Bound<'_, PyAny>) -> PyResult<bool> {
    crate::rows_equal(&packets::read(left)?, &packets::read(right)?).map_err(source_error)
}
