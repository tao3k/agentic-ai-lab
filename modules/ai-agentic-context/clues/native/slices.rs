//! Presentation over Scheme-derived items; no relevance or set-difference policy.
use super::cells::text;
use super::{ClueExchange, ClueSelector, RULES, data_rows, evaluate, invalid, rows};
use super::{
    deferred::DeferredRelations,
    family::{counts, family},
};
use crate::{Cancellation, Data, FactLimits, Limits, Result, Row, Value};
use std::collections::{BTreeMap, BTreeSet};

fn reference(source: &str, claim: &str, items: &Data) -> Data {
    Data::object([
        ("claim", claim.into()),
        ("sourceIdentity", source.into()),
        ("contentIdentity", items.digest().into()),
    ])
}
fn request_fields(request: &Data) -> Result<&BTreeMap<String, Data>> {
    let fields = request.map()?;
    if fields.keys().any(|k| {
        !matches!(
            k.as_str(),
            "questions" | "expand" | "checkpoint" | "displayBytes" | "bindings" | "readConfirmed"
        )
    }) {
        return Err(invalid("unknown slice request field"));
    }
    Ok(fields)
}

fn saved_query(checkpoint: Option<&Data>) -> Result<Option<&Data>> {
    let Some(checkpoint) = checkpoint else {
        return Ok(None);
    };
    if checkpoint == &Data::List(Vec::new()) {
        return Ok(None);
    }
    let body = checkpoint.field("body")?;
    if body.digest() != checkpoint.field("digest")?.text()? {
        return Err(invalid("slice checkpoint content changed"));
    }
    if body.field("schema")?.text()? != "clue-slice.v1" {
        return Err(invalid("unsupported slice checkpoint"));
    }
    Ok(body.map()?.get("query"))
}
fn prior(
    checkpoint: Option<&Data>,
    source: &str,
    contract: &str,
    anchor: &str,
    confirmed: bool,
) -> Result<(Vec<Row>, Vec<Row>, &'static str)> {
    let Some(checkpoint) = checkpoint else {
        return Ok((Vec::new(), Vec::new(), "initial"));
    };
    if checkpoint == &Data::List(Vec::new()) {
        return Ok((Vec::new(), Vec::new(), "initial"));
    }
    let body = checkpoint.field("body")?;
    if body.digest() != checkpoint.field("digest")?.text()? {
        return Err(invalid("slice checkpoint content changed"));
    }
    if body.field("schema")?.text()? != "clue-slice.v1" {
        return Err(invalid("unsupported slice checkpoint"));
    }
    if !confirmed {
        return Ok((Vec::new(), Vec::new(), "initial"));
    }
    let source_changed = body.field("sourceIdentity")?.text()? != source;
    if source_changed
        && body
            .map()?
            .get("readContractIdentity")
            .map(Data::text)
            .transpose()?
            != Some(contract)
    {
        return Ok((Vec::new(), Vec::new(), "reset"));
    }
    let previous = rows(body.field("items")?)?;
    if previous.iter().any(|r| r.len() != 8) {
        return Err(invalid("slice checkpoint item arity"));
    }
    let relations = rows(body.field("relations")?)?;
    if relations.iter().any(|r| r.len() != 3) {
        return Err(invalid("slice checkpoint relation arity"));
    }
    let mode = if source_changed {
        "refresh"
    } else if body.field("anchorIdentity")?.text()? == anchor {
        "incremental"
    } else {
        "rescope"
    };
    Ok((previous, relations, mode))
}

