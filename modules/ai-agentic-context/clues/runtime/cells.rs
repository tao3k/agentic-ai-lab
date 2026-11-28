//! Inert row conversion and rendering shared by clue owners.
use crate::{Data, Result, Row, Value};
pub(super) fn invalid(message: &str) -> crate::Error {
    crate::invalid_data(message)
}

pub(super) fn rows(value: &Data) -> Result<Vec<Row>> {
    value
        .list()?
        .iter()
        .map(|row| {
            row.list()?
                .iter()
                .map(|cell| Ok(Value::from(cell.text()?)))
                .collect::<Result<Vec<_>>>()
                .map(Row::from)
        })
        .collect()
}

pub(super) fn data_rows(rows: &[Row]) -> Result<Data> {
    Ok(Data::List(
        rows.iter()
            .map(|row| {
                Ok(Data::List(
                    row.iter()
                        .map(|cell| match cell {
                            Value::Text(text) => Ok(Data::from(text.as_ref())),
                            _ => Err(invalid("Clue relations require text cells")),
                        })
                        .collect::<Result<_>>()?,
                ))
            })
            .collect::<Result<_>>()?,
    ))
}

/// Inert Scheme data rendering for Agent-facing exchange; no executable forms.
#[must_use]
pub fn clue_sexpr(value: &Data) -> String {
    match value {
        Data::Null => "()".into(),
        Data::Bool(v) => if *v { "#t" } else { "#f" }.into(),
        Data::Integer(v) => v.to_string(),
        Data::Real(v) => f64::from_bits(*v).to_string(),
        Data::Text(v) => format!(
            "\"{}\"",
            v.replace('\\', "\\\\")
                .replace('"', "\\\"")
                .replace('\n', "\\n")
                .replace('\r', "\\r")
                .replace('\t', "\\t")
        ),
        Data::List(v) => format!(
            "({})",
            v.iter().map(clue_sexpr).collect::<Vec<_>>().join(" ")
        ),
        Data::Map(v) => format!(
            "({})",
            v.iter()
                .map(|(k, v)| format!("({} {})", clue_sexpr(&k.as_str().into()), clue_sexpr(v)))
                .collect::<Vec<_>>()
                .join(" ")
        ),
    }
}
pub(super) fn text(row: &Data, n: usize) -> Result<&str> {
    row.list()?
        .get(n)
        .ok_or_else(|| invalid("slice item arity"))?
        .text()
}
