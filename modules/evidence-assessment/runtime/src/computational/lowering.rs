//! Inert candidate data is lowered directly to typed rules; proposal procedures never run.
use crate::{
    Atom, Clause, Data, Expression, FactLimits, Operator, Program, Reducer, Relation, Result, Rule,
    Term, Type, Value, invalid_data as invalid,
};
use std::collections::BTreeMap;
pub(super) struct Candidate {
    pub program: Program,
    pub query: Atom,
}
fn label(value: &Data) -> Result<&str> {
    let name = value.identity()?;
    if name.chars().count() > 128 {
        return Err(invalid("candidate name bound"));
    }
    Ok(name)
}
fn scalar(value: &Data) -> Result<Value> {
    match value {
        Data::Integer(v) => Ok(Value::Integer(v.clone())),
        Data::Bool(v) => Ok(Value::Boolean(*v)),
        Data::Text(v) if v != "?" && !v.starts_with('?') => Ok(Value::Symbol(label(value)?.into())),
        _ => Err(invalid("ground candidate scalar required")),
    }
}
fn term(value: &Data, names: &mut BTreeMap<String, u32>) -> Result<Term> {
    if let Data::Text(n) = value {
        if n == "?_" {
            return Ok(Term::Wildcard);
        }
        if n.starts_with('?') && n.len() > 1 {
            label(value)?;
            let next =
                u32::try_from(names.len()).map_err(|_| invalid("candidate variable bound"))?;
            return Ok(Term::Variable(*names.entry(n.clone()).or_insert(next)));
        }
    }
    scalar(value).map(Term::Literal)
}
fn atom(value: &Data, names: &mut BTreeMap<String, u32>) -> Result<Atom> {
    let cells = value.list()?;
    let (name, terms) = cells
        .split_first()
        .ok_or_else(|| invalid("candidate atom required"))?;
    Ok(Atom::new(
        label(name)?,
        terms
            .iter()
            .map(|v| term(v, names))
            .collect::<Result<Vec<_>>>()?,
    ))
}
fn expression(value: &Data, names: &mut BTreeMap<String, u32>) -> Result<Expression> {
    let form = value.list()?;
    let (op, args) = form
        .split_first()
        .ok_or_else(|| invalid("candidate operator form required"))?;
    let operator = Operator::named(op.text()?)
        .filter(|op| {
            matches!(
                op,
                Operator::Even | Operator::Less | Operator::Identity | Operator::Add
            )
        })
        .ok_or_else(|| invalid("unsupported candidate operator"))?;
    let terms = args
        .iter()
        .map(|v| {
            let t = term(v, names)?;
            if !matches!(t, Term::Variable(_)) {
                return Err(invalid("candidate operator inputs must be bound variables"));
            }
            Ok(Expression::Term(t))
        })
        .collect::<Result<_>>()?;
    Ok(Expression::Call(operator, terms))
}
fn output(value: &Data, names: &mut BTreeMap<String, u32>) -> Result<u32> {
    if let Term::Variable(n) = term(value, names)? {
        Ok(n)
    } else {
        Err(invalid("candidate output variable required"))
    }
}
fn clause(value: &Data, names: &mut BTreeMap<String, u32>) -> Result<Clause> {
    let form = value.list()?;
    let op = form
        .first()
        .ok_or_else(|| invalid("candidate body clause required"))?
        .text()?;
    match (op, form) {
        ("not", [_, target]) => Ok(Clause::Relation {
            atom: atom(target, names)?,
            negative: true,
        }),
        ("where", [_, form]) => {
            let expression = expression(form, names)?;
            if !matches!(
                expression,
                Expression::Call(Operator::Even | Operator::Less, _)
            ) {
                return Err(invalid("unsupported candidate predicate"));
            }
            Ok(Clause::Guard {
                inputs: Vec::new(),
                expression,
            })
        }
        ("compute", [_, out, form]) => {
            let expression = expression(form, names)?;
            if !matches!(
                expression,
                Expression::Call(Operator::Add | Operator::Identity, _)
            ) {
                return Err(invalid("unsupported candidate computation"));
            }
            Ok(Clause::Compute {
                inputs: Vec::new(),
                expression,
                output: output(out, names)?,
            })
        }
        ("reduce", [_, out, mode, target]) => {
            let mode = mode.list()?;
            let (op, inputs) = mode
                .split_first()
                .ok_or_else(|| invalid("candidate reducer required"))?;
            let operator = Reducer::named(op.text()?)
                .filter(|r| !matches!(r, Reducer::Mean))
                .ok_or_else(|| invalid("unsupported candidate reducer"))?;
            let atom = atom(target, names)?;
            let inputs = inputs
                .iter()
                .map(|v| output(v, names))
                .collect::<Result<_>>()?;
            Ok(Clause::Reduce {
                operator,
                atom,
                inputs,
                output: output(out, names)?,
            })
        }
        ("not" | "where" | "compute" | "reduce", _) => Err(invalid("candidate clause shape")),
        _ => Ok(Clause::Relation {
            atom: atom(value, names)?,
            negative: false,
        }),
    }
}
fn limit(value: &Data) -> Result<Option<usize>> {
    if value == &Data::Text("unlimited".into()) {
        return Ok(None);
    }
    let n = value.index()?;
    if n == 0 {
        return Err(invalid("positive candidate fact limits required"));
    }
    Ok(Some(n))
}
pub(super) fn read(source: &Data, candidate: &Data) -> Result<Candidate> {
    source.field("identity")?.identity()?;
    source.field("generation")?.natural()?;
    let (mut program, mut schema) = source_program(source)?;
    let forms = candidate.list()?;
    if forms.first() != Some(&Data::Text("candidate".into())) || forms.len() > 257 {
        return Err(invalid("inert candidate list required"));
    }
    let mut query = None;
    let mut limits = None;
    let mut rules = Vec::new();
    let mut facts = Vec::new();
    for form in &forms[1..] {
        let fields = form.list()?;
        match fields.first().map(Data::text).transpose()?.unwrap_or("") {
            "relation" => {
                let [_, name, arity] = fields else {
                    return Err(invalid("candidate relation shape"));
                };
                let name = label(name)?;
                let arity = arity.index()?;
                if arity > 16 || schema.insert(name.into(), false).is_some() {
                    return Err(invalid("duplicate candidate relation or arity bound"));
                }
                program
                    .relations
                    .push(Relation::new(name, vec![Type::Scalar; arity], false));
            }
            "rule" => {
                let [_, head, body @ ..] = fields else {
                    return Err(invalid("candidate rule shape"));
                };
                if body.is_empty() {
                    return Err(invalid("candidate rule body required"));
                }
                rules.push((head, body));
            }
            "fact" => {
                let [_, name, values @ ..] = fields else {
                    return Err(invalid("candidate fact shape"));
                };
                facts.push((label(name)?.to_string(), values));
            }
            "query" => {
                if query.is_some() || fields.len() < 2 {
                    return Err(invalid("duplicate or malformed candidate query"));
                }
                query = Some(Data::List(fields[1..].to_vec()));
            }
            "limits" => {
                let [_, input, derived, out] = fields else {
                    return Err(invalid("candidate limits shape"));
                };
                if limits.is_some() {
                    return Err(invalid("duplicate candidate limits"));
                }
                limits = Some(FactLimits {
                    input: limit(input)?,
                    derived: limit(derived)?,
                    output: limit(out)?,
                });
            }
            _ => return Err(invalid("unsupported candidate construct")),
        }
    }
    if program.relations.len() > 64 || rules.len() > 128 {
        return Err(invalid("candidate declaration bound"));
    }
    source_facts(&mut program, &schema, &facts)?;
    for (head, body) in rules {
        let mut names = BTreeMap::new();
        let body = body
            .iter()
            .map(|v| clause(v, &mut names))
            .collect::<Result<Vec<_>>>()?;
        let head = atom(head, &mut names)?;
        program.rules.push(Rule { head, body });
    }
    program.fact_limits = limits.ok_or_else(|| invalid("candidate limits required"))?;
    let query = atom(
        &query.ok_or_else(|| invalid("candidate query required"))?,
        &mut BTreeMap::new(),
    )?;
    let relation = program
        .relations
        .iter()
        .find(|r| r.name == query.relation)
        .ok_or_else(|| invalid("unknown candidate query"))?;
    if relation.columns.len() != query.terms.len() {
        return Err(invalid("candidate query arity"));
    }
    Ok(Candidate { program, query })
}
pub(super) fn matches(query: &Atom, row: &[Value]) -> bool {
    let mut bound = BTreeMap::new();
    query.terms.iter().zip(row).all(|(term, value)| match term {
        Term::Literal(v) => v == value,
        Term::Wildcard => true,
        Term::Variable(v) => bound.insert(*v, value).is_none_or(|old| old == value),
    })
}

