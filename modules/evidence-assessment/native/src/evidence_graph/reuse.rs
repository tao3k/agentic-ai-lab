//! Source-bound component certificates and checked lowering; a key alone authorizes nothing.
use super::{canonical_rule, component_rules, components, heads, index, strings, texts, used};
use crate::{Data, Result, evidence_store::put, invalid_data as invalid};
use std::collections::{BTreeMap, BTreeSet};
struct Context<'a> {
    request: &'a Data,
    program: &'a Data,
    trusted: &'a BTreeMap<String, Data>,
    certificates: &'a BTreeMap<String, Data>,
    base: BTreeSet<String>,
    declarations: BTreeMap<String, Data>,
    source: &'a str,
    retain: bool,
}
#[derive(Default)]
struct Assembly {
    keys: BTreeMap<String, Data>,
    mapping: BTreeMap<String, Data>,
    groups: Vec<Data>,
    reused: Vec<Data>,
    fresh: Vec<Data>,
}
/// Lower only components carrying complete certificates under the exact current source.
/// # Errors
/// Rejects changed source authority, missing dependencies and malformed certificates.
pub fn query_graph(request: &Data) -> Result<Data> {
    let context = Context::read(request)?;
    let mut state = Assembly::default();
    for group in components(context.program)? {
        state.admit(&context, &group)?;
    }
    state.finish(&context)
}
impl<'a> Context<'a> {
    fn read(request: &'a Data) -> Result<Self> {
        let program = request.field("program")?;
        let trusted = request.field("trusted")?.map()?;
        let base = texts(request.field("sources")?)?
            .into_iter()
            .collect::<BTreeSet<_>>();
        let declared = index(program.field("relations")?)?;
        let declarations = declared
            .iter()
            .filter_map(|(n, r)| match authority(n, r, trusted) {
                Ok(true) => Some(Ok((n.clone(), r.clone()))),
                Ok(false) => None,
                Err(e) => Some(Err(e)),
            })
            .collect::<Result<BTreeMap<_, _>>>()?;
        if !base.iter().all(|n| declared.contains_key(n)) {
            return Err(invalid("query omitted source authority"));
        }
        for rule in program.field("rules")?.list()? {
            validate_head(rule, trusted)?;
        }
        Ok(Self {
            request,
            program,
            trusted,
            certificates: request.field("certificates")?.map()?,
            base,
            declarations,
            source: request.field("sourceIdentity")?.identity()?,
            retain: request.field("retain")?.boolean()?,
        })
    }
}
fn authority(name: &str, relation: &Data, trusted: &BTreeMap<String, Data>) -> Result<bool> {
    if let Some(authority) = trusted.get(name) {
        if relation != authority {
            return Err(invalid("query changed source authority"));
        }
        return Ok(false);
    }
    if relation.field("source")?.boolean()?
        || relation
            .get("rows")
            .map(Data::list)
            .transpose()?
            .is_some_and(|r| !r.is_empty())
    {
        return Err(invalid("derived evidence cannot introduce source facts"));
    }
    Ok(true)
}
fn validate_head(rule: &Data, trusted: &BTreeMap<String, Data>) -> Result<()> {
    if heads(rule)?.iter().any(|n| trusted.contains_key(n)) {
        return Err(invalid("query defines source heads"));
    }
    Ok(())
}
impl Assembly {
    fn admit(&mut self, ctx: &Context<'_>, group: &[String]) -> Result<()> {
        let (key, descriptor) = describe(
            ctx.program,
            group,
            &ctx.declarations,
            &self.keys,
            ctx.trusted,
            ctx.source,
        )?;
        let aliases = if ctx.retain {
            ctx.certificates.get(&key).map(Data::map).transpose()?
        } else {
            None
        };
        let aliases = aliases.filter(|aliases| aliases_complete(group, aliases, ctx));
        self.keys
            .extend(group.iter().cloned().map(|n| (n, key.clone().into())));
        self.groups.push(descriptor.clone());
        match aliases {
            Some(aliases) => {
                self.mapping
                    .extend(group.iter().map(|n| (n.clone(), aliases[n].clone())));
                self.reused.push(descriptor);
            }
            None => self.fresh.push(descriptor),
        }
        Ok(())
    }
    fn finish(mut self, ctx: &Context<'_>) -> Result<Data> {
        let lowered = lower(ctx.program, &ctx.declarations, &self.mapping)?;
        let key = ctx.program.digest();
        let lowered = self.cached(ctx, &key, lowered)?;
        Ok(Data::object([
            ("graphVersion", "evidence-dag-v1".into()),
            ("requestKey", key.into()),
            ("lowered", lowered),
            ("mapping", Data::Map(self.mapping)),
            ("groups", Data::List(self.groups)),
            ("keys", Data::Map(self.keys)),
            ("reused", Data::List(self.reused)),
            ("fresh", Data::List(self.fresh)),
        ]))
    }
    fn cached(&mut self, ctx: &Context<'_>, key: &str, lowered: Data) -> Result<Data> {
        if !ctx.retain {
            return Ok(lowered);
        }
        let Some(cached) = ctx.request.get("requests").and_then(|v| v.get(key)) else {
            return Ok(lowered);
        };
        let values = cached.list()?;
        if values.len() != 2 {
            return Err(invalid("cached request shape"));
        }
        let mapping = values[1].map()?;
        if mapping
            .values()
            .any(|a| a.text().is_err() || !ctx.trusted.contains_key(a.text().unwrap_or("")))
        {
            return Err(invalid("stale cached request"));
        }
        self.mapping = mapping.clone();
        Ok(values[0].clone())
    }
}
fn aliases_complete(group: &[String], aliases: &BTreeMap<String, Data>, ctx: &Context<'_>) -> bool {
    group.iter().all(|n| {
        aliases
            .get(n)
            .and_then(|a| a.text().ok())
            .is_some_and(|alias| !ctx.base.contains(alias) && ctx.trusted.contains_key(alias))
    })
}
fn lower(
    program: &Data,
    declarations: &BTreeMap<String, Data>,
    mapping: &BTreeMap<String, Data>,
) -> Result<Data> {
    let rules = program.field("rules")?.list()?;
    let mut lowered = program.clone();
    put(
        &mut lowered,
        "relations",
        Data::List(
            program
                .field("relations")?
                .list()?
                .iter()
                .filter(|r| {
                    r.get("name")
                        .and_then(|n| n.text().ok())
                        .is_none_or(|n| !mapping.contains_key(n))
                })
                .cloned()
                .collect(),
        ),
    )?;
    let mut retained = Vec::new();
    for rule in rules {
        if mapped_head(rule, mapping)? {
            continue;
        }
        let mut rule = rule.clone();
        let mut body = rule.field("body")?.list()?.to_vec();
        for atom in &mut body {
            if let Some(n) = atom.get("relation").and_then(|v| v.text().ok())
                && let Some(alias) = mapping.get(n)
            {
                let alias = alias.clone();
                put(atom, "relation", alias)?;
            }
        }
        put(&mut rule, "body", Data::List(body))?;
        retained.push(rule);
    }
    put(&mut lowered, "rules", Data::List(retained))?;
    let wanted = texts(program.field("queries")?)?;
    let mut seen = BTreeSet::new();
    let mut queries = Vec::new();
    for n in wanted.into_iter().chain(declarations.keys().cloned()) {
        let alias = mapping.get(&n).cloned().unwrap_or_else(|| n.into());
        let text = alias.text()?.to_string();
        if seen.insert(text) {
            queries.push(alias);
        }
    }
    put(&mut lowered, "queries", Data::List(queries))?;
    Ok(lowered)
}
fn describe(
    program: &Data,
    group: &[String],
    declarations: &BTreeMap<String, Data>,
    keys: &BTreeMap<String, Data>,
    trusted: &BTreeMap<String, Data>,
    source: &str,
) -> Result<(String, Data)> {
    let rules = program.field("rules")?.list()?;
    let rules = component_rules(rules, group)?;
    let used = used(&rules)?;
    let members = group.iter().cloned().collect::<BTreeSet<_>>();
    let external = used.difference(&members).cloned().collect::<Vec<_>>();
    let deps = external
        .iter()
        .map(|n| {
            keys.get(n)
                .cloned()
                .or_else(|| trusted.get(n).map(|v| Data::from(v.digest())))
                .map(|v| (n.clone(), v))
                .ok_or_else(|| invalid("undeclared component dependency"))
        })
        .collect::<Result<BTreeMap<String, Data>>>()?;
    let mut canonical = rules
        .iter()
        .map(|r| canonical_rule(r))
        .collect::<Result<Vec<_>>>()?;
    canonical.sort_by_cached_key(Data::digest);
    let relation_values = group
        .iter()
        .map(|n| {
            declarations
                .get(n)
                .cloned()
                .ok_or_else(|| invalid("untrusted component declaration"))
        })
        .collect::<Result<Vec<_>>>()?;
    let key = Data::object([
        ("graphVersion", "evidence-dag-v1".into()),
        ("sourceIdentity", source.into()),
        ("relations", Data::List(relation_values)),
        ("rules", Data::List(canonical)),
        ("dependencies", Data::Map(deps)),
    ])
    .digest();
    let descriptor = Data::object([
        ("relations", strings(group.to_vec())),
        ("fingerprint", key.clone().into()),
        (
            "recursive",
            (group.len() > 1 || !members.is_disjoint(&used)).into(),
        ),
        ("dependencies", strings(external)),
    ]);
    Ok((key, descriptor))
}

fn mapped_head(rule: &Data, mapping: &BTreeMap<String, Data>) -> Result<bool> {
    Ok(heads(rule)?.iter().any(|n| mapping.contains_key(n)))
}