impl ClueExchange {
    /// Read a caller-selected scope, with explicit expansions and an optional read hint.
    /// Display bytes never limit inference or permitted exploration.
    /// # Errors
    /// Rejects invalid checkpoints, partial evaluation, or insufficient display capacity.
    pub fn slice(
        &mut self,
        request: &Data,
        limits: &Limits,
        cancel: &Cancellation,
    ) -> Result<Data> {
        let fields = request_fields(request)?;
        if !fields.contains_key("questions") {
            if let Some(query) = saved_query(fields.get("checkpoint"))? {
                let mut resumed = query.map()?.clone();
                resumed.extend(fields.clone());
                if let Some(selection) = resumed.remove("selection") {
                    let sources = selection
                        .field("sources")?
                        .list()?
                        .iter()
                        .map(Data::text)
                        .collect::<Result<Vec<_>>>()?;
                    return self.slice_selected(
                        ClueSelector {
                            sources: &sources,
                            constructor: selection.field("constructor")?.text()?,
                        },
                        &Data::Map(resumed),
                        limits,
                        cancel,
                    );
                }
                let mut query = resumed.clone();
                query.remove("checkpoint");
                return self.slice_bound(
                    &Data::Map(resumed),
                    None,
                    Data::Map(query),
                    limits,
                    cancel,
                );
            }
            if fields.contains_key("checkpoint")
                && !fields.contains_key("bindings")
                && !fields.contains_key("expand")
            {
                return Err(invalid(
                    "checkpoint has no resumable query declaration; provide an explicit query",
                ));
            }
        }
        let mut query = fields.clone();
        query.remove("checkpoint");
        self.slice_bound(request, None, Data::Map(query), limits, cancel)
    }

    fn slice_bound(
        &mut self,
        request: &Data,
        selection: Option<Data>,
        query: Data,
        limits: &Limits,
        cancel: &Cancellation,
    ) -> Result<Data> {
        self.check()?;
        let fields = request_fields(request)?;
        let claims = |name: &str| -> Result<Vec<String>> {
            fields.get(name).map_or(Ok(Vec::new()), |v| {
                v.list()?
                    .iter()
                    .map(|c| Ok(c.identity()?.to_owned()))
                    .collect()
            })
        };
        let questions = claims("questions")?;
        let expansions = claims("expand")?;
        let checkpoint = fields.get("checkpoint");
        let confirmed = fields
            .get("readConfirmed")
            .map_or(Ok(true), Data::boolean)?;
        // Carrier confirmation affects display reuse, never the saved query.
        // It is an observation for this read, not a sticky query preference.
        let Data::Map(mut query) = query else {
            return Err(invalid("slice query must be a map"));
        };
        query.remove("readConfirmed");
        let query = Data::Map(query);
        let display_bytes = fields
            .get("displayBytes")
            .map_or(Ok(8192usize), Data::index)?;
        let scope: BTreeSet<_> = questions.iter().chain(expansions.iter()).cloned().collect();
        if scope.iter().any(String::is_empty) {
            return Err(invalid("nonempty slice claims required"));
        }
        let scope_data = Data::List(scope.iter().cloned().map(Data::from).collect());
        let anchor = Data::object([
            ("questions", scope_data.clone()),
            (
                "selectorIdentity",
                selection
                    .as_ref()
                    .map(|s| s.field("selectorIdentity").cloned())
                    .transpose()?
                    .unwrap_or(Data::List(Vec::new())),
            ),
        ])
        .digest();
        let (previous, previous_relations, mode) = prior(
            checkpoint,
            &self.identity,
            &self.read_contract,
            &anchor,
            confirmed,
        )?;
        let mut facts = self.facts.clone();
        facts.insert(
            "question".into(),
            scope
                .iter()
                .map(|c| Row::from(vec![c.as_str().into()]))
                .collect(),
        );
        facts.insert("previous".into(), previous.clone());
        let mut session = self.engine.open_declaration_sources(
            &[RULES],
            Some("make-clue-slice-evidence"),
            FactLimits::default(),
        )?;
        let answers = evaluate(&mut session, facts, limits, cancel);
        session.close();
        let answers = answers?;
        let items = data_rows(&answers["item"])?;
        render_slice(SliceView {
            engine: &self.engine,
            limits,
            cancel,
            source: &self.identity,
            read_contract: &self.read_contract,
            anchor: &anchor,
            mode,
            scope_data,
            items: &items,
            answers: &answers,
            selection,
            query,
            previous: &previous,
            previous_relations: &previous_relations,
            display_bytes,
        })
    }

