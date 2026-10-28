# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Collector regressions: observe mutation bodies, never skipped loop guards."""
import unittest
from fractions import Fraction
from types import SimpleNamespace
from agentic_ai_lab_testing.assessment_studies.domain_observations import group_schedule, series_precision

def root_with_boundary_term(p, n, x, prec):
    prec = Fraction(5,2)
    return {(Fraction(-1,2),):1,(Fraction(1),):2,(Fraction(2),):3}


def filtered_update(graph, group, normalized=False):
    for v in group:
        for x in group:
            Dx = graph[x]
            for y in group:
                if y not in Dx:
                    continue
                Dy = graph[y]
    return 0


def intersected_update(graph, group, normalized=False):
    group = set(group)
    for v in group:
        for x in group:
            Dx = graph[x]
            for y in group & Dx.keys():
                Dy = graph[y]
    return 0


class ExecutedDomainObservations(unittest.TestCase):
    def test_series_collects_fractional_budget_and_every_returned_exponent(self):
        class Polynomial(dict):
            ring=SimpleNamespace(gens=['x'])
        p=Polynomial({(Fraction(1,2),):1})
        rows=series_precision(root_with_boundary_term,p,-1,'x',2)['observations']
        self.assertEqual(len(rows),4)
        self.assertEqual(rows[0],['leading-term',[1,2],-1,[2,1],[5,2],[0,1],True])
        self.assertEqual([r[5] for r in rows[1:]],[[0,1],[3,2],[5,2]])
    def test_filtered_traversal_does_not_record_skipped_nodes(self):
        graph = {1:{1:0}, 3:{1:0,3:0}, 7:{7:0}}
        rows = group_schedule(filtered_update,graph,[1,3,7])['observations']
        self.assertEqual(len(rows),9)
        for _,outer,eligible,actual in rows:
            self.assertEqual(actual,[node for node in outer if node in eligible])

    def test_intersection_captures_actual_order_instead_of_reconstructing_it(self):
        nodes = [0,8,16,24,32,40]
        graph = {x:{y:0 for y in nodes if y >= x} for x in nodes}
        rows = group_schedule(intersected_update,graph,nodes)['observations']
        self.assertTrue(any(actual != [node for node in outer if node in eligible]
                            for _,outer,eligible,actual in rows))
