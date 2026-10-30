//! Current observations retain immutable checker laws while snapshot replacement revokes claims.
use crate::{
    Data, Engine, EvidenceChain, FactLimits, Result, domain_check, domain_contract,
    evidence_store::put, invalid_data as invalid,
};
use std::{
    collections::{BTreeMap, BTreeSet},
    sync::OnceLock,
    time::Instant,
};
/// Compiled checker identity includes its native source, packet semantics and immutable dependency lock.
#[must_use]
pub fn domain_checker_version() -> &'static str {
    static VERSION: OnceLock<String> = OnceLock::new();
    VERSION.get_or_init(|| {
        format!(
            "ascent-domain-v2:{}",
            Data::List(vec![
                include_str!("domain.rs").into(),
                include_str!("lib.rs").into(),
                include_str!("../Cargo.toml").into()
            ])
            .digest()
        )
    })
}
/// Exact receipted observations remain distinct from source authenticity and implementation proofs.
pub struct DomainEvidence {
    engine: Engine,
    snapshot: String,
    retain: bool,
    observations: BTreeMap<String, Data>,
    laws: BTreeMap<String, Data>,
    chain: Option<EvidenceChain>,
    journal: Vec<Data>,
    closed: bool,
}
impl DomainEvidence {
    /// # Errors
    /// Rejects empty snapshot identities and closed engines.
    pub fn new(engine: &Engine, snapshot: &str, retain: bool) -> Result<Self> {
        engine.check()?;
        if snapshot.is_empty() {
            return Err(invalid("snapshot identity required"));
        }
        Ok(Self {
            engine: engine.clone(),
            snapshot: snapshot.into(),
            retain,
            observations: BTreeMap::new(),
            laws: BTreeMap::new(),
            chain: None,
            journal: Vec::new(),
            closed: false,
        })
    }
    fn check(&self) -> Result<()> {
        self.engine.check()?;
        if self.closed {
            Err(crate::Error::Closed)
        } else {
            Ok(())
        }
    }
    /// # Errors
    /// Rejects empty identities and revoked ownership.
    pub fn replace_snapshot(&mut self, snapshot: &str) -> Result<()> {
        self.check()?;
        if snapshot.is_empty() {
            return Err(invalid("snapshot identity required"));
        }
        if self.snapshot == snapshot {
            return Ok(());
        }
        self.close_chain();
        self.snapshot = snapshot.into();
        self.observations.clear();
        if !self.laws.is_empty() {
            self.chain = Some(EvidenceChain::new(
                &self.engine,
                self.sources()?,
                self.retain,
                FactLimits::default(),
            )?);
        }
        Ok(())
    }
    /// Check the complete observation batch before changing this snapshot's retained claims.
    /// # Errors
    /// Rejects missing receipts, duplicate IDs and invalid exact-domain observations.
    pub fn observe(&mut self, kind: &str, observations: &Data, receipt: &str) -> Result<Data> {
        self.check()?;
        let batch = CheckedBatch::new(&self.snapshot, kind, observations, receipt)?;
        let mut next = self.staged();
        next.add_observation(kind, receipt, &batch)?;
        let mut result = next.summary()?;
        batch.annotate(&mut result)?;
        self.close_chain();
        *self = next;
        Ok(result)
    }
    fn staged(&self) -> Self {
        Self {
            engine: self.engine.clone(),
            snapshot: self.snapshot.clone(),
            retain: self.retain,
            observations: self.observations.clone(),
            laws: self.laws.clone(),
            chain: None,
            journal: self.journal.clone(),
            closed: false,
        }
    }
    fn add_observation(&mut self, kind: &str, receipt: &str, batch: &CheckedBatch) -> Result<()> {
        if !self.retain {
            self.laws.clear();
            self.observations.clear();
        }
        self.laws.insert(batch.law.digest(), batch.law.clone());
        self.observations.insert(
            batch.key.clone(),
            Data::object([
                ("receipt", receipt.into()),
                ("kind", kind.into()),
                ("checks", batch.checks.clone()),
            ]),
        );
        self.chain = Some(EvidenceChain::new(
            &self.engine,
            self.sources()?,
            self.retain,
            FactLimits::default(),
        )?);
        Ok(())
    }
    /// # Errors
    /// Fails without a completed summary when evaluation is unavailable or bounded.
    pub fn summary(&mut self) -> Result<Data> {
        self.check()?;
        if self.chain.is_none() {
            return Ok(Data::object([
                ("snapshot", self.snapshot.clone().into()),
                ("checkedDomainEvidence", Data::List(Vec::new())),
                (
                    "domainContracts",
                    Data::List(self.laws.values().cloned().collect()),
                ),
            ]));
        }
        let program = domain_program(self.sources()?);
        let began = Instant::now();
        let receipt = self
            .chain
            .as_mut()
            .ok_or_else(|| invalid("missing domain chain"))?
            .query(&program)?;
        self.journal.push(Data::object([
            ("snapshot", self.snapshot.clone().into()),
            (
                "reusedComponents",
                receipt.field("reusedComponents")?.clone(),
            ),
            ("freshComponents", receipt.field("freshComponents")?.clone()),
            ("resultReference", receipt.field("resultReference")?.clone()),
            (
                "seconds",
                Data::Real(began.elapsed().as_secs_f64().to_bits()),
            ),
        ]));
        let rows = receipt.field("result")?.field("relations")?;
        let laws = rows
            .field("ReusableLaw")?
            .list()?
            .iter()
            .map(|r| {
                let row = r.list()?;
                self.laws
                    .get(row[0].text()?)
                    .cloned()
                    .ok_or_else(|| invalid("unknown completed law"))
            })
            .collect::<Result<Vec<_>>>()?;
        Ok(Data::object([("snapshot",self.snapshot.clone().into()),("checkedDomainEvidence",Data::List(self.observations.values().cloned().collect())),("domainContracts",Data::List(laws)),("passedClaims",rows.field("Passed")?.clone()),("failedClaims",rows.field("Failed")?.clone()),("resultReference",receipt.field("resultReference")?.clone()),("scope","Exact constraints over receipted observations; not a proof of all implementation behavior.".into())]))
    }
    /// # Errors
    /// Rejects stale references, nonunary projections and revoked owners.
    pub fn answer(&self, reference: &str, relation: &str) -> Result<Data> {
        self.check()?;
        self.chain
            .as_ref()
            .ok_or_else(|| invalid("unknown result reference"))?
            .answer(reference, relation)
    }
    /// # Errors
    /// Rejects revoked observation owners before exposing their checker contract.
    pub fn checker_version(&self) -> Result<&'static str> {
        self.check()?;
        Ok(domain_checker_version())
    }
    #[must_use]
    pub fn journal(&self) -> &[Data] {
        &self.journal
    }
    fn close_chain(&mut self) {
        if let Some(mut chain) = self.chain.take() {
            chain.close();
        }
    }
    pub fn close(&mut self) {
        self.close_chain();
        self.observations.clear();
        self.laws.clear();
        self.closed = true;
    }
    fn sources(&self) -> Result<Data> {
        let claims = self
            .observations
            .iter()
            .map(|(key, o)| observation_claims(key, o))
            .collect::<Result<Vec<_>>>()?
            .into_iter()
            .flatten()
            .collect();
        Ok(Data::List(vec![
            declaration(
                "Snapshot",
                &["symbol"],
                true,
                vec![vec![self.snapshot.clone().into()]],
            ),
            declaration("ObservedClaim", &["symbol", "boolean"], true, claims),
            declaration(
                "Checker",
                &["symbol"],
                true,
                vec![vec![domain_checker_version().into()]],
            ),
            declaration(
                "CheckedLaw",
                &["symbol", "symbol"],
                true,
                self.laws
                    .iter()
                    .map(|(key, law)| {
                        vec![
                            key.clone().into(),
                            law.get("checkerVersion").cloned().unwrap_or(Data::Null),
                        ]
                    })
                    .collect(),
            ),
        ]))
    }
}
fn observation_claims(key: &str, observation: &Data) -> Result<Vec<Vec<Data>>> {
    observation
        .field("checks")?
        .list()?
        .iter()
        .map(|check| check_claims(key, check))
        .collect::<Result<Vec<_>>>()
        .map(|rows| rows.into_iter().flatten().collect())
}
fn check_claims(key: &str, check: &Data) -> Result<Vec<Vec<Data>>> {
    check
        .field("claims")?
        .list()?
        .iter()
        .map(|c| {
            let c = c.list()?;
            if c.len() != 2 {
                return Err(invalid("domain claim shape"));
            }
            let claim =
                Data::List(vec![key.into(), check.field("id")?.clone(), c[0].clone()]).digest();
            Ok(vec![claim.into(), c[1].clone()])
        })
        .collect()
}
fn declaration(name: &str, kinds: &[&str], source: bool, rows: Vec<Vec<Data>>) -> Data {
    Data::object([
        ("name", name.into()),
        (
            "columns",
            Data::List(
                kinds
                    .iter()
                    .map(|kind| Data::object([("kind", (*kind).into())]))
                    .collect(),
            ),
        ),
        ("source", source.into()),
        (
            "rows",
            Data::List(rows.into_iter().map(Data::List).collect()),
        ),
    ])
}
fn atom(name: &str, terms: Vec<Data>) -> Data {
    Data::object([("relation", name.into()), ("terms", Data::List(terms))])
}
fn var(name: &str) -> Data {
    Data::object([("var", name.into())])
}
fn rule(head: Data, body: Vec<Data>) -> Data {
    Data::object([("head", Data::List(vec![head])), ("body", Data::List(body))])
}
fn domain_program(sources: Data) -> Data {
    let Data::List(mut relations) = sources else {
        unreachable!("validated source declarations")
    };
    relations.extend(
        ["Passed", "Failed", "ReusableLaw"]
            .into_iter()
            .map(|n| declaration(n, &["symbol"], false, Vec::new())),
    );
    let mut rules = [("Passed", true), ("Failed", false)]
        .into_iter()
        .map(|(name, value)| {
            rule(
                atom(name, vec![var("c")]),
                vec![atom(
                    "ObservedClaim",
                    vec![var("c"), Data::object([("const", value.into())])],
                )],
            )
        })
        .collect::<Vec<_>>();
    rules.push(rule(
        atom("ReusableLaw", vec![var("c")]),
        vec![
            atom("CheckedLaw", vec![var("c"), var("v")]),
            atom("Checker", vec![var("v")]),
        ],
    ));
    Data::object([
        ("relations", Data::List(relations)),
        ("rules", Data::List(rules)),
        (
            "queries",
            Data::List(
                ["Passed", "Failed", "ReusableLaw"]
                    .into_iter()
                    .map(Data::from)
                    .collect(),
            ),
        ),
    ])
}

