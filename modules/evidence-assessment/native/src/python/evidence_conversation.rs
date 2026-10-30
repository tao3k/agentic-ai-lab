//! Pair native evidence tools with opaque provider history, without evaluating provider code.
use super::{
    conversation::ResponseHistory, interaction::EvidenceInteraction, packets, types::error,
};
use crate::{Data, ResponseHistory as History, ToolCallId};
use pyo3::{Bound, Py, PyAny, PyRef, PyResult, Python, pyclass, pymethods};
use std::sync::Mutex;

#[pyclass(name = "EvidenceConversation", frozen)]
pub(super) struct EvidenceConversation {
    history: Py<ResponseHistory>,
    interaction: Py<EvidenceInteraction>,
}
#[pymethods]
impl EvidenceConversation {
    #[new]
    fn new(question: &Bound<'_, PyAny>, interaction: Py<EvidenceInteraction>) -> PyResult<Self> {
        Ok(Self {
            history: Py::new(
                question.py(),
                ResponseHistory(Mutex::new(History::new(packets::read(question)?))),
            )?,
            interaction,
        })
    }
    #[getter]
    fn history(&self, py: Python<'_>) -> Py<ResponseHistory> {
        self.history.clone_ref(py)
    }
    fn restore_history(&self, py: Python<'_>, input: &Bound<'_, PyAny>) -> PyResult<()> {
        let restored = History::restore(&packets::read(input)?).map_err(error)?;
        let owner = self.history.borrow(py);
        let mut retained = owner.lock()?;
        if retained.snapshot().list().map_err(error)?.first()
            != restored.snapshot().list().map_err(error)?.first()
        {
            return Err(pyo3::exceptions::PyValueError::new_err(
                "provider history question changed",
            ));
        }
        *retained = restored;
        Ok(())
    }
    #[pyo3(signature=(response,*,call_id,round))]
    fn accept(
        &self,
        py: Python<'_>,
        response: &Bound<'_, PyAny>,
        call_id: &str,
        round: &Bound<'_, PyAny>,
    ) -> PyResult<Py<PyAny>> {
        let interaction = self.interaction.borrow(py);
        let data = packets::read(response)?;
        if let Some(ledger) = &interaction.trajectory {
            let usage = data
                .get("usage")
                .map(|v| packets::write(py, v))
                .transpose()?;
            ledger.borrow(py).model_call(
                py,
                call_id,
                round,
                usage.as_ref().map(|v| v.bind(py)),
                None,
            )?;
        }
        if data.get("status") != Some(&Data::from("completed")) {
            return Err(pyo3::exceptions::PyValueError::new_err(
                "provider response is incomplete; usage was retained",
            ));
        }
        let history = self.history.borrow(py);
        let calls = history.lock()?.append_response(&data).map_err(error)?;
        let output = calls
            .list()
            .map_err(error)?
            .iter()
            .map(|call| execute(py, &history, &interaction, call, call_id))
            .collect::<PyResult<Vec<_>>>()?;
        packets::write(py, &Data::List(output))
    }
}
fn execute(
    py: Python<'_>,
    history: &PyRef<'_, ResponseHistory>,
    interaction: &PyRef<'_, EvidenceInteraction>,
    call: &Data,
    model_call: &str,
) -> PyResult<Data> {
    let feedback = interaction.dispatch_data(py, call, model_call);
    let exposed = crate::compact_feedback(&feedback).map_err(error)?;
    let id = call.field("call_id").map_err(error)?;
    let identity = ToolCallId::new(id.text().map_err(error)?).map_err(error)?;
    history
        .lock()?
        .append_result(&identity, &exposed)
        .map_err(error)?;
    Ok(Data::object([
        ("callId", id.clone()),
        ("toolName", call.get("name").cloned().unwrap_or(Data::Null)),
        (
            "arguments",
            call.get("arguments").cloned().unwrap_or(Data::Null),
        ),
        ("feedback", feedback),
        ("exposedFeedback", exposed),
    ]))
}
