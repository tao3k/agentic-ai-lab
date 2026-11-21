//! Completed component certificates, current result references and checked continuations.
use crate::{
    Data, Engine, EvidenceStore, FactLimits, Result, evidence_graph, evidence_store::put,
    invalid_data as invalid,
};
use std::collections::{BTreeMap, BTreeSet};
/// A source-generation owner. Private certificates are minted only after complete evaluation.
pub struct EvidenceChain {
    engine: Engine,
    store: EvidenceStore,
    retain: bool,
    limits: FactLimits,
    certificates: BTreeMap<String, Data>,
    requests: BTreeMap<String, Data>,
    results: BTreeMap<String, Data>,
}
impl EvidenceChain {
    /// # Errors
    /// Rejects inadmissible trusted source schemas/facts or a closed engine.
    pub fn new(engine: &Engine, sources: Data, retain: bool, limits: FactLimits) -> Result<Self> {
        Ok(Self {
            engine: engine.clone(),
            store: EvidenceStore::new(engine, sources, limits)?,
            retain,
            limits,
            certificates: BTreeMap::new(),
            requests: BTreeMap::new(),
            results: BTreeMap::new(),
        })
    }
    #[must_use]
    pub fn source_identity(&self) -> String {
        self.store.source_identity()
    }
    /// Observe the admitted source snapshot, never mutable store internals.
    #[must_use]
    pub fn sources(&self) -> &Data {
        self.store.sources()
    }
    /// # Errors
    /// Rejects unknown sources and revoked materializations.
    pub fn scan(&self, names: &[String]) -> Result<Data> {
        self.store.scan(names)
    }
    /// # Errors
    /// Rechecks every source and rule; exhaustion never mints a completed certificate.
    pub fn query(&mut self, program: &Data) -> Result<Data> {
        let sources = self.store.sources().clone();
        let mut trusted = self.store.materialized().clone();
        let mut source_names = Vec::new();
        for r in sources.list()? {
            let n = r.field("name")?.identity()?.to_string();
            trusted.insert(n.clone(), r.clone());
            source_names.push(n.into());
        }
        let declarations = program
            .field("relations")?
            .list()?
            .iter()
            .filter(|r| r.get("source") == Some(&Data::Bool(false)))
            .map(|r| Ok((r.field("name")?.text()?.to_string(), r.clone())))
            .collect::<Result<BTreeMap<_, _>>>()?;
        let graph = evidence_graph::query_graph(&Data::object([
            ("program", program.clone()),
            ("trusted", Data::Map(trusted)),
            ("sources", Data::List(source_names)),
            ("certificates", Data::Map(self.certificates.clone())),
            ("requests", Data::Map(self.requests.clone())),
            ("sourceIdentity", self.source_identity().into()),
            ("retain", self.retain.into()),
        ]))?;
        let mapping = graph.field("mapping")?.map()?;
        let lowered = graph.field("lowered")?.clone();
        let receipt = self.store.query(lowered.clone())?;
        let aliases = receipt
            .field("publishedEvidence")?
            .list()?
            .iter()
            .map(|p| {
                Ok((
                    p.field("originRelation")?.text()?.to_string(),
                    p.field("relation")?.clone(),
                ))
            })
            .collect::<Result<BTreeMap<_, _>>>()?;
        let mut certificates = self.certificates.clone();
        if self.retain {
            for descriptor in graph.field("groups")?.list()? {
                let key = descriptor.field("fingerprint")?.text()?;
                if !certificates.contains_key(key) {
                    let cert = descriptor
                        .field("relations")?
                        .list()?
                        .iter()
                        .map(|n| {
                            let n = n.text()?;
                            mapping
                                .get(n)
                                .or_else(|| aliases.get(n))
                                .cloned()
                                .map(|alias| (n.into(), alias))
                                .ok_or_else(|| invalid("component lacks completed alias"))
                        })
                        .collect::<Result<_>>()?;
                    certificates.insert(key.into(), Data::Map(cert));
                }
            }
        }
        let (handle, retained, feedback) =
            self.reference(program, &declarations, &graph, &receipt)?;
        if self.retain {
            self.requests.insert(
                graph.field("requestKey")?.text()?.into(),
                Data::List(vec![lowered, Data::Map(mapping.clone())]),
            );
            self.certificates = certificates;
        } else {
            let replacement = EvidenceStore::new(&self.engine, sources, self.limits)?;
            self.store.close();
            self.store = replacement;
        }
        self.results.insert(handle, retained);
        Ok(feedback)
    }
    fn reference(
        &self,
        program: &Data,
        declarations: &BTreeMap<String, Data>,
        graph: &Data,
        receipt: &Data,
    ) -> Result<(String, Data, Data)> {
        let mapping = graph.field("mapping")?.map()?;
        let rows = receipt.field("result")?.field("relations")?.map()?;
        let wanted = program.field("queries")?.list()?;
        let mut result = BTreeMap::new();
        let mut columns = BTreeMap::new();
        for name in wanted {
            let n = name.text()?;
            let alias = mapping.get(n).map(Data::text).transpose()?.unwrap_or(n);
            result.insert(
                n.into(),
                rows.get(alias)
                    .ok_or_else(|| invalid("completed query missing"))?
                    .clone(),
            );
            if let Some(r) = declarations.get(n) {
                columns.insert(n.into(), r.field("columns")?.clone());
            }
        }
        let handle = Data::object([
            ("sourceIdentity", self.source_identity().into()),
            ("pathIdentity", receipt.field("pathIdentity")?.clone()),
            ("queries", Data::List(wanted.to_vec())),
        ])
        .digest();
        let retained = Data::object([
            ("sourceIdentity", self.source_identity().into()),
            ("relations", Data::Map(result.clone())),
            ("columns", Data::Map(columns)),
            ("components", graph.field("groups")?.clone()),
            (
                "componentColumns",
                Data::Map(
                    declarations
                        .iter()
                        .map(|(n, r)| r.field("columns").map(|v| (n.clone(), v.clone())))
                        .collect::<Result<_>>()?,
                ),
            ),
            ("pathIdentity", receipt.field("pathIdentity")?.clone()),
        ]);
        let claims = if self.retain {
            declarations
                .keys()
                .map(|n| {
                    let alias = mapping.get(n).map(Data::text).transpose()?.unwrap_or(n);
                    Ok(Data::object([
                        ("name", n.clone().into()),
                        ("fingerprint", graph.field("keys")?.field(n)?.clone()),
                        (
                            "rows",
                            rows.get(alias)
                                .ok_or_else(|| invalid("missing completed claim"))?
                                .list()?
                                .len()
                                .into(),
                        ),
                    ]))
                })
                .collect::<Result<Vec<_>>>()?
        } else {
            Vec::new()
        };
        let feedback = Data::object([
            ("sourceIdentity", self.source_identity().into()),
            ("resultReference", handle.clone().into()),
            ("pathIdentity", receipt.field("pathIdentity")?.clone()),
            (
                "result",
                Data::object([("complete", true.into()), ("relations", Data::Map(result))]),
            ),
            ("reusedComponents", graph.field("reused")?.clone()),
            ("freshComponents", graph.field("fresh")?.clone()),
            (
                "retainedCompleted",
                receipt.field("retainedCompleted")?.clone(),
            ),
            ("availableClaims", Data::List(claims)),
            ("evaluated", receipt.field("evaluated")?.clone()),
            ("evaluationCount", receipt.field("evaluationCount")?.clone()),
        ]);
        Ok((handle, retained, feedback))
    }
    fn current(&self, reference: &str) -> Result<&Data> {
        self.engine.check()?;
        let result = self
            .results
            .get(reference)
            .ok_or_else(|| invalid("unknown result reference"))?;
        if result.field("sourceIdentity")?.text()? != self.source_identity() {
            return Err(invalid("stale result reference"));
        }
        Ok(result)
    }
    /// # Errors
    /// Rejects stale references or projections other than a unary derived query.
    pub fn answer(&self, reference: &str, relation: &str) -> Result<Data> {
        let result = self.current(reference)?;
        if result
            .field("columns")?
            .get(relation)
            .map(Data::list)
            .transpose()?
            .is_none_or(|v| v.len() != 1)
        {
            return Err(invalid(
                "answer reference must select a unary derived relation",
            ));
        }
        Ok(result.field("relations")?.field(relation)?.clone())
    }
    /// # Errors
    /// Rejects requested answers, duplicate names and components without current certificates.
    pub fn intermediates(&self, reference: &str, names: &[String]) -> Result<Data> {
        let result = self.current(reference)?;
        if !self.retain
            || names.is_empty()
            || names.iter().collect::<BTreeSet<_>>().len() != names.len()
            || names.iter().any(|n| {
                result
                    .field("relations")
                    .ok()
                    .and_then(|v| v.get(n))
                    .is_some()
            })
        {
            return Err(invalid("select distinct completed intermediate relations"));
        }
        let selected =
            self.select_intermediates(result, &names.iter().map(String::as_str).collect())?;
        if selected.len() != names.len() {
            return Err(invalid("intermediate relation is not currently completed"));
        }
        let scanned = self.scan(
            &selected
                .values()
                .map(|(_, a)| a.clone())
                .collect::<Vec<_>>(),
        )?;
        Ok(Data::object([
            ("schema", "ascent.intermediate-evidence.v1".into()),
            ("sourceIdentity", self.source_identity().into()),
            ("resultReference", reference.into()),
            ("pathIdentity", result.field("pathIdentity")?.clone()),
            (
                "componentFingerprints",
                Data::Map(
                    selected
                        .iter()
                        .map(|(n, (k, _))| (n.clone(), k.clone().into()))
                        .collect(),
                ),
            ),
            (
                "columns",
                Data::Map(
                    names
                        .iter()
                        .map(|n| {
                            result
                                .field("componentColumns")?
                                .field(n)
                                .map(|v| (n.clone(), v.clone()))
                        })
                        .collect::<Result<_>>()?,
                ),
            ),
            (
                "facts",
                Data::Map(
                    selected
                        .iter()
                        .map(|(n, (_, a))| {
                            scanned
                                .field("relations")?
                                .field(a)
                                .map(|v| (n.clone(), v.clone()))
                        })
                        .collect::<Result<_>>()?,
                ),
            ),
        ]))
    }
    fn select_intermediates(
        &self,
        result: &Data,
        names: &BTreeSet<&str>,
    ) -> Result<BTreeMap<String, (String, String)>> {
        let entries = result
            .field("components")?
            .list()?
            .iter()
            .map(|descriptor| self.select_component(descriptor, names))
            .collect::<Result<Vec<_>>>()?;
        let selected = entries.into_iter().flatten().collect();
        Ok(selected)
    }
    fn select_component(
        &self,
        descriptor: &Data,
        names: &BTreeSet<&str>,
    ) -> Result<Vec<(String, (String, String))>> {
        let key = descriptor.field("fingerprint")?.text()?;
        let Some(certificate) = self.certificates.get(key) else {
            return Ok(Vec::new());
        };
        descriptor
            .field("relations")?
            .list()?
            .iter()
            .filter_map(|name| match name.text() {
                Ok(n) if names.contains(n) => certificate.get(n).map(|alias| {
                    alias
                        .text()
                        .map(|a| (n.to_string(), (key.to_string(), a.to_string())))
                }),
                Ok(_) => None,
                Err(e) => Some(Err(e)),
            })
            .collect()
    }
    /// # Errors
    /// Rejects invalid replacement before revoking the current generation.
    pub fn replace(&mut self, sources: Data) -> Result<()> {
        self.store.replace(sources)?;
        self.certificates.clear();
        self.requests.clear();
        self.results.clear();
        Ok(())
    }
    /// # Errors
    /// Rejects stale consumption references and bounded equivalence-search exhaustion.
    pub fn consume(
        &mut self,
        reference: &str,
        program: &Data,
        contract: &Data,
        interpretation: Data,
    ) -> Result<Data> {
        if !self.retain {
            return Err(invalid("consumption requires current retained evidence"));
        }
        self.current(reference)?;
        let mut admission = evidence_graph::check_continuation(program, contract)?;
        if !admission.field("accepted")?.boolean()? {
            return Ok(admission);
        }
        let feedback = self.query(&evidence_graph::normalize_contract(contract)?)?;
        for (k, v) in feedback.map()? {
            put(&mut admission, k, v.clone())?;
        }
        put(&mut admission, "consumedReference", reference.into())?;
        put(&mut admission, "interpretation", interpretation)?;
        put(
            &mut admission,
            "admissionScope",
            "closed-query-against-trusted-task-contract".into(),
        )?;
        put(
            &mut admission,
            "naturalLanguageEquivalenceProved",
            false.into(),
        )?;
        Ok(admission)
    }
    pub fn close(&mut self) {
        self.store.close();
        self.certificates.clear();
        self.results.clear();
        self.requests.clear();
    }
}
