//! ASCENT packet shape over the shared VM-independent upstream value transport.
use crate::Data;
use gerbil_scheme_python::{OwnedValue, ValueLimits};
use pyo3::{Bound, Py, PyAny, PyResult, Python, exceptions::PyValueError};

pub(crate) fn read(value: &Bound<'_, PyAny>) -> PyResult<Data> {
    into_data(OwnedValue::from_python(value, ValueLimits::default())?)
}
pub(crate) fn write(py: Python<'_>, value: &Data) -> PyResult<Py<PyAny>> {
    owned(value).to_python(py)
}
fn into_data(value: OwnedValue) -> PyResult<Data> {
    Ok(match value {
        OwnedValue::Null => Data::Null,
        OwnedValue::Boolean(v) => Data::Bool(v),
        OwnedValue::Integer(v) => Data::Integer(v),
        OwnedValue::Real(v) if v.is_finite() => Data::Real(v.to_bits()),
        OwnedValue::Text(v) => Data::Text(v),
        OwnedValue::List(values) => {
            Data::List(values.into_iter().map(into_data).collect::<PyResult<_>>()?)
        }
        OwnedValue::Map(values) => Data::Map(
            values
                .into_iter()
                .map(|(k, v)| Ok((k, into_data(v)?)))
                .collect::<PyResult<_>>()?,
        ),
        _ => {
            return Err(PyValueError::new_err(
                "ASCENT packets require finite data; bytes need an explicit value channel",
            ));
        }
    })
}
fn owned(value: &Data) -> OwnedValue {
    match value {
        Data::Null => OwnedValue::Null,
        Data::Bool(v) => OwnedValue::Boolean(*v),
        Data::Integer(v) => OwnedValue::Integer(v.clone()),
        Data::Real(v) => OwnedValue::Real(f64::from_bits(*v)),
        Data::Text(v) => OwnedValue::Text(v.clone()),
        Data::List(values) => OwnedValue::List(values.iter().map(owned).collect()),
        Data::Map(values) => {
            OwnedValue::Map(values.iter().map(|(k, v)| (k.clone(), owned(v))).collect())
        }
    }
}
