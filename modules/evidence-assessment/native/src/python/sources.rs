use gerbil_scheme_python::ValueLimits;
use pyo3::{Bound, PyAny, PyResult, Python, pyclass, pymethods, types::PyDict};
#[pyclass(name = "FactLimits", frozen)]
#[derive(Clone, Copy)]
pub(super) struct FactLimits(pub(super) gerbil_ascent::FactLimits);
#[pymethods]
impl FactLimits {
    #[getter]
    fn input(&self) -> Option<usize> {
        self.0.input
    }
    #[getter]
    fn derived(&self) -> Option<usize> {
        self.0.derived
    }
    #[getter]
    fn output(&self) -> Option<usize> {
        self.0.output
    }
    #[new]
    #[pyo3(signature=(input=None,derived=None,output=None))]
    fn new(
        input: Option<&Bound<'_, PyAny>>,
        derived: Option<&Bound<'_, PyAny>>,
        output: Option<&Bound<'_, PyAny>>,
    ) -> PyResult<Self> {
        Ok(Self(gerbil_ascent::FactLimits {
            input: ceiling(input)?,
            derived: ceiling(derived)?,
            output: ceiling(output)?,
        }))
    }
    fn wire<'py>(&self, py: Python<'py>) -> PyResult<Bound<'py, PyDict>> {
        use pyo3::types::PyDictMethods;
        let out = PyDict::new(py);
        for (name, value) in [
            ("input", self.0.input),
            ("derived", self.0.derived),
            ("output", self.0.output),
        ] {
            if let Some(value) = value {
                out.set_item(name, value)?;
            }
        }
        Ok(out)
    }
}
pub(super) fn ceiling(value: Option<&Bound<'_, PyAny>>) -> PyResult<Option<usize>> {
    value
        .map(|v| {
            gerbil_scheme_python::OwnedValue::from_python(v, ValueLimits::default())?
                .positive_usize()
        })
        .transpose()
}
