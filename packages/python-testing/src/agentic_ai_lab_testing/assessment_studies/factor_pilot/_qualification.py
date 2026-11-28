# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Qualification for the factor pilot study."""

from agentic_ai_lab_testing.model_study.reporting import report_text
from ._artifacts import save
from ._config import BASE, CASES
from ._transport import SchemeEngine


def _qualify_factor_cases(native, obs):
    """Own the qualify factor cases phase and retain its evidence checks."""
    for c in CASES:
        for a in "ABCD":
            native.call(op="init", arm=a, edges=c["edges"], identity=c["id"])
            x, _ = native.call(op="factor", u=0, v=4)
            y, _ = native.call(op="factor", u=0, v=4)
            z, _ = native.call(op="factor", u=1, v=5)
            assert x["precedes"] and x["freshNativeSolve"] and y["reused"] == (a != "A")
            assert z["precedes"] and z["reused"] == (a == "D")
            f, _ = native.call(op="fault")
            assert all(f.values())
            for phase in range(2):
                n = 6 + phase
                ds = c["durations"][:n]
                ws = c["weights"][phase]
                gold, _ = native.call(
                    op="grade", durations=ds, weights=ws, order=list(range(n))
                )
                bad, _ = native.call(
                    op="grade",
                    durations=ds,
                    weights=ws,
                    order=list(reversed(range(n))),
                )
                assert (
                    gold["valid"]
                    and not bad["valid"]
                    and gold["oracle"]["enumeratedOrders"] in (720, 5040)
                )
                obs.append(
                    {
                        "case": c["id"],
                        "arm": a,
                        "phase": phase,
                        "grade": gold,
                        "faults": f,
                    }
                )


def qualification():
    native = SchemeEngine()
    obs = []
    try:
        native.call(op="init", arm="A", edges=[], identity="oracle-control")
        control, _ = native.call(
            op="grade", durations=[1, 2, 3], weights=[3, 2, 1], order=[0, 1, 2]
        )
        assert (
            control["oracle"]
            == {"optimum": 15, "feasibleOrders": 6, "enumeratedOrders": 6}
            and control["optimal"]
        )
        native.call(
            op="init", arm="A", edges=[[0, 1], [1, 2]], identity="chain-control"
        )
        chain, _ = native.call(
            op="grade", durations=[1, 2, 3], weights=[3, 2, 1], order=[0, 1, 2]
        )
        prefix, _ = native.call(op="explore", prefix=[1], n=3)
        assert chain["oracle"]["feasibleOrders"] == 1 and not prefix["validPrefix"]
        _qualify_factor_cases(native, obs)
        correspondence = []
        for ident in range(16):
            for phase in range(2):
                current = ident - 4 if phase == 1 and ident & 4 else ident
                graph = [
                    e
                    for i, e in enumerate([[0, 0], [0, 1], [1, 0], [1, 1]])
                    if current & (1 << i)
                ]
                native.call(
                    op="init", arm="C", edges=graph, identity=f"finite-{current}"
                )
                x, _ = native.call(op="factor", u=0, v=0)
                y, _ = native.call(op="factor", u=1, v=0)
                # Python only projects native boolean observations into the model wire mask.
                correspondence.append(
                    [
                        ident,
                        phase,
                        current,
                        int(x["precedes"]) + 2 * int(y["precedes"]),
                        int(ident == current),
                    ]
                )
        save(BASE / "native-retained-correspondence.json", correspondence)
        save(BASE / "qualification.json", {"passed": True, "observations": obs})
        report_text("QUALIFICATION-OK", len(obs), flush=True)
    finally:
        native.close()
