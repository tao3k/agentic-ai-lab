//! Exact domain checks over caller-supplied observations, never source authentication.
use crate::{Data, Result, invalid_data as invalid};
use num_bigint::BigInt;
use num_rational::BigRational;
use num_traits::{Signed, Zero};
fn rational(value: &Data) -> Result<BigRational> {
    let v = value.list()?;
    if v.len() != 2 {
        return Err(invalid(
            "exact rational numerator and positive denominator required",
        ));
    }
    let (Data::Integer(n), Data::Integer(d)) = (&v[0], &v[1]) else {
        return Err(invalid("exact rational components required"));
    };
    if d <= &BigInt::zero() {
        return Err(invalid("positive denominator required"));
    }
    Ok(BigRational::new(n.clone(), d.clone()))
}
fn wire(v: BigRational) -> Data {
    let (n, d) = v.into_raw();
    Data::List(vec![Data::Integer(n), Data::Integer(d)])
}
fn claim(name: &str, value: bool) -> Data {
    Data::List(vec![name.into(), value.into()])
}
/// Trusted contract text names only the checked relationship, not upstream observation authority.
/// # Errors
/// Rejects unsupported domain kinds.
pub fn domain_contract(kind: &str) -> Result<&'static str> {
    match kind {
        "graph-schedule" => Ok(
            "Inner update traversal equals outer group traversal filtered by reachability; matrix mutation must not mix traversal schedules.",
        ),
        "graph-update" => {
            Ok("Read the required update epoch; after=before-removed and 0<=removed<=before.")
        }
        "series-precision" => Ok(
            "For p=x^m*u and nth root n!=0, internal precision=P-m/n; keep a normalized term e exactly when e+m/n<P.",
        ),
        "graph-row-normalization" => Ok(
            "Normalize each mutual-weight row by that row's own maximum; the read divisor must belong to the same row.",
        ),
        "symbolic-specialization" => Ok(
            "A receipted zero symbolic difference witnesses that a specialization belongs to a returned family; retaining both is redundant. A nonzero or unknown difference is not a containment proof.",
        ),
        _ => Err(invalid("unsupported domain contract")),
    }
}
/// Exact rational and sequence checks with the same bounded observation contract as the Scheme API.
/// # Errors
/// Rejects malformed observations, invalid rational pairs and unsupported kinds.
pub fn domain_check(kind: &str, rows: &Data) -> Result<Data> {
    domain_contract(kind)?;
    let rows = rows.list()?;
    if rows.len() > 256 {
        return Err(invalid("domain observation count"));
    }
    let width = match kind {
        "graph-update" => 6,
        "series-precision" => 7,
        "symbolic-specialization" => 3,
        _ => 4,
    };
    rows.iter()
        .map(|r| {
            let r = r.list()?;
            if r.len() != width {
                return Err(invalid("domain observation width"));
            }
            r[0].text()?;
            match kind {
                "graph-update" => update(r),
                "graph-schedule" => schedule(r),
                "series-precision" => precision(r),
                "graph-row-normalization" => normalization(r),
                "symbolic-specialization" => specialization(r),
                _ => Err(invalid("unsupported domain checker")),
            }
        })
        .collect::<Result<Vec<_>>>()
        .map(Data::List)
}
fn update(r: &[Data]) -> Result<Data> {
    let n = r[1..]
        .iter()
        .map(Data::natural)
        .collect::<Result<Vec<_>>>()?;
    Ok(Data::object([
        ("id", r[0].clone()),
        (
            "claims",
            Data::List(vec![
                claim("update-read-version", n[0] == n[1]),
                claim("path-count-conservation", n[4] == &(n[2] - n[3])),
                claim("path-count-nonnegative", n[3] <= n[2]),
            ]),
        ),
    ]))
}
fn schedule(r: &[Data]) -> Result<Data> {
    let lists = r[1..].iter().map(Data::list).collect::<Result<Vec<_>>>()?;
    if lists
        .iter()
        .flat_map(|v| v.iter())
        .any(|v| !matches!(v, Data::Text(_) | Data::Integer(_)))
    {
        return Err(invalid("invalid graph schedule observation"));
    }
    let expected = lists[0]
        .iter()
        .filter(|v| lists[1].contains(v))
        .cloned()
        .collect::<Vec<_>>();
    let coherent = expected == lists[2];
    Ok(Data::object([
        ("id", r[0].clone()),
        ("requiredOrder", Data::List(expected)),
        (
            "claims",
            Data::List(vec![claim("update-traversal-coherence", coherent)]),
        ),
    ]))
}
fn precision(r: &[Data]) -> Result<Data> {
    let Data::Integer(n) = &r[2] else {
        return Err(invalid("exact nonzero root order required"));
    };
    if n.is_zero() {
        return Err(invalid("nonzero root order required"));
    }
    let m = rational(&r[1])?;
    let p = rational(&r[3])?;
    let inner = rational(&r[4])?;
    let term = rational(&r[5])?;
    let included = r[6].boolean()?;
    let shift = m / BigRational::from_integer(n.clone());
    let required = &p - &shift;
    let restored = term + shift;
    let keep = restored < p;
    Ok(Data::object([
        ("id", r[0].clone()),
        ("requiredInternalPrecision", wire(required.clone())),
        ("restoredExponent", wire(restored)),
        ("shouldInclude", keep.into()),
        (
            "claims",
            Data::List(vec![
                claim("precision-budget", inner == required),
                claim("precision-boundary", included == keep),
            ]),
        ),
    ]))
}
fn normalization(r: &[Data]) -> Result<Data> {
    let original = r[1]
        .list()?
        .iter()
        .map(rational)
        .collect::<Result<Vec<_>>>()?;
    let actual = r[2]
        .list()?
        .iter()
        .map(rational)
        .collect::<Result<Vec<_>>>()?;
    let tolerance = rational(&r[3])?;
    let maximum = original
        .iter()
        .max()
        .ok_or_else(|| invalid("nonempty normalization row required"))?;
    if original.len() != actual.len()
        || maximum <= &BigRational::zero()
        || tolerance.is_negative()
        || original.iter().any(Signed::is_negative)
    {
        return Err(invalid(
            "normalization requires nonnegative weights and positive maximum",
        ));
    }
    let required = original.iter().map(|v| v / maximum).collect::<Vec<_>>();
    let okay = required
        .iter()
        .zip(actual)
        .all(|(x, y)| (x - y).abs() <= tolerance);
    Ok(Data::object([
        ("id", r[0].clone()),
        (
            "requiredNormalizedRow",
            Data::List(required.into_iter().map(wire).collect()),
        ),
        ("claims", Data::List(vec![claim("same-row-divisor", okay)])),
    ]))
}
fn specialization(r: &[Data]) -> Result<Data> {
    let zero = r[1].text()? == "0";
    let retained = r[2].boolean()?;
    Ok(Data::object([
        ("id", r[0].clone()),
        ("witnessAvailable", zero.into()),
        (
            "claims",
            Data::List(vec![
                claim("specialization-witness", zero),
                claim("no-redundant-specialization", !(zero && retained)),
            ]),
        ),
    ]))
}
