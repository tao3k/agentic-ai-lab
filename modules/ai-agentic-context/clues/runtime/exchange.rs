//! Clue exchange over the existing declarative Session, without a consumer VM.
use super::hypotheses::append_hypothesis;
use super::projection::{projection_facts, validate_clues, validate_references};
use super::{data_rows, invalid, rows};
use crate::{Cancellation, Data, Engine, FactLimits, Limits, Result, Row, SourceSession, Value};
use std::collections::{BTreeMap, BTreeSet};

pub(super) const RULES: &str = include_str!(
    "../../../../packages/python-runtime/src/agentic_ai_lab_runtime/reasoning_rules/clue_query_rules.ss"
);

/// Caller-owned projection declarations and host-attested input facts.
#[derive(Clone, Copy)]
pub struct ClueProjection<'a> {
    /// Scheme projection declarations.
    pub sources: &'a [&'a str],
    /// Projection constructor exported by those declarations.
    pub constructor: &'a str,
    /// Caller-supplied source relations.
    pub supplied: &'a Data,
    /// Host-checked source label to content digest mapping.
    pub attestations: &'a Data,
}

/// Application-owned selector declarations; the Library supplies no navigation policy.
#[derive(Clone, Copy)]
pub struct ClueSelector<'a> {
    /// Scheme selector declarations.
    pub sources: &'a [&'a str],
    /// Selector constructor exported by those declarations.
    pub constructor: &'a str,
}

/// Source-bound observations and untrusted hypotheses share query rules, not authority.
/// The host supplies source attestations; this owner never executes or admits work.
pub struct ClueExchange {
    pub(super) engine: Engine,
    pub(super) facts: BTreeMap<String, Vec<Row>>,
    pub(super) identity: String,
    pub(super) read_contract: String,
    session: SourceSession,
}

pub(super) fn evaluate(
    session: &mut SourceSession,
    facts: BTreeMap<String, Vec<Row>>,
    limits: &Limits,
    cancel: &Cancellation,
) -> Result<BTreeMap<String, Vec<Row>>> {
    session.replace(facts, limits, cancel)?;
    let result = session.run(None, limits, cancel)?;
    session.result(result.result_handle)?.close();
    if !result.complete {
        return Err(invalid("incomplete Clue evaluation"));
    }
    Ok(result.relations)
}

impl ClueExchange {
    pub(super) fn check(&self) -> Result<()> {
        self.engine.check()?;
        if self.session.is_closed() {
            Err(crate::Error::Closed)
        } else {
            Ok(())
        }
    }

    /// Release the Session; detached reads remain data, not live authority.
    pub fn close(&mut self) {
        self.session.close();
    }

