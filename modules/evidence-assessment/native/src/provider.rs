//! Optional external provider protocol; engine graphs and rows never use this JSON path.
use crate::{Data, Result, invalid_data as invalid};
use std::collections::BTreeMap;
/// Decode only externally supplied tool argument text into owned native values.
/// # Errors
/// Rejects oversized, malformed, overly nested and nonfinite provider data.
pub fn read_provider_arguments(source: &str) -> Result<Data> {
    if source.len() > 1_048_576 {
        return Err(invalid("provider argument size bound"));
    }
    let value: serde_json::Value =
        serde_json::from_str(source).map_err(|_| invalid("invalid provider argument JSON"))?;
    convert(value, 0, &mut 0)
}
fn convert(value: serde_json::Value, depth: usize, nodes: &mut usize) -> Result<Data> {
    if depth > 128 || *nodes >= 1_000_000 {
        return Err(invalid("provider structure bound"));
    }
    *nodes += 1;
    match value {
        serde_json::Value::Null => Ok(Data::Null),
        serde_json::Value::Bool(v) => Ok(Data::Bool(v)),
        serde_json::Value::String(v) => Ok(Data::Text(v)),
        serde_json::Value::Number(v) => number(&v),
        serde_json::Value::Array(v) => v
            .into_iter()
            .map(|v| convert(v, depth + 1, nodes))
            .collect::<Result<Vec<_>>>()
            .map(Data::List),
        serde_json::Value::Object(v) => v
            .into_iter()
            .map(|(k, v)| convert(v, depth + 1, nodes).map(|v| (k, v)))
            .collect::<Result<BTreeMap<_, _>>>()
            .map(Data::Map),
    }
}
fn number(value: &serde_json::Number) -> Result<Data> {
    let text = value.to_string();
    if !text.contains(['.', 'e', 'E']) {
        return text
            .parse()
            .map(Data::Integer)
            .map_err(|_| invalid("provider exact integer required"));
    }
    let real = value
        .as_f64()
        .filter(|v| v.is_finite())
        .ok_or_else(|| invalid("finite provider number required"))?;
    Ok(Data::Real(real.to_bits()))
}
