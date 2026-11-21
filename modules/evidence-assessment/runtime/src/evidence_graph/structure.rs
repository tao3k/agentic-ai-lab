//! Source-qualified dependency graphs. Structure alone never admits retained evidence.
use crate::{Data, Result, evidence_store::put, invalid_data as invalid};
use std::collections::{BTreeMap, BTreeSet};
pub(crate) fn index(relations: &Data) -> Result<BTreeMap<String, Data>> {
    let mut out = BTreeMap::new();
    for r in relations.list()? {
        if out
            .insert(r.field("name")?.identity()?.into(), r.clone())
            .is_some()
        {
            return Err(invalid("duplicate relation"));
        }
        r.field("source")?.boolean()?;
    }
    Ok(out)
}
pub(crate) fn dependencies(atoms: &[Data]) -> Result<BTreeSet<String>> {
    atoms
        .iter()
        .filter_map(|a| a.get("relation"))
        .map(|v| v.identity().map(str::to_string))
        .collect()
}
pub(crate) fn heads(rule: &Data) -> Result<BTreeSet<String>> {
    dependencies(rule.field("head")?.list()?)
}
pub(crate) fn strings(names: impl IntoIterator<Item = String>) -> Data {
    Data::List(names.into_iter().map(Data::from).collect())
}
pub(crate) fn texts(value: &Data) -> Result<Vec<String>> {
    value
        .list()?
        .iter()
        .map(|v| v.text().map(str::to_string))
        .collect()
}
pub(crate) fn component_rules<'a>(rules: &'a [Data], group: &[String]) -> Result<Vec<&'a Data>> {
    rules
        .iter()
        .filter_map(|r| match heads(r) {
            Ok(h) if h.iter().any(|n| group.contains(n)) => Some(Ok(r)),
            Ok(_) => None,
            Err(e) => Some(Err(e)),
        })
        .collect()
}
pub(crate) fn used(rules: &[&Data]) -> Result<BTreeSet<String>> {
    let mut out = BTreeSet::new();
    for r in rules {
        out.extend(dependencies(r.field("body")?.list()?)?);
    }
    Ok(out)
}
fn rename(value: &Data, names: &mut BTreeMap<String, String>) -> Result<Data> {
    let n = value.text()?.to_string();
    let next = names.len().to_string();
    Ok(names.entry(n).or_insert(next).clone().into())
}
/// Canonical alpha-renaming preserves tuple sharing and clause order without mutating the input.
/// # Errors
/// Rejects malformed rule/term fields.
pub fn canonical_rule(rule: &Data) -> Result<Data> {
    let mut out = rule.clone();
    let mut names = BTreeMap::<String, String>::new();
    for field in ["head", "body"] {
        let atoms = out
            .field(field)?
            .list()?
            .iter()
            .map(|a| canonical_atom(a, &mut names))
            .collect::<Result<_>>()?;
        put(&mut out, field, Data::List(atoms))?;
    }
    Ok(out)
}
fn canonical_atom(atom: &Data, names: &mut BTreeMap<String, String>) -> Result<Data> {
    let mut atom = atom.clone();
    if atom.get("mode").is_none() && atom.get("not").is_none() {
        put(&mut atom, "not", false.into())?;
    }
    let terms = atom
        .field("terms")?
        .list()?
        .iter()
        .map(|term| canonical_term(term, names))
        .collect::<Result<Vec<_>>>()?;
    put(&mut atom, "terms", Data::List(terms))?;
    if let Some(v) = atom.get("output") {
        let n = rename(v, names)?;
        put(&mut atom, "output", n)?;
    }
    if let Some(v) = atom.get("inputs") {
        let inputs = v
            .list()?
            .iter()
            .map(|v| rename(v, names))
            .collect::<Result<_>>()?;
        put(&mut atom, "inputs", Data::List(inputs))?;
    }
    Ok(atom)
}
fn canonical_term(term: &Data, names: &mut BTreeMap<String, String>) -> Result<Data> {
    let mut out = term.clone();
    if let Some(v) = term.get("var") {
        put(&mut out, "var", rename(v, names)?)?;
    }
    Ok(out)
}
/// Iterative Tarjan traversal emits sorted SCC members in dependency-first order.
/// Multi-head rules are atomic components.
/// # Errors
/// Rejects source/undeclared heads and malformed declarations.
pub fn components(program: &Data) -> Result<Vec<Vec<String>>> {
    let graph = dependency_graph(program)?;
    SccWalk::new(&graph).run()
}
fn dependency_graph(program: &Data) -> Result<BTreeMap<String, BTreeSet<String>>> {
    let declarations = index(program.field("relations")?)?;
    let mut graph = declarations
        .iter()
        .filter(|(_, r)| r.get("source") == Some(&Data::Bool(false)))
        .map(|(n, _)| (n.clone(), BTreeSet::new()))
        .collect::<BTreeMap<_, _>>();
    for rule in program.field("rules")?.list()? {
        add_dependencies(&mut graph, rule)?;
    }
    Ok(graph)
}
fn add_dependencies(graph: &mut BTreeMap<String, BTreeSet<String>>, rule: &Data) -> Result<()> {
    let head = heads(rule)?;
    let body = dependencies(rule.field("body")?.list()?)?;
    let derived = body
        .into_iter()
        .filter(|n| graph.contains_key(n))
        .collect::<Vec<_>>();
    for name in &head {
        let edges = graph
            .get_mut(name)
            .ok_or_else(|| invalid("rule head must name a declared derived relation"))?;
        edges.extend(head.iter().filter(|h| *h != name).cloned());
        edges.extend(derived.clone());
    }
    Ok(())
}
struct SccWalk {
    names: Vec<String>,
    edges: Vec<Vec<usize>>,
    indices: Vec<Option<usize>>,
    low: Vec<usize>,
    active: Vec<bool>,
    stack: Vec<usize>,
    next: usize,
    result: Vec<Vec<String>>,
}
impl SccWalk {
    fn new(graph: &BTreeMap<String, BTreeSet<String>>) -> Self {
        let names = graph.keys().cloned().collect::<Vec<_>>();
        let positions = names
            .iter()
            .enumerate()
            .map(|(i, n)| (n.clone(), i))
            .collect::<BTreeMap<_, _>>();
        let edges = names
            .iter()
            .map(|n| graph[n].iter().map(|n| positions[n]).collect())
            .collect();
        let len = names.len();
        Self {
            names,
            edges,
            indices: vec![None; len],
            low: vec![0; len],
            active: vec![false; len],
            stack: Vec::new(),
            next: 0,
            result: Vec::new(),
        }
    }
    fn enter(&mut self, node: usize) {
        self.indices[node] = Some(self.next);
        self.low[node] = self.next;
        self.next += 1;
        self.active[node] = true;
        self.stack.push(node);
    }
    fn run(mut self) -> Result<Vec<Vec<String>>> {
        for root in 0..self.names.len() {
            if self.indices[root].is_none() {
                self.visit(root)?;
            }
        }
        Ok(self.result)
    }
    fn visit(&mut self, root: usize) -> Result<()> {
        self.enter(root);
        let mut frames = vec![(root, 0)];
        while let Some((node, child)) = frames.last_mut() {
            let v = *node;
            if let Some(&w) = self.edges[v].get(*child) {
                *child += 1;
                self.edge(v, w, &mut frames)?;
            } else {
                frames.pop();
                self.finish(v)?;
                if let Some((parent, _)) = frames.last() {
                    self.low[*parent] = self.low[*parent].min(self.low[v]);
                }
            }
        }
        Ok(())
    }
    fn edge(&mut self, v: usize, w: usize, frames: &mut Vec<(usize, usize)>) -> Result<()> {
        if self.indices[w].is_none() {
            self.enter(w);
            frames.push((w, 0));
        } else if self.active[w] {
            self.low[v] = self.low[v].min(self.indices[w].ok_or_else(|| invalid("SCC index"))?);
        }
        Ok(())
    }
    fn finish(&mut self, v: usize) -> Result<()> {
        if Some(self.low[v]) != self.indices[v] {
            return Ok(());
        }
        let mut group = Vec::new();
        loop {
            let w = self.stack.pop().ok_or_else(|| invalid("SCC stack"))?;
            self.active[w] = false;
            group.push(self.names[w].clone());
            if w == v {
                break;
            }
        }
        group.sort();
        self.result.push(group);
        Ok(())
    }
}
/// Structural SCC DAG. Completion and source applicability require separate checked receipts.
/// # Errors
/// Rejects undeclared dependency edges.
pub fn evidence_graph(program: &Data) -> Result<Data> {
    let declarations = index(program.field("relations")?)?;
    let groups = components(program)?;
    let rules = program.field("rules")?.list()?;
    let mut owners = BTreeMap::new();
    let mut nodes = Vec::new();
    let mut edges = BTreeSet::new();
    for (name, r) in &declarations {
        if r.field("source")?.boolean()? {
            let id = format!("source:{name}");
            owners.insert(name.clone(), id.clone());
            nodes.push(Data::object([
                ("id", id.into()),
                ("kind", "source".into()),
                ("relations", strings([name.clone()])),
            ]));
        }
    }
    for group in &groups {
        let id = format!("component:{}", strings(group.clone()).digest());
        for n in group {
            owners.insert(n.clone(), id.clone());
        }
    }
    for group in groups {
        let id = owners[&group[0]].clone();
        let used = used(&component_rules(rules, &group)?)?;
        let members = group.iter().cloned().collect::<BTreeSet<_>>();
        let recursive = group.len() > 1 || !members.is_disjoint(&used);
        nodes.push(Data::object([
            ("id", id.clone().into()),
            ("kind", "component".into()),
            ("relations", strings(group.clone())),
            ("recursive", recursive.into()),
        ]));
        for n in used.difference(&members) {
            edges.insert((
                owners
                    .get(n)
                    .ok_or_else(|| invalid("undeclared DAG dependency"))?
                    .clone(),
                id.clone(),
            ));
        }
    }
    Ok(Data::object([
        ("schema", "ascent.evidence-dag-structure.v1".into()),
        ("nodes", Data::List(nodes)),
        (
            "edges",
            Data::List(
                edges
                    .into_iter()
                    .map(|(a, b)| Data::object([("from", a.into()), ("to", b.into())]))
                    .collect(),
            ),
        ),
    ]))
}