    /// Partial vocabulary for discovery, never an admissible-question whitelist.
    /// # Errors
    /// Rejects invalid retained cell types.
    pub fn inventory(&self) -> Result<Data> {
        self.check()?;
        let factors: BTreeSet<_> = self.facts["factor"]
            .iter()
            .map(|row| Row::from(vec![row[2].clone(), row[3].clone()]))
            .collect();
        let claims: BTreeSet<_> = self.facts["clue"]
            .iter()
            .map(|row| Row::from(vec![row[2].clone()]))
            .collect();
        Ok(Data::object([
            (
                "factors",
                data_rows(&factors.into_iter().collect::<Vec<_>>())?,
            ),
            (
                "claims",
                data_rows(&claims.into_iter().collect::<Vec<_>>())?,
            ),
            ("inventoryComplete", false.into()),
        ]))
    }
    /// Project trusted host facts with caller-owned Scheme declarations.
    /// `attestations` maps source labels to the host-checked current content digest.
    /// Neither Agent hints nor projected hypotheses can attest observations.
    /// # Errors
    /// Rejects malformed declarations, unbound sources and ambiguous clue identities.
    pub fn new(
        engine: &Engine,
        projection: ClueProjection<'_>,
        limits: &Limits,
        cancel: &Cancellation,
    ) -> Result<Self> {
        let ClueProjection {
            sources,
            constructor,
            supplied,
            attestations,
        } = projection;
        let mut projection =
            engine.open_declaration_sources(sources, Some(constructor), FactLimits::default())?;
        let inputs = supplied
            .map()?
            .iter()
            .map(|(name, value)| {
                let rows = value
                    .list()?
                    .iter()
                    .map(|row| {
                        row.list()?
                            .iter()
                            .map(|cell| gerbil_ascent::Catalog::scalar(cell, crate::Type::Any))
                            .collect::<Result<Vec<_>>>()
                            .map(Row::from)
                    })
                    .collect::<Result<Vec<_>>>()?;
                Ok((name.clone(), rows))
            })
            .collect::<Result<_>>()?;
        let projected = evaluate(&mut projection, inputs, limits, cancel)?;
        let mut facts = projection_facts(&projected)?;
        let (identities, attested) = validate_clues(&facts["clue"], attestations)?;
        validate_references(&facts, &identities)?;
        facts.insert("attested".into(), attested);
        facts.insert("question".into(), vec![]);
        let identity = Data::object([
            (
                "declarations",
                Data::List(sources.iter().map(|v| Data::from(*v)).collect()),
            ),
            ("constructor", constructor.into()),
            ("facts", supplied.clone()),
            ("attestations", attestations.clone()),
            ("rules", RULES.into()),
        ])
        .digest();
        let read_contract = Data::object([
            (
                "declarations",
                Data::List(sources.iter().map(|v| Data::from(*v)).collect()),
            ),
            ("constructor", constructor.into()),
            ("rules", RULES.into()),
        ])
        .digest();
        let session = engine.open_declaration_sources(
            &[RULES],
            Some("make-clue-query-evidence"),
            FactLimits::default(),
        )?;
        Ok(Self {
            engine: engine.clone(),
            facts,
            identity,
            read_contract,
            session,
        })
    }

    /// Read exact Agent claims or caller-selected claims. Unknown claims remain visible.
    /// # Errors
    /// Propagates Session limits, cancellation and type failures.
    pub fn read(
        &mut self,
        questions: &[String],
        limits: &Limits,
        cancel: &Cancellation,
    ) -> Result<Data> {
        self.check()?;
        if questions.iter().any(String::is_empty) {
            return Err(invalid("nonempty questions required"));
        }
        let mut facts = self.facts.clone();
        facts.insert(
            "question".into(),
            questions
                .iter()
                .map(|q| Row::from(vec![q.as_str().into()]))
                .collect(),
        );
        let answers = evaluate(&mut self.session, facts, limits, cancel)?;
        let mut result = answers
            .iter()
            .map(|(name, value)| Ok((name.clone(), data_rows(value)?)))
            .collect::<Result<BTreeMap<_, _>>>()?;
        result.insert("sourceIdentity".into(), self.identity.clone().into());
        result.insert(
            "questions".into(),
            Data::List(questions.iter().cloned().map(Data::from).collect()),
        );
        result.insert("executionAuthorized".into(), false.into());
        result.insert("runtimeAdmitted".into(), false.into());
        Ok(Data::Map(result))
    }

