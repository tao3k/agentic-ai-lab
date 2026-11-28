//! Rust-generated trajectory bindings; all admission and counters live in the Rust library.
use super::{bindings::Engine, packets, types::source_error};
use crate::{Data, Trajectory as Ledger};
use pyo3::{
    Bound, PyAny, PyRef, PyResult, Python, pyclass, pymethods,
    types::{PyAnyMethods, PyDict},
};
use std::{collections::BTreeMap, sync::Mutex};
struct State {
    ledger: Ledger,
    sequence: usize,
}
#[pyclass(name = "Trajectory", frozen)]
pub(super) struct Trajectory {
    pub(super) engine: crate::Engine,
    state: Mutex<State>,
}
impl Trajectory {
    fn lock(&self) -> PyResult<std::sync::MutexGuard<'_, State>> {
        self.state
            .lock()
            .map_err(|_| pyo3::exceptions::PyRuntimeError::new_err("trajectory lock poisoned"))
    }
    pub(super) fn require_call(&self, call: &str) -> PyResult<()> {
        self.lock()?
            .ledger
            .require_model_call(call)
            .map_err(source_error)
    }
    pub(super) fn emit_batch(&self, events: Vec<(&str, BTreeMap<String, Data>)>) -> PyResult<()> {
        let mut state = self.lock()?;
        let mut sequence = state.sequence;
        let source = state.ledger.source_identity().to_string();
        let supplied = events
            .into_iter()
            .map(|(kind, mut fields)| {
                sequence = sequence.checked_add(1).ok_or_else(|| {
                    pyo3::exceptions::PyValueError::new_err("event sequence exhausted")
                })?;
                fields.insert("id".into(), format!("event:{sequence}").into());
                fields.insert("kind".into(), kind.into());
                fields.insert("sourceIdentity".into(), source.clone().into());
                Ok(Data::Map(fields))
            })
            .collect::<PyResult<Vec<_>>>()?;
        state.ledger.append_batch(&supplied).map_err(source_error)?;
        state.sequence = sequence;
        Ok(())
    }
    pub(super) fn emit(
        &self,
        kind: &str,
        event_id: Option<String>,
        mut fields: BTreeMap<String, Data>,
    ) -> PyResult<(String, Data)> {
        let mut state = self.lock()?;
        state.sequence += 1;
        let id = event_id.unwrap_or_else(|| format!("event:{}", state.sequence));
        fields.insert("id".into(), id.clone().into());
        fields.insert("kind".into(), kind.into());
        fields.insert(
            "sourceIdentity".into(),
            state.ledger.source_identity().into(),
        );
        state
            .ledger
            .append(Data::Map(fields))
            .map(|result| (id, result))
            .map_err(source_error)
    }
}
#[pymethods]
impl Trajectory {
    #[new]
    fn new(engine: &Engine, task: &str, source_identity: &str) -> PyResult<Self> {
        let execution: &crate::Runtime = &engine.0;
        Ledger::new(execution, task, source_identity)
            .map(|ledger| Self {
                engine: execution.clone(),
                state: Mutex::new(State {
                    ledger,
                    sequence: 0,
                }),
            })
            .map_err(source_error)
    }
    #[getter]
    fn handle(&self) -> PyResult<u64> {
        Ok(self.lock()?.ledger.handle())
    }
    #[getter]
    pub(super) fn source_identity(&self) -> PyResult<String> {
        Ok(self.lock()?.ledger.source_identity().into())
    }
    #[getter]
    fn closed(&self, py: Python<'_>) -> PyResult<pyo3::Py<PyAny>> {
        let state = self.lock()?;
        if state.ledger.is_closed() {
            packets::write(py, &state.ledger.snapshot().map_err(source_error)?)
        } else {
            Ok(py.None())
        }
    }
    #[pyo3(signature=(kind,*,event_id=None,**fields))]
    fn append(
        &self,
        py: Python<'_>,
        kind: &str,
        event_id: Option<String>,
        fields: Option<&Bound<'_, PyDict>>,
    ) -> PyResult<(String, pyo3::Py<PyAny>)> {
        let fields = fields
            .map(|v| packets::read(v.as_any()))
            .transpose()?
            .unwrap_or_else(|| Data::Map(BTreeMap::new()));
        let (id, result) =
            self.emit(kind, event_id, fields.map().map_err(source_error)?.clone())?;
        Ok((id, packets::write(py, &result)?))
    }
    #[pyo3(signature=(call_id,round,usage=None,repair_of=None))]
    pub(super) fn model_call(
        &self,
        py: Python<'_>,
        call_id: &str,
        round: &Bound<'_, PyAny>,
        usage: Option<&Bound<'_, PyAny>>,
        repair_of: Option<String>,
    ) -> PyResult<pyo3::Py<PyAny>> {
        let mut fields = BTreeMap::from([("round".into(), packets::read(round)?)]);
        let mut normalized = BTreeMap::new();
        if let Some(usage) = usage.filter(|u| !u.is_none()) {
            let usage = packets::read(usage)?;
            for (external, internal) in [
                ("input_tokens", "inputTokens"),
                ("output_tokens", "outputTokens"),
            ] {
                if let Some(value) = usage.get(external).filter(|v| !matches!(v, Data::Null)) {
                    normalized.insert(internal.into(), value.clone());
                }
            }
            if let Some(thinking) = usage
                .get("output_tokens_details")
                .and_then(|v| v.get("reasoning_tokens"))
                .filter(|v| !matches!(v, Data::Null))
            {
                normalized.insert("thinkingTokens".into(), thinking.clone());
            }
        }
        fields.insert("usage".into(), Data::Map(normalized));
        if let Some(repair) = repair_of {
            fields.insert("repairOf".into(), repair.into());
        }
        let (_, result) = self.emit("model-call", Some(format!("call:{call_id}")), fields)?;
        packets::write(py, &result)
    }
    pub(super) fn evidence(
        &self,
        py: Python<'_>,
        feedback: &Bound<'_, PyAny>,
    ) -> PyResult<pyo3::Py<PyAny>> {
        let feedback = packets::read(feedback)?;
        if feedback
            .field("sourceIdentity")
            .map_err(source_error)?
            .text()
            .map_err(source_error)?
            != self.source_identity()?
        {
            return Err(pyo3::exceptions::PyValueError::new_err(
                "evidence belongs to another source",
            ));
        }
        let keys = [
            "resultReference",
            "pathIdentity",
            "reusedComponents",
            "freshComponents",
            "retainedCompleted",
        ];
        let fields = keys
            .into_iter()
            .map(|k| feedback.field(k).map(|v| (k.into(), v.clone())))
            .collect::<crate::Result<_>>()
            .map_err(source_error)?;
        let (_, result) = self.emit("evidence", None, fields)?;
        packets::write(py, &result)
    }
    fn direct_answer(&self, py: Python<'_>, reference: &str) -> PyResult<pyo3::Py<PyAny>> {
        let (_, result) = self.emit(
            "direct-answer",
            None,
            BTreeMap::from([("resultReference".into(), reference.into())]),
        )?;
        packets::write(py, &result)
    }
    fn checkpoint(
        &self,
        py: Python<'_>,
        model_call: &str,
        branches: &Bound<'_, PyAny>,
    ) -> PyResult<pyo3::Py<PyAny>> {
        let (_, result) = self.emit(
            "checkpoint",
            None,
            BTreeMap::from([
                ("modelCall".into(), format!("call:{model_call}").into()),
                ("branches".into(), packets::read(branches)?),
            ]),
        )?;
        packets::write(py, &result)
    }
    #[pyo3(signature=(correct,verifier,*,round=None,candidate=None,scope="task",consumption_reference=None))]
    fn verify(
        &self,
        correct: &Bound<'_, PyAny>,
        verifier: &str,
        round: Option<&Bound<'_, PyAny>>,
        candidate: Option<&Bound<'_, PyAny>>,
        scope: &str,
        consumption_reference: Option<String>,
    ) -> PyResult<pyo3::Py<PyAny>> {
        let py = correct.py();
        let correct = packets::read(correct)?;
        correct.boolean().map_err(source_error)?;
        let mut fields = BTreeMap::from([
            ("correct".into(), correct),
            ("verifier".into(), verifier.into()),
            (
                "candidate".into(),
                candidate
                    .map(packets::read)
                    .transpose()?
                    .unwrap_or(Data::Null),
            ),
            ("scope".into(), scope.into()),
        ]);
        if let Some(round) = round {
            fields.insert("round".into(), packets::read(round)?);
        }
        if let Some(reference) = consumption_reference {
            fields.insert("consumptionReference".into(), reference.into());
        }
        let (_, result) = self.emit("verification", None, fields)?;
        packets::write(py, &result)
    }
    #[pyo3(signature=(next_source_identity,reason="source-replaced"))]
    fn invalidate(
        &self,
        py: Python<'_>,
        next_source_identity: &str,
        reason: &str,
    ) -> PyResult<pyo3::Py<PyAny>> {
        let (_, result) = self.emit(
            "invalidate",
            None,
            BTreeMap::from([
                ("nextSourceIdentity".into(), next_source_identity.into()),
                ("reason".into(), reason.into()),
            ]),
        )?;
        packets::write(py, &result)
    }
    #[pyo3(signature=(prior_reference,reference,intent_identity,contract_identity,*,interpretation=None))]
    fn consume(
        &self,
        py: Python<'_>,
        prior_reference: &str,
        reference: &str,
        intent_identity: &str,
        contract_identity: &str,
        interpretation: Option<&Bound<'_, PyAny>>,
    ) -> PyResult<pyo3::Py<PyAny>> {
        let mut fields = BTreeMap::from([
            ("consumedReference".into(), prior_reference.into()),
            ("resultReference".into(), reference.into()),
            ("intentIdentity".into(), intent_identity.into()),
            ("contractIdentity".into(), contract_identity.into()),
        ]);
        if let Some(value) = interpretation {
            fields.insert("interpretation".into(), packets::read(value)?);
        }
        let (_, result) = self.emit("consumption", None, fields)?;
        packets::write(py, &result)
    }
    fn snapshot(&self, py: Python<'_>) -> PyResult<pyo3::Py<PyAny>> {
        packets::write(py, &self.lock()?.ledger.snapshot().map_err(source_error)?)
    }
    fn explore(&self, py: Python<'_>, candidate: &Bound<'_, PyAny>) -> PyResult<pyo3::Py<PyAny>> {
        let candidate = packets::read(candidate)?;
        let result = self
            .lock()?
            .ledger
            .explore(&candidate)
            .map_err(source_error)?;
        packets::write(py, &result)
    }
    fn context(&self, py: Python<'_>) -> PyResult<pyo3::Py<PyAny>> {
        packets::write(py, &self.lock()?.ledger.context().map_err(source_error)?)
    }
    #[pyo3(signature=(observed=None))]
    fn brief(
        &self,
        py: Python<'_>,
        observed: Option<&Bound<'_, PyAny>>,
    ) -> PyResult<pyo3::Py<PyAny>> {
        let observed = observed.map(packets::read).transpose()?;
        let packet = self
            .lock()?
            .ledger
            .brief(observed.as_ref())
            .map_err(source_error)?;
        packets::write(py, &packet)
    }
    #[pyo3(signature=(candidate,observed=None))]
    fn focus(
        &self,
        py: Python<'_>,
        candidate: &Bound<'_, PyAny>,
        observed: Option<&Bound<'_, PyAny>>,
    ) -> PyResult<pyo3::Py<PyAny>> {
        let candidate = packets::read(candidate)?;
        let observed = observed.map(packets::read).transpose()?;
        let packet = self
            .lock()?
            .ledger
            .focus(&candidate, observed.as_ref())
            .map_err(source_error)?;
        packets::write(py, &packet)
    }
    fn exact_prefix(
        &self,
        py: Python<'_>,
        through: usize,
        prefix_identity: &str,
    ) -> PyResult<pyo3::Py<PyAny>> {
        let packet = self
            .lock()?
            .ledger
            .exact_prefix(through, prefix_identity)
            .map_err(source_error)?;
        packets::write(py, &packet)
    }
    fn exploration_current(&self, packet: &Bound<'_, PyAny>) -> PyResult<bool> {
        self.lock()?
            .ledger
            .exploration_current(&packets::read(packet)?)
            .map_err(source_error)
    }
    #[pyo3(signature=(reason="complete"))]
    fn close(&self, py: Python<'_>, reason: &str) -> PyResult<pyo3::Py<PyAny>> {
        packets::write(
            py,
            &self.lock()?.ledger.close(reason).map_err(source_error)?,
        )
    }
    fn __enter__(slf: PyRef<'_, Self>) -> PyRef<'_, Self> {
        slf
    }
    fn __exit__(
        &self,
        py: Python<'_>,
        exception: &Bound<'_, PyAny>,
        _value: &Bound<'_, PyAny>,
        _traceback: &Bound<'_, PyAny>,
    ) -> PyResult<()> {
        self.close(
            py,
            if exception.is_none() {
                "complete"
            } else {
                "exception"
            },
        )
        .map(|_| ())
    }
}
