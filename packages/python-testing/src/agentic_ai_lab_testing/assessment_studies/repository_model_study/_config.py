# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Config for the repository model study study."""

from pathlib import Path

ROOT = Path.cwd().resolve()

CORPUS = ROOT / ".cache/ascent/repository-study"

ARMS = ("ordinary-tools", "scheme-fresh", "scheme-retained")

ENGINE = None

CASES = [
    {
        "name": "group-centrality-order",
        "metadata": "networkx-8931",
        "package": "networkx",
        "editable": ["networkx/algorithms/centrality/group.py"],
        "testFile": "networkx/algorithms/centrality/tests/test_group.py",
        "targets": [
            "networkx/algorithms/centrality/tests/test_group.py::TestGroupBetweennessCentrality"
        ],
        "development": [
            "networkx/algorithms/centrality/tests/test_group.py::TestGroupBetweennessCentrality"
        ],
        "question": "Repair group_betweenness_centrality: on a directed graph, permuting the same group members can change its value. A path 0->1->2->3->4, a disjoint path 6->7->8->9->10, and additional edges 3->2->1 give different results for [1,3,7,9] and [9,7,3,1] with normalized=False. The result must be independent of group ordering. Preserve directed and undirected behavior, weighted shortest paths, endpoint inclusion, normalization, and disconnected-component handling. Diagnose the interaction among shortest-path counts and accumulated group contributions; repair the implementation without replacing it with a hard-coded answer.",
        "reproducer": 'import json,networkx as nx\nG=nx.path_graph(5,create_using=nx.DiGraph);nx.add_path(G,range(6,11));nx.add_path(G,[3,2,1])\nprint(json.dumps({"forward":nx.group_betweenness_centrality(G,[1,3,7,9],normalized=False),"reverse":nx.group_betweenness_centrality(G,[9,7,3,1],normalized=False)}))\n',
    },
    {
        "name": "series-root-precision",
        "metadata": "sympy-30699",
        "package": "sympy",
        "editable": ["sympy/polys/ring_series.py", "sympy/polys/puiseux.py"],
        "testFile": "sympy/polys/tests/test_ring_series.py",
        "targets": [
            "sympy/polys/tests/test_ring_series.py::test_issue_30698",
            "sympy/polys/tests/test_ring_series.py::test_nth_root",
            "sympy/polys/tests/test_ring_series.py::test_inversion",
        ],
        "development": ["sympy/polys/tests/test_ring_series.py::test_inversion"],
        "question": "Repair rs_nth_root for inputs whose leading exponent is nonzero. For p=x+x**2, rs_nth_root(p,-1,x,3) drops x-x**2 whereas rs_series_inversion preserves those terms. For p=x**4+x**5, the square root at precision 3 returns zero instead of x**2. Precision excludes terms at or above the requested exponent. Handle reciprocal and positive fractional roots, rational exponents, multivariate coefficients and precision boundaries consistently; preserve existing series inversion and root behavior. Trace normalization, recursive expansion and leading-power restoration before repairing the general case.",
        "reproducer": 'import json\nfrom sympy import QQ\nfrom sympy.polys.puiseux import puiseux_ring\nfrom sympy.polys.ring_series import rs_nth_root,rs_series_inversion\nR,x=puiseux_ring("x",QQ);p=x+x**2\nprint(json.dumps({"reciprocal":str(rs_nth_root(p,-1,x,3).as_expr()),"inversion":str(rs_series_inversion(p,x,3).as_expr()),"squareRoot":str(rs_nth_root(x**4+x**5,2,x,3).as_expr())}))\n',
    },
]