    /// The application declares association, including conjunctions or recursive paths.
    /// # Errors
    /// Missing association output, malformed declarations and partial runs are errors.
    pub fn slice_selected(
        &mut self,
        selector: ClueSelector<'_>,
        request: &Data,
        limits: &Limits,
        cancel: &Cancellation,
    ) -> Result<Data> {
        let ClueSelector {
            sources,
            constructor,
        } = selector;
        let mut inherited = inherited_request(request)?;
        let bindings = inherited
            .entry("bindings".into())
            .or_insert_with(|| Data::List(Vec::new()))
            .clone();
        let mut selection = self
            .select(selector, &bindings, limits, cancel)?
            .map()?
            .clone();
        let questions = selector_questions(&selection)?;
        selection.insert(
            "selectorIdentity".into(),
            Data::object([
                ("schema", Data::from(super::RULES).digest().into()),
                (
                    "sources",
                    Data::List(sources.iter().map(|s| Data::from(*s)).collect()),
                ),
                ("constructor", constructor.into()),
                ("bindings", bindings),
            ])
            .digest()
            .into(),
        );
        let mut query = inherited.clone();
        query.remove("checkpoint");
        query.remove("questions");
        query.insert(
            "selection".into(),
            Data::object([
                (
                    "sources",
                    Data::List(sources.iter().map(|s| Data::from(*s)).collect()),
                ),
                ("constructor", constructor.into()),
            ]),
        );
        let mut request = inherited;
        request.insert(
            "questions".into(),
            Data::List(questions.into_iter().map(Data::from).collect()),
        );
        self.slice_bound(
            &Data::Map(request),
            Some(Data::Map(selection)),
            Data::Map(query),
            limits,
            cancel,
        )
    }
}

fn inherited_request(request: &Data) -> Result<BTreeMap<String, Data>> {
    let fields = request_fields(request)?;
    let mut inherited = saved_query(fields.get("checkpoint"))?
        .map(Data::map)
        .transpose()?
        .cloned()
        .unwrap_or_default();
    inherited.remove("selection");
    inherited.extend(fields.clone());
    Ok(inherited)
}

fn selector_questions(selection: &BTreeMap<String, Data>) -> Result<Vec<String>> {
    selection
        .get("question")
        .ok_or_else(|| invalid("selector requires question"))?
        .list()?
        .iter()
        .map(|row| {
            if row.list()?.len() != 1 {
                return Err(invalid("selector question arity"));
            }
            Ok(text(row, 0)?.to_owned())
        })
        .collect::<Result<Vec<_>>>()
}

struct SliceView<'a> {
    engine: &'a crate::Engine,
    limits: &'a Limits,
    cancel: &'a Cancellation,
    source: &'a str,
    read_contract: &'a str,
    anchor: &'a str,
    mode: &'a str,
    scope_data: Data,
    items: &'a Data,
    answers: &'a BTreeMap<String, Vec<Row>>,
    selection: Option<Data>,
    query: Data,
    previous: &'a [Row],
    previous_relations: &'a [Row],
    display_bytes: usize,
}
fn slice_header(view: &SliceView<'_>) -> Result<BTreeMap<String, Data>> {
    Ok(BTreeMap::from([
        ("sourceIdentity".into(), view.source.into()),
        ("anchorIdentity".into(), view.anchor.into()),
        ("mode".into(), view.mode.into()),
        ("evaluationComplete".into(), true.into()),
        ("presentationComplete".into(), true.into()),
        ("executionAuthorized".into(), false.into()),
        ("runtimeAdmitted".into(), false.into()),
        ("explorationOpen".into(), true.into()),
        ("counts".into(), counts(view.items.list()?)?),
        (
            "delta".into(),
            Data::object([
                ("added", view.answers["added"].len().into()),
                ("removed", view.answers["removed"].len().into()),
                ("retained", view.answers["retained"].len().into()),
            ]),
        ),
        ("families".into(), Data::List(Vec::new())),
        ("deferred".into(), Data::List(Vec::new())),
        (
            "scopeReference".into(),
            Data::object([
                ("sourceIdentity", view.source.into()),
                ("claims", view.scope_data.clone()),
            ]),
        ),
    ]))
}

