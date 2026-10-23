# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Rust structural graphs and private, source-bound completed component reuse."""
import copy
import os
import unittest

from agentic_ai_lab_runtime.reasoning import ReasoningRuntime, ReasoningError
from agentic_ai_lab_runtime.reasoning import EvidenceChain, components, canonical_rule, evidence_graph, slice_program


def atom(name, variable='x'):
    return {'relation': name, 'terms': [{'var': variable}]}


def declaration(name, source=False, rows=None, kind='symbol'):
    return {'name': name, 'source': source, 'columns': [{'kind': kind}], 'rows': rows or []}


class EvidenceDagTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine=ReasoningRuntime()

    @classmethod
    def tearDownClass(cls):
        cls.engine.close()

    def slice(self, program, facts, queries):
        return slice_program(program,facts,queries)

    def test_recursive_and_multihead_dependencies_stay_atomic(self):
        program = {'relations': [declaration(n) for n in ('reach', 'answer', 'left', 'right')],
                   'rules': [{'head': [atom('reach')], 'body': [atom('reach')]},
                             {'head': [atom('answer')], 'body': [atom('reach')]},
                             {'head': [atom('left'), atom('right')], 'body': [atom('reach')]}]}
        groups = components(program)
        self.assertIn(['left', 'right'], groups)
        self.assertLess(groups.index(['reach']), groups.index(['answer']))

    def test_explicit_dag_preserves_recursive_component_and_topological_edges(self):
        program = {'relations': [declaration('input', True), declaration('reach'), declaration('answer')],
                   'rules': [{'head': [atom('reach')], 'body': [atom('input')]},
                             {'head': [atom('reach')], 'body': [atom('reach')]},
                             {'head': [atom('answer')], 'body': [atom('reach')]}]}
        dag = evidence_graph(program)
        self.assertEqual([node['relations'] for node in dag['nodes']],
                         [['input'], ['reach'], ['answer']])
        self.assertTrue(dag['nodes'][1]['recursive'])
        positions = {node['id']:i for i,node in enumerate(dag['nodes'])}
        self.assertTrue(all(positions[edge['from']] < positions[edge['to']]
                            for edge in dag['edges']))

    def test_alpha_renaming_is_native_and_does_not_mutate_input(self):
        def rule(a, b):
            return {'head': [{'relation': 'reach', 'terms': [{'var': a}, {'var': b}]}],
                    'body': [{'relation': 'edge', 'terms': [{'var': a}, {'var': b}]}]}
        original = rule('x', 'y')
        saved = copy.deepcopy(original)
        self.assertEqual(canonical_rule(original),
                         canonical_rule(rule('a', 'z')))
        self.assertEqual(original, saved)

    def test_slice_keeps_negative_and_reducer_dependencies(self):
        program = {'relations': [declaration(n, True) for n in ('input', 'blocked', 'unrelated')]
                                + [declaration('answer')],
                   'rules': [{'head': [atom('answer')],
                              'body': [atom('input'), {**atom('blocked'), 'not': True}]}]}
        result = self.slice(program, {'input': [['a']], 'blocked': [], 'unrelated': [['b']]}, ['answer'])
        self.assertEqual([r['name'] for r in result['relations']], ['answer', 'blocked', 'input'])
        program['rules'][0]['body'] = [{'mode': 'reduce', 'operator': 'count',
                                      'output': 'x', 'inputs': [], 'relation': 'input', 'terms': []}]
        result = self.slice(program, {'input': [['a']]}, ['answer'])
        self.assertEqual([r['name'] for r in result['relations']], ['answer', 'input'])

    def test_slice_rejects_extra_rule_fields_and_bool_integer(self):
        program = {'relations': [declaration('input', True, kind='integer'), declaration('answer')],
                   'rules': [{'head': [atom('answer')], 'body': [atom('input')], 'waiver': True}]}
        with self.assertRaises(ValueError):
            self.slice(program, {'input': [[1]]}, ['answer'])
        del program['rules'][0]['waiver']
        with self.assertRaises(ValueError):
            self.slice(program, {'input': [[True]]}, ['answer'])

    def test_slice_rejects_missing_sources_and_undefined_or_source_heads(self):
        program = {'relations': [declaration('input', True), declaration('answer')],
                   'rules': [{'head': [atom('answer')], 'body': [atom('input')]}]}
        with self.assertRaises(ValueError):
            self.slice(program, {}, ['answer'])
        with self.assertRaises(ValueError):
            self.slice({**program, 'rules': []}, {'input': []}, ['answer'])
        program['rules'][0]['head'] = [atom('input')]
        with self.assertRaises(ValueError):
            self.slice(program, {'input': []}, ['input'])

    def test_query_dag_rejects_changed_source_before_reuse(self):
        source=declaration('input',True,[['a']])
        program={'relations':[copy.deepcopy(source),declaration('answer')],
                 'rules':[{'head':[atom('answer')],'body':[atom('input')]}],
                 'queries':['answer']}
        with EvidenceChain(self.engine,[source]) as chain:
            first=chain.query(program)
            self.assertEqual(len(first['freshComponents']),1)
            program['relations'][0]['rows']=[]
            with self.assertRaises(ValueError):chain.query(program)
            self.assertEqual(chain.answer(first['resultReference'],'answer'),[['a']])

    def test_query_dag_reuses_exact_completed_alias_and_retains_all_sources(self):
        source=declaration('input',True,[['a']])
        unused=declaration('unused',True,[])
        program={'relations':[copy.deepcopy(source),unused,declaration('answer')],
                 'rules':[{'head':[atom('answer')],'body':[atom('input')]}],
                 'queries':['answer']}
        with EvidenceChain(self.engine,[source,unused]) as chain:
            first=chain.query(program)
            second=chain.query(program)
            self.assertFalse(first['reusedComponents'])
            self.assertEqual(len(second['reusedComponents']),1)
            self.assertTrue(second['retainedCompleted'])
            self.assertEqual(first['result'],second['result'])
            # Certificates and aliases are private native owner state, not caller packets.
            with self.assertRaises(TypeError):chain.query(program,certificates={'answer':'input'})
            forged=copy.deepcopy(program);forged['relations'][-1]['source']=True
            forged['relations'][-1]['rows']=[['forged']]
            with self.assertRaises(ValueError):chain.query(forged)
            omitted=copy.deepcopy(program);omitted['relations'].pop(1)
            with self.assertRaises(ValueError):chain.query(omitted)
            changed=declaration('input',True,[['b']])
            chain.replace([changed,unused])
            program['relations'][0]=changed
            fresh=chain.query(program)
            self.assertFalse(fresh['reusedComponents'])
            self.assertEqual(chain.answer(fresh['resultReference'],'answer'),[['b']])
            with self.assertRaises(ValueError):chain.answer(first['resultReference'],'answer')

    def test_capability_is_public_and_request_unknown_fields_are_rejected(self):
        self.assertTrue(callable(components))
        self.assertFalse(hasattr(self.engine,'request'))
        with self.assertRaises(TypeError):components({'relations':[],'rules':[]},waiver=True)
        with self.assertRaises(ReasoningError):
            self.engine.open({'relations':[],'rules':[],'waiver':True})


if __name__=='__main__':unittest.main()
