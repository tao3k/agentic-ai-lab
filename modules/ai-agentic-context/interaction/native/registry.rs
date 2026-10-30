//! Immutable operation definitions are normalized once and intern shared native query graphs.
use crate::{
    Catalog, Data, Result,
    evidence_graph::normalize_contract,
    evidence_store::{put, schema},
    invalid_data as invalid,
};
use std::{
    collections::{BTreeMap, BTreeSet},
    sync::Arc,
};
/// Trusted application registration. Completeness concerns this local predicate only.
#[derive(Clone)]
pub struct EvidenceOperation {
    program: Data,
    relation: String,
    description: String,
    complete: bool,
}
impl EvidenceOperation {
    /// # Errors
    /// Rejects malformed graphs, missing predicates and unsafe rule structure.
    pub fn new(program: &Data, relation: &str, description: &str, complete: bool) -> Result<Self> {
        let mut program = normalize_contract(program)?;
        put(&mut program, "queries", Data::List(Vec::new()))?;
        let catalog = Catalog::read(&program)?;
        catalog.program.validate()?;
        if !program
            .field("relations")?
            .list()?
            .iter()
            .any(|r| r.get("name") == Some(&Data::from(relation)))
        {
            return Err(invalid("registered predicate is not declared"));
        }
        Ok(Self {
            program,
            relation: relation.into(),
            description: description.into(),
            complete,
        })
    }
    #[must_use]
    pub fn program(&self) -> &Data {
        &self.program
    }
    #[must_use]
    pub fn relation(&self) -> &str {
        &self.relation
    }
    #[must_use]
    pub fn description(&self) -> &str {
        &self.description
    }
    #[must_use]
    pub fn complete(&self) -> bool {
        self.complete
    }
}
pub(super) struct Registered {
    pub signature: String,
    pub relation: String,
    pub columns: Data,
    pub complete: bool,
}
pub(super) struct Registry {
    pub operations: BTreeMap<String, Registered>,
    pub programs: BTreeMap<String, Arc<Data>>,
    pub descriptions: BTreeMap<String, Data>,
}
impl Registry {
    pub fn new(sources: &Data, operations: &BTreeMap<String, EvidenceOperation>) -> Result<Self> {
        if operations.is_empty() || operations.len() > 64 {
            return Err(invalid("register one to 64 local operations"));
        }
        let trusted = source_index(sources)?;
        let mut registry = Self {
            operations: BTreeMap::new(),
            programs: BTreeMap::new(),
            descriptions: BTreeMap::new(),
        };
        let mut queries = BTreeMap::<String, BTreeSet<String>>::new();
        for (name, operation) in operations {
            registry.register(name, operation, &trusted, &mut queries)?;
        }
        for (key, names) in queries {
            let mut program = registry.programs[&key].as_ref().clone();
            put(
                &mut program,
                "queries",
                Data::List(names.into_iter().map(Data::from).collect()),
            )?;
            registry.programs.insert(key, Arc::new(program));
        }
        Ok(registry)
    }
    fn register(
        &mut self,
        name: &str,
        operation: &EvidenceOperation,
        trusted: &BTreeMap<String, Data>,
        queries: &mut BTreeMap<String, BTreeSet<String>>,
    ) -> Result<()> {
        if name.is_empty() {
            return Err(invalid("operation identity required"));
        }
        let program = current_program(&operation.program, trusted)?;
        let signature = program.digest();
        if self
            .programs
            .get(&signature)
            .is_some_and(|prior| **prior != program)
        {
            return Err(invalid("operation graph digest collision"));
        }
        let declaration = program
            .field("relations")?
            .list()?
            .iter()
            .find(|r| r.get("name") == Some(&Data::Text(operation.relation.clone())))
            .ok_or_else(|| invalid("missing registered predicate"))?;
        let columns = declaration.field("columns")?.clone();
        self.operations.insert(
            name.into(),
            Registered {
                signature: signature.clone(),
                relation: operation.relation.clone(),
                columns,
                complete: operation.complete,
            },
        );
        self.programs
            .entry(signature.clone())
            .or_insert_with(|| Arc::new(program));
        self.descriptions
            .insert(name.into(), operation.description.clone().into());
        queries
            .entry(signature)
            .or_default()
            .insert(operation.relation.clone());
        Ok(())
    }
}
fn source_index(sources: &Data) -> Result<BTreeMap<String, Data>> {
    sources
        .list()?
        .iter()
        .map(|s| s.field("name")?.text().map(|n| (n.to_string(), s.clone())))
        .collect()
}
fn current_program(program: &Data, trusted: &BTreeMap<String, Data>) -> Result<Data> {
    let mut program = program.clone();
    let mut included = BTreeSet::new();
    let mut declarations = program
        .field("relations")?
        .list()?
        .iter()
        .map(|r| {
            let name = r.field("name")?.text()?;
            if !r.field("source")?.boolean()? {
                return Ok(r.clone());
            }
            let authority = trusted
                .get(name)
                .ok_or_else(|| invalid("operation introduces an untrusted source"))?;
            if schema(r) != schema(authority) {
                return Err(invalid("operation changed trusted source schema"));
            }
            included.insert(name.to_string());
            Ok(authority.clone())
        })
        .collect::<Result<Vec<_>>>()?;
    declarations.extend(
        trusted
            .iter()
            .filter(|(n, _)| !included.contains(*n))
            .map(|(_, r)| r.clone()),
    );
    put(&mut program, "relations", Data::List(declarations))?;
    Ok(program)
}
pub(super) fn ground(arguments: &Data, columns: &Data) -> Result<bool> {
    let arguments = arguments.list()?;
    let columns = columns.list()?;
    if arguments.len() != columns.len() {
        return Ok(false);
    }
    arguments
        .iter()
        .zip(columns)
        .map(|(v, c)| ground_cell(v, c))
        .collect::<Result<Vec<_>>>()
        .map(|values| values.into_iter().all(|v| v))
}
fn ground_cell(value: &Data, column: &Data) -> Result<bool> {
    let valid = match column.field("kind")?.text()? {
        "integer" => matches!(value, Data::Integer(_)),
        "boolean" => matches!(value, Data::Bool(_)),
        "symbol" | "text" | "string" => matches!(value, Data::Text(_)),
        "value" | "scalar" => matches!(value, Data::Integer(_) | Data::Bool(_) | Data::Text(_)),
        _ => false,
    };
    if !valid {
        return Ok(false);
    }
    Ok(column
        .get("domain")
        .map(Data::list)
        .transpose()?
        .is_none_or(|domain| domain.contains(value)))
}