    /// Evaluate an application-owned selector, not a Library-mandated navigation policy.
    /// # Errors
    /// Invalid selectors or missing question outputs are rejected, never guessed.
    pub fn select(
        &self,
        selector: ClueSelector<'_>,
        bindings: &Data,
        limits: &Limits,
        cancel: &Cancellation,
    ) -> Result<Data> {
        self.check()?;
        let ClueSelector {
            sources,
            constructor,
        } = selector;
        let mut declarations = Vec::with_capacity(sources.len() + 1);
        declarations.push(RULES);
        declarations.extend_from_slice(sources);
        let mut session = self.engine.open_declaration_sources(
            &declarations,
            Some(constructor),
            FactLimits::default(),
        )?;
        let mut facts = BTreeMap::from([
            ("clue".into(), self.facts["clue"].clone()),
            ("factor".into(), self.facts["factor"].clone()),
            ("binding".into(), rows(bindings)?),
            ("link".into(), self.facts["link"].clone()),
            ("attested".into(), self.facts["attested"].clone()),
        ]);
        let sources: BTreeSet<_> = session
            .descriptors()
            .iter()
            .filter(|r| r.source)
            .map(|r| r.name.clone())
            .collect();
        facts.retain(|name, _| sources.contains(name));
        let result = evaluate(&mut session, facts, limits, cancel)?;
        if !result.contains_key("question") {
            return Err(invalid("selector requires question output"));
        }
        Ok(Data::Map(
            result
                .iter()
                .map(|(k, v)| Ok((k.clone(), data_rows(v)?)))
                .collect::<Result<_>>()?,
        ))
    }

    /// Agent hypotheses are immutable, never observation receipts. No factor vocabulary is closed.
    /// # Errors
    /// Reusing an id or changing its body is rejected atomically.
    pub fn submit(&mut self, hypotheses: &Data) -> Result<()> {
        self.check()?;
        let mut candidate = self.facts.clone();
        let mut ids = candidate["clue"]
            .iter()
            .map(|row| match &row[0] {
                Value::Text(text) => Ok(text.to_string()),
                _ => Err(invalid("Clue relations require text cells")),
            })
            .collect::<Result<BTreeSet<_>>>()?;
        hypotheses
            .list()?
            .iter()
            .try_for_each(|hint| append_hypothesis(hint, &mut ids, &mut candidate))?;
        self.facts = candidate;
        Ok(())
    }

    /// Compose independent caller projections without sharing consumer code.
    /// # Errors
    /// Identity collisions reject the whole addition; observations are re-attested.
    pub fn include(&mut self, other: Self) -> Result<()> {
        self.check()?;
        other.check()?;
        let current: BTreeSet<_> = self.facts["clue"].iter().map(|row| &row[0]).collect();
        if other.facts["clue"]
            .iter()
            .any(|row| current.contains(&row[0]))
        {
            return Err(invalid("clue identity collision between projections"));
        }
        let identity =
            Data::List(vec![self.identity.clone().into(), other.identity.into()]).digest();
        let read_contract = Data::List(vec![
            self.read_contract.clone().into(),
            other.read_contract.into(),
        ])
        .digest();
        for name in ["clue", "factor", "link", "attested"] {
            self.facts
                .entry(name.into())
                .or_default()
                .extend(other.facts[name].iter().cloned());
        }
        self.identity = identity;
        self.read_contract = read_contract;
        Ok(())
    }

    /// Bind and read through a caller's selector in one progressive exchange.
    /// # Errors
    /// Missing or malformed selector question projections are not silently ignored.
    pub fn read_selected(
        &mut self,
        selector: ClueSelector<'_>,
        bindings: &Data,
        limits: &Limits,
        cancel: &Cancellation,
    ) -> Result<Data> {
        let ClueSelector {
            sources,
            constructor,
        } = selector;
        let selection = self.select(selector, bindings, limits, cancel)?;
        let questions = selection
            .field("question")?
            .list()?
            .iter()
            .map(|row| {
                let row = row.list()?;
                if row.len() != 1 {
                    return Err(invalid("selector question arity must be one"));
                }
                Ok(row[0].identity()?.to_owned())
            })
            .collect::<Result<Vec<_>>>()?;
        let mut result = self.read(&questions, limits, cancel)?.map()?.clone();
        result.insert("selection".into(), selection);
        result.insert(
            "selectorIdentity".into(),
            Data::object([
                ("schema", Data::from(RULES).digest().into()),
                (
                    "declarations",
                    Data::List(sources.iter().map(|source| Data::from(*source)).collect()),
                ),
                ("constructor", constructor.into()),
                ("bindings", bindings.clone()),
            ])
            .digest()
            .into(),
        );
        Ok(Data::Map(result))
    }
}
