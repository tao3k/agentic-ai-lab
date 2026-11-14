//! Provider history retains opaque items and enforces atomic, uniquely paired tool responses.
use crate::{Data, Result, invalid_data as invalid};
use std::collections::{BTreeMap, BTreeSet};
/// Opaque nonempty identity supplied by the external provider, never executable authority.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ToolCallId(String);
impl ToolCallId {
    /// # Errors
    /// Rejects empty provider call identities.
    pub fn new(value: &str) -> Result<Self> {
        if value.is_empty() {
            return Err(invalid("tool call identity required"));
        }
        Ok(Self(value.into()))
    }
}
/// Provider observations have no inference or execution authority in the relational engine.
pub struct ResponseHistory {
    items: Vec<Data>,
    pending: BTreeMap<String, Data>,
    seen: BTreeSet<String>,
}
impl ResponseHistory {
    #[must_use]
    pub fn new(question: Data) -> Self {
        Self {
            items: vec![Data::object([
                ("role", "user".into()),
                ("content", question),
            ])],
            pending: BTreeMap::new(),
            seen: BTreeSet::new(),
        }
    }
    /// Restore exact provider items after validating every unique call and output pairing.
    /// # Errors
    /// Rejects duplicate calls, orphan outputs, unknown item types and unfinished calls.
    pub fn restore(input: &Data) -> Result<Self> {
        let mut history = Self {
            items: vec![],
            pending: BTreeMap::new(),
            seen: BTreeSet::new(),
        };
        for item in input.list()? {
            history.restore_item(item)?;
        }
        history.ready()?;
        Ok(history)
    }
    /// Read detached audit items, including pending calls; these are not a ready provider input.
    #[must_use]
    pub fn snapshot(&self) -> Data {
        Data::List(self.items.clone())
    }
    /// Read the complete immutable set of observed provider call identities.
    #[must_use]
    pub fn seen(&self) -> BTreeSet<String> {
        self.seen.clone()
    }
    fn restore_item(&mut self, item: &Data) -> Result<()> {
        match item.get("type").map(Data::text).transpose()? {
            Some("function_call") => {
                let id = item.field("call_id")?.identity()?;
                if !self.seen.insert(id.into()) {
                    return Err(invalid("tool call identity must be unique"));
                }
                self.pending.insert(id.into(), item.clone());
            }
            Some("function_call_output") => {
                let id = item.field("call_id")?.identity()?;
                item.field("output")?.text()?;
                if self.pending.remove(id).is_none() {
                    return Err(invalid("orphan or duplicate tool output"));
                }
            }
            Some("reasoning" | "message") => (),
            None => {
                self.ready()?;
                if !matches!(
                    item.field("role")?.text()?,
                    "user" | "system" | "developer" | "assistant"
                ) {
                    return Err(invalid("unsupported history role"));
                }
                item.field("content")?;
            }
            _ => return Err(invalid("unsupported history item")),
        }
        self.items.push(item.clone());
        Ok(())
    }
    /// # Errors
    /// Rejects unpaired tool calls before exposing the next provider input.
    pub fn input(&self) -> Result<Data> {
        self.ready()?;
        Ok(Data::List(self.items.clone()))
    }
    fn ready(&self) -> Result<()> {
        if self.pending.is_empty() {
            Ok(())
        } else {
            Err(invalid("every function call requires a paired output"))
        }
    }
    /// # Errors
    /// Rejects unsupported items and duplicate IDs without changing retained history.
    pub fn append_response(&mut self, response: &Data) -> Result<Data> {
        self.ready()?;
        let output = response.field("output")?.list()?;
        let mut calls = BTreeMap::new();
        let mut ordered = Vec::new();
        for item in output {
            if let Some(id) = tool_call(item)? {
                if self.seen.contains(id) || calls.insert(id.to_string(), item.clone()).is_some() {
                    return Err(invalid("tool call identity must be unique"));
                }
                ordered.push(item.clone());
            }
        }
        self.items.extend_from_slice(output);
        self.seen.extend(calls.keys().cloned());
        self.pending = calls;
        Ok(Data::List(ordered))
    }
    /// # Errors
    /// Rejects unknown/completed calls. JSON is used only for the external provider protocol.
    pub fn append_result(&mut self, call_id: &ToolCallId, result: &Data) -> Result<()> {
        let call_id = call_id.0.as_str();
        if !self.pending.contains_key(call_id) {
            return Err(invalid("unknown or already completed tool call"));
        }
        let output = provider_json(result)?;
        self.items.push(Data::object([
            ("type", "function_call_output".into()),
            ("call_id", call_id.into()),
            ("output", output.into()),
        ]));
        self.pending.remove(call_id);
        Ok(())
    }
    /// # Errors
    /// Rejects feedback while tool responses remain unpaired.
    pub fn append_feedback(&mut self, result: &Data) -> Result<()> {
        self.ready()?;
        let content = provider_json(result)?;
        self.items.push(Data::object([
            ("role", "user".into()),
            ("content", content.into()),
        ]));
        Ok(())
    }
    #[must_use]
    pub fn reasoning_items(&self) -> usize {
        self.items
            .iter()
            .filter(|i| i.get("type") == Some(&Data::Text("reasoning".into())))
            .count()
    }
}
fn tool_call(item: &Data) -> Result<Option<&str>> {
    match item.field("type")?.text()? {
        "function_call" => item.field("call_id")?.identity().map(Some),
        "reasoning" | "message" => Ok(None),
        _ => Err(invalid("unsupported response output item")),
    }
}
/// External provider formatting is separate from typed engine program/result transport.
fn provider_json(value: &Data) -> Result<String> {
    let mut output = String::new();
    json_value(value, &mut output, 0)?;
    Ok(output)
}
fn json_value(value: &Data, out: &mut String, depth: usize) -> Result<()> {
    if depth > 128 {
        return Err(invalid("provider item depth bound"));
    }
    match value {
        Data::Null => out.push_str("null"),
        Data::Bool(v) => out.push_str(if *v { "true" } else { "false" }),
        Data::Integer(v) => out.push_str(&v.to_string()),
        Data::Real(v) => {
            let v = f64::from_bits(*v);
            if !v.is_finite() {
                return Err(invalid("finite provider number required"));
            }
            out.push_str(&v.to_string());
        }
        Data::Text(v) => quoted(v, out),
        Data::List(values) => json_list(values, out, depth + 1)?,
        Data::Map(values) => json_map(values, out, depth + 1)?,
    }
    Ok(())
}
fn json_list(values: &[Data], out: &mut String, depth: usize) -> Result<()> {
    out.push('[');
    for (i, value) in values.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        json_value(value, out, depth)?;
    }
    out.push(']');
    Ok(())
}
fn json_map(values: &BTreeMap<String, Data>, out: &mut String, depth: usize) -> Result<()> {
    out.push('{');
    for (i, (key, value)) in values.iter().enumerate() {
        if i > 0 {
            out.push(',');
        }
        quoted(key, out);
        out.push(':');
        json_value(value, out, depth)?;
    }
    out.push('}');
    Ok(())
}
fn quoted(value: &str, out: &mut String) {
    use std::fmt::Write;
    out.push('"');
    for c in value.chars() {
        match c {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            c if c < '\u{20}' => {
                write!(out, "\\u{:04x}", u32::from(c)).expect("string output");
            }
            c => out.push(c),
        }
    }
    out.push('"');
}
