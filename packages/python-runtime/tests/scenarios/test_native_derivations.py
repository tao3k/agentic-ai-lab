# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Pure graph operations execute directly in Rust without an engine dispatcher."""
import unittest
from agentic_ai_lab_runtime.reasoning import normalize_contract,evidence_graph,components,canonical_rule

class DerivationStructure(unittest.TestCase):
    def test_dag_helpers_use_the_same_native_operation(self):
        relation=lambda name,source:{'name':name,'source':source,'columns':[{'kind':'symbol'}],'rows':[]}
        atom=lambda name:{'relation':name,'terms':[{'var':'x'}]}
        program={'relations':[relation('input',True),relation('answer',False)],
                 'rules':[{'head':[atom('answer')],'body':[atom('input')]}]}
        graph=evidence_graph(program)
        self.assertEqual([n['relations'] for n in graph['nodes']],[['input'],['answer']])
        self.assertEqual(len(graph['edges']),1)
        self.assertEqual(components(program),[['answer']])
        self.assertEqual(canonical_rule(program['rules'][0])['head'][0]['terms'],[{'var':'0'}])

    def test_relaxed_head_surface_preserves_meaning_and_caller_input(self):
        atom={'relation':'answer','terms':[{'var':'x'}]}
        original={'rules':[{'head':atom,'body':[atom]}]}
        value=normalize_contract(original)
        self.assertEqual(value['rules'][0]['head'],[atom])
        self.assertIsInstance(original['rules'][0]['head'],dict)
        self.assertEqual(value['relations'],[])

if __name__=='__main__':unittest.main()
