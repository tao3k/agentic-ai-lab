//! Bounded inert request decoding; no Scheme evaluation or query compilation.
use super::invalid;
use crate::{Data, Result};
use gerbil_ascent::syntax::{Datum, read_datum};
use std::collections::BTreeMap;

fn value(datum: Datum) -> Result<Data> {
    match datum {
        Datum::Text(text) => Ok(Data::Text(text)),
        Datum::Atom(text) => match text.as_str() {
            "#t" => Ok(Data::Bool(true)),
            "#f" => Ok(Data::Bool(false)),
            _ => text
                .parse()
                .map(Data::Integer)
                .map_err(|_| invalid("inert Clue request value required")),
        },
        Datum::List(items) => items
            .into_iter()
            .map(value)
            .collect::<Result<Vec<_>>>()
            .map(Data::List),
        Datum::Vector(_) => Err(invalid("Clue request lists required")),
    }
}
fn binding(row: &Data) -> Result<()> {
    let pair = row.list()?;
    if pair.len() != 2 {
        return Err(invalid("binding name/value pair required"));
    }
    pair[0].text()?;
    pair[1].text()?;
    Ok(())
}
fn validate(key: &str, data: &Data) -> Result<()> {
    match key {
        "bindings" => data.list()?.iter().try_for_each(binding),
        "questions" | "expand" => data
            .list()?
            .iter()
            .try_for_each(|item| item.text().map(|_| ())),
        "checkpoint" | "selector" | "constructor" => data.text().map(|_| ()),
        "displayBytes" if matches!(data, Data::Integer(n) if n > &0.into()) => Ok(()),
        "displayBytes" => Err(invalid("positive displayBytes required")),
        _ => Err(invalid("unknown Clue request field")),
    }
}
fn field(datum: Datum) -> Result<(String, Data)> {
    let Datum::List(pair) = datum else {
        return Err(invalid("Clue request key/value pair required"));
    };
    let [name, datum]: [Datum; 2] = pair
        .try_into()
        .map_err(|_| invalid("Clue request key/value pair required"))?;
    let data = value(datum)?;
    let (Datum::Atom(key) | Datum::Text(key)) = name else {
        return Err(invalid("Clue request field name required"));
    };
    validate(&key, &data)?;
    Ok((key, data))
}
/// Decode inert request fields with the Library's existing bounded datum reader.
/// # Errors
/// Rejects malformed, duplicate, unknown or executable fields.
pub fn read_clue_request(source: &str) -> Result<Data> {
    let Datum::List(fields) = read_datum(source)? else {
        return Err(invalid("Clue request association list required"));
    };
    let request = fields
        .into_iter()
        .try_fold(BTreeMap::new(), |mut request, datum| {
            let (key, data) = field(datum)?;
            if request.insert(key, data).is_some() {
                return Err(invalid("duplicate Clue request field"));
            }
            Ok(request)
        })?;
    if request.contains_key("constructor") && !request.contains_key("selector") {
        return Err(invalid("constructor requires a caller-written selector"));
    }
    Ok(Data::Map(request))
}