struct CheckedBatch {
    key: String,
    law: Data,
    checks: Data,
    seconds: Data,
}
impl CheckedBatch {
    fn new(snapshot: &str, kind: &str, observations: &Data, receipt: &str) -> Result<Self> {
        if receipt.is_empty() {
            return Err(invalid("an observation receipt identity is required"));
        }
        let rows = observations.list()?;
        let ids = rows
            .iter()
            .map(|r| {
                r.list()?
                    .first()
                    .ok_or_else(|| invalid("observation ID required"))?
                    .identity()
                    .map(str::to_string)
            })
            .collect::<Result<BTreeSet<_>>>()?;
        if ids.len() != rows.len() || ids.is_empty() {
            return Err(invalid("unique nonempty observation IDs required"));
        }
        let began = Instant::now();
        let checks = domain_check(kind, observations)?;
        let seconds = Data::Real(began.elapsed().as_secs_f64().to_bits());
        let law = Data::object([
            ("kind", kind.into()),
            ("checkerVersion", domain_checker_version().into()),
            ("contract", domain_contract(kind)?.into()),
        ]);
        let key = Data::object([
            ("snapshot", snapshot.into()),
            ("receipt", receipt.into()),
            ("checker", domain_checker_version().into()),
            ("kind", kind.into()),
            ("observations", observations.clone()),
        ])
        .digest();
        Ok(Self {
            key,
            law,
            checks,
            seconds,
        })
    }
    fn annotate(self, result: &mut Data) -> Result<()> {
        put(result, "currentChecks", self.checks)?;
        put(result, "observationIdentity", self.key.into())?;
        put(result, "checkerSeconds", self.seconds)
    }
}