fn relation_summaries(
    source: &str,
    traces: &BTreeMap<String, Data>,
    relation_rows: &[Row],
) -> Result<Vec<Data>> {
    data_rows(relation_rows)?
        .list()?
        .iter()
        .map(|row| {
            let name = text(row, 1)?;
            Ok(Data::object([
                ("relation", name.into()),
                ("role", "derived-relation".into()),
                ("rowCount", traces[name].list()?.len().into()),
                (
                    "reference",
                    Data::object([
                        ("sourceIdentity", source.into()),
                        ("selectorIdentity", text(row, 0)?.into()),
                        ("relation", name.into()),
                        ("contentIdentity", text(row, 2)?.into()),
                    ]),
                ),
            ]))
        })
        .collect()
}

fn present_relations(
    mut association: BTreeMap<String, Data>,
    traces: &BTreeMap<String, Data>,
    pending: &[Row],
    brief: &mut BTreeMap<String, Data>,
    display_bytes: usize,
) -> Result<Vec<Row>> {
    let mut deferred = DeferredRelations::new(brief["deferredRelations"].list()?.to_vec());
    let mut shown = Vec::new();
    for row in data_rows(pending)?.list()? {
        let name = text(row, 1)?;
        if association.contains_key(name) {
            shown.extend(rows(&Data::List(vec![row.clone()]))?);
            continue;
        }
        let summary = deferred.summary(name)?;
        deferred.remove(&summary);
        association.insert(name.into(), traces[name].clone());
        brief.insert("association".into(), Data::Map(association.clone()));
        brief.insert("deferredRelations".into(), deferred.data());
        if super::clue_sexpr(&Data::Map(brief.clone())).len() > display_bytes {
            fold_scope_reference(brief)?;
        }
        if super::clue_sexpr(&Data::Map(brief.clone())).len() > display_bytes {
            association.remove(name);
            deferred.push(summary);
            brief.insert("association".into(), Data::Map(association.clone()));
            brief.insert("deferredRelations".into(), deferred.data());
        } else {
            shown.extend(rows(&Data::List(vec![row.clone()]))?);
        }
    }
    brief.insert(
        "presentationComplete".into(),
        (deferred.is_empty()
            && brief["deferred"].list()?.is_empty()
            && !brief.contains_key("deferredScope"))
        .into(),
    );
    Ok(shown)
}

fn prepare_relations(
    source: &str,
    mut association: BTreeMap<String, Data>,
    traces: &BTreeMap<String, Data>,
    pending: &BTreeMap<String, Vec<Row>>,
    brief: &mut BTreeMap<String, Data>,
) -> Result<BTreeMap<String, Data>> {
    for name in traces.keys() {
        association.remove(name);
    }
    let mut deferred = DeferredRelations::new(relation_summaries(
        source,
        traces,
        &pending["pending_relation"],
    )?);
    for row in data_rows(&pending["pending_relation"])?.list()? {
        let name = text(row, 1)?;
        let summary = deferred.summary(name)?;
        let raw = Data::object([(name, traces[name].clone())]);
        // Inline tiny/empty results when a reference would be the larger encoding.
        if super::clue_sexpr(&raw).len() <= super::clue_sexpr(&summary).len() {
            association.insert(name.into(), traces[name].clone());
            deferred.remove(&summary);
        }
    }
    brief.insert("deferredRelations".into(), deferred.data());
    brief.insert(
        "retainedRelations".into(),
        Data::List(relation_summaries(
            source,
            traces,
            &pending["retained_relation"],
        )?),
    );
    if !association.is_empty() {
        brief.insert("association".into(), Data::Map(association.clone()));
    }
    Ok(association)
}

