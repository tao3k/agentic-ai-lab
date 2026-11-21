//! Provider-facing tool descriptions expose only bounded, registered local predicates.
use super::EvidenceInteraction;
use crate::Data;
use std::collections::BTreeMap;

impl EvidenceInteraction {
    /// Detached tool schemas. They grant no source authority or whole-task certification.
    #[must_use]
    pub fn tools(&self) -> Data {
        let condition = object_schema(
            BTreeMap::from([
                (
                    "operation".into(),
                    Data::object([
                        ("type", "string".into()),
                        (
                            "enum",
                            Data::List(
                                self.descriptions()
                                    .keys()
                                    .cloned()
                                    .map(Data::from)
                                    .collect(),
                            ),
                        ),
                    ]),
                ),
                (
                    "arguments".into(),
                    array(Data::Map(BTreeMap::new()), 0, 256),
                ),
            ]),
            &["operation", "arguments"],
        );
        let branch = object_schema(
            BTreeMap::from([
                ("id".into(), string()),
                ("conditions".into(), array(condition.clone(), 1, 16)),
                ("reference".into(), string()),
            ]),
            &["id", "conditions"],
        );
        let extension = object_schema(
            BTreeMap::from([
                ("id".into(), string()),
                ("reference".into(), string()),
                ("conditions".into(), array(condition, 1, 16)),
            ]),
            &["id", "reference", "conditions"],
        );
        Data::List(vec![
            tool(
                "check_branches",
                "Check the conjunction of declared local conditions. Supported certifies only these conditions; unknown is not false. No whole-task answer is certified.",
                "branches",
                branch,
                self.descriptions(),
            ),
            tool(
                "reuse_paths",
                "Recheck local paths against current sources. Stale or foreign references return unknown.",
                "references",
                string(),
                self.descriptions(),
            ),
            tool(
                "extend_paths",
                "Check all previous and added local conditions in the current source generation.",
                "paths",
                extension,
                self.descriptions(),
            ),
        ])
    }
}
fn string() -> Data {
    Data::object([("type", "string".into())])
}
fn array(items: Data, min: usize, max: usize) -> Data {
    Data::object([
        ("type", "array".into()),
        ("items", items),
        ("minItems", min.into()),
        ("maxItems", max.into()),
    ])
}
fn object_schema(properties: BTreeMap<String, Data>, required: &[&str]) -> Data {
    Data::object([
        ("type", "object".into()),
        ("properties", Data::Map(properties)),
        (
            "required",
            Data::List(required.iter().map(|v| Data::from(*v)).collect()),
        ),
        ("additionalProperties", false.into()),
    ])
}
fn tool(
    name: &str,
    description: &str,
    field: &str,
    items: Data,
    operations: &BTreeMap<String, Data>,
) -> Data {
    Data::object([
        ("type", "function".into()),
        ("name", name.into()),
        (
            "description",
            format!(
                "{description} Registered operations: {}",
                operations
                    .iter()
                    .map(|(name, value)| format!("{name}: {}", value.text().unwrap_or("")))
                    .collect::<Vec<_>>()
                    .join("; ")
            )
            .into(),
        ),
        (
            "parameters",
            object_schema(
                BTreeMap::from([(field.into(), array(items, 1, 128))]),
                &[field],
            ),
        ),
        ("strict", false.into()),
    ])
}