fn source_program(source: &Data) -> Result<(Program, BTreeMap<String, bool>)> {
    let mut program = Program::default();
    let mut schema = BTreeMap::new();
    for entry in source.field("relations")?.list()? {
        let entry = entry.list()?;
        let [name, arity, rows] = entry else {
            return Err(invalid("source snapshot relation shape"));
        };
        let name = label(name)?;
        let arity = arity.index()?;
        if arity > 16 || schema.insert(name.to_string(), true).is_some() {
            return Err(invalid("duplicate source relation or arity bound"));
        }
        let mut relation = Relation::new(name, vec![Type::Scalar; arity], true);
        relation.rows = rows
            .list()?
            .iter()
            .map(|r| {
                r.list()?
                    .iter()
                    .map(scalar)
                    .collect::<Result<Vec<_>>>()
                    .map(Into::into)
            })
            .collect::<Result<_>>()?;
        program.relations.push(relation);
    }
    Ok((program, schema))
}

fn source_facts(
    program: &mut Program,
    schema: &BTreeMap<String, bool>,
    facts: &[(String, &[Data])],
) -> Result<()> {
    let mut relations = program
        .relations
        .iter_mut()
        .map(|r| (r.name.clone(), r))
        .collect::<BTreeMap<_, _>>();
    for (name, values) in facts {
        if schema.get(name) != Some(&true) {
            return Err(invalid("candidate facts must write a declared source"));
        }
        let relation = relations
            .get_mut(name)
            .ok_or_else(|| invalid("candidate source missing"))?;
        relation.rows.push(
            values
                .iter()
                .map(scalar)
                .collect::<Result<Vec<_>>>()?
                .into(),
        );
    }
    Ok(())
}