struct RelationView {
    association: BTreeMap<String, Data>,
    traces: BTreeMap<String, Data>,
    items: Vec<Row>,
}

fn relation_view(selection: Option<Data>, source: &str) -> Result<RelationView> {
    let association = selection
        .map(|s| s.map().cloned())
        .transpose()?
        .unwrap_or_default();
    let selector = association
        .get("selectorIdentity")
        .map(Data::text)
        .transpose()?
        .unwrap_or("");
    let question_is_wide = if let Some(question) = association.get("question") {
        let row = Row::from(vec![
            Value::from(selector),
            Value::from("question"),
            Value::from(question.digest().as_str()),
        ]);
        let summary = relation_summaries(
            source,
            &BTreeMap::from([("question".into(), question.clone())]),
            &[row],
        )?;
        super::clue_sexpr(&Data::object([("question", question.clone())])).len()
            > super::clue_sexpr(&summary[0]).len()
    } else {
        false
    };
    let traces = association
        .iter()
        .filter(|(name, _)| {
            name.as_str() != "selectorIdentity" && (name.as_str() != "question" || question_is_wide)
        })
        .map(|(name, value)| (name.clone(), value.clone()))
        .collect::<BTreeMap<_, _>>();
    let items = traces
        .iter()
        .map(|(name, value)| {
            Row::from(vec![
                Value::from(selector),
                Value::from(name.as_str()),
                Value::from(value.digest().as_str()),
            ])
        })
        .collect();
    Ok(RelationView {
        association,
        traces,
        items,
    })
}

fn render_slice(view: SliceView<'_>) -> Result<Data> {
    let mut brief = slice_header(&view)?;
    let changed = data_rows(&view.answers["changed"])?;
    let changed: BTreeSet<_> = changed
        .list()?
        .iter()
        .map(|r| Ok(text(r, 0)?.to_owned()))
        .collect::<Result<_>>()?;
    let mut families: BTreeMap<String, Vec<Data>> = BTreeMap::new();
    for row in view.items.list()? {
        families
            .entry(text(row, 1)?.into())
            .or_default()
            .push(row.clone());
    }
    let RelationView {
        association,
        traces,
        items: relation_items,
    } = relation_view(view.selection, view.source)?;
    let mut acknowledgements = view.engine.open_declaration_sources(
        &[RULES],
        Some("make-clue-read-acknowledgement"),
        FactLimits::default(),
    )?;
    let mut ack_facts = BTreeMap::from([
        ("previous".into(), view.previous.to_vec()),
        ("item".into(), rows(view.items)?),
        ("shown".into(), Vec::new()),
        ("previous_relation".into(), view.previous_relations.to_vec()),
        ("relation_item".into(), relation_items),
        ("shown_relation".into(), Vec::new()),
    ]);
    let pending = evaluate(
        &mut acknowledgements,
        ack_facts.clone(),
        view.limits,
        view.cancel,
    )?;
    let association = prepare_relations(view.source, association, &traces, &pending, &mut brief)?;
    present(
        view.source,
        &families,
        &changed,
        &mut brief,
        view.display_bytes,
    )?;
    let shown_relations = present_relations(
        association,
        &traces,
        &pending["pending_relation"],
        &mut brief,
        view.display_bytes,
    )?;
    let shown = brief["families"]
        .list()?
        .iter()
        .map(|family| Ok(Row::from(vec![Value::from(family.field("claim")?.text()?)])))
        .collect::<Result<Vec<_>>>()?;
    ack_facts.insert("shown".into(), shown);
    ack_facts.insert("shown_relation".into(), shown_relations);
    let acknowledged = evaluate(&mut acknowledgements, ack_facts, view.limits, view.cancel);
    acknowledgements.close();
    let acknowledged = acknowledged?;
    let body = Data::object([
        ("schema", "clue-slice.v1".into()),
        ("sourceIdentity", view.source.into()),
        ("readContractIdentity", view.read_contract.into()),
        ("anchorIdentity", view.anchor.into()),
        ("items", data_rows(&acknowledged["acknowledged"])?),
        ("query", view.query),
        (
            "relations",
            data_rows(&acknowledged["acknowledged_relation"])?,
        ),
    ]);
    let next = Data::object([("digest", body.digest().into()), ("body", body)]);
    Ok(Data::object([
        ("brief", Data::Map(brief)),
        ("checkpoint", next),
    ]))
}
fn fold_scope_reference(brief: &mut BTreeMap<String, Data>) -> Result<()> {
    if let Some(scope) = brief.get("scopeReference")
        && let Ok(claims) = scope.field("claims")
    {
        let compact = Data::object([
            ("sourceIdentity", scope.field("sourceIdentity")?.clone()),
            ("contentIdentity", claims.digest().into()),
            ("claimCount", claims.list()?.len().into()),
        ]);
        brief.insert("scopeReference".into(), compact);
    }
    Ok(())
}

fn defer_families(
    source: &str,
    pending: &[Data],
    brief: &mut BTreeMap<String, Data>,
    display_bytes: usize,
) -> Result<bool> {
    brief.remove("deferredScope");
    brief.insert("deferred".into(), Data::List(pending.to_vec()));
    if super::clue_sexpr(&Data::Map(brief.clone())).len() <= display_bytes {
        return Ok(true);
    }
    // A scope reference replaces only presentation, never the inferred scope
    // or acknowledgement. Repeating with the checkpoint exposes unseen units.
    brief.insert("deferred".into(), Data::List(Vec::new()));
    if !pending.is_empty() {
        brief.insert(
            "deferredScope".into(),
            Data::object([
                ("sourceIdentity", source.into()),
                (
                    "contentIdentity",
                    Data::List(pending.to_vec()).digest().into(),
                ),
                ("claimCount", pending.len().into()),
            ]),
        );
    }
    if super::clue_sexpr(&Data::Map(brief.clone())).len() > display_bytes {
        fold_scope_reference(brief)?;
    }
    Ok(super::clue_sexpr(&Data::Map(brief.clone())).len() <= display_bytes)
}

#[cfg(test)]
#[path = "tests/capacity.rs"]
mod capacity_tests;

fn present(
    source: &str,
    families: &BTreeMap<String, Vec<Data>>,
    changed: &BTreeSet<String>,
    brief: &mut BTreeMap<String, Data>,
    display_bytes: usize,
) -> Result<Vec<Data>> {
    let summaries = families
        .iter()
        .filter(|(claim, _)| changed.contains(*claim))
        .map(|(claim, members)| {
            Ok(Data::object([
                ("claim", claim.as_str().into()),
                ("collapsed", true.into()),
                ("counts", counts(members)?),
                (
                    "reference",
                    reference(source, claim, &Data::List(members.clone())),
                ),
            ]))
        })
        .collect::<Result<Vec<_>>>()?;
    let mut shown = Vec::new();
    let mut deferred = summaries.clone();
    let relations_complete = brief["deferredRelations"].list()?.is_empty();
    brief.insert(
        "presentationComplete".into(),
        (deferred.is_empty() && relations_complete).into(),
    );
    if !defer_families(source, &deferred, brief, display_bytes)? {
        return Err(invalid(
            "presentation capacity insufficient for slice identity and references",
        ));
    }
    for summary in summaries {
        let claim = summary.field("claim")?.text()?;
        deferred.retain(|s| s != &summary);
        shown.push(family(source, claim, &families[claim])?);
        brief.insert("families".into(), Data::List(shown.clone()));
        brief.insert(
            "presentationComplete".into(),
            (deferred.is_empty() && relations_complete).into(),
        );
        if !defer_families(source, &deferred, brief, display_bytes)? {
            shown.pop();
            deferred.push(summary);
            brief.insert("families".into(), Data::List(shown.clone()));
            if !defer_families(source, &deferred, brief, display_bytes)? {
                return Err(invalid("presentation references exceed display capacity"));
            }
            brief.insert("presentationComplete".into(), false.into());
        }
    }
    Ok(deferred)
}
