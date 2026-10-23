# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""POO-owned execution policy; the original native source/authority assertions."""
from importlib.resources import files
import unittest
import ascent

class ExecutionPolicy(unittest.TestCase):
    def setUp(self): self.engine=ascent.Engine(workers=4)
    def tearDown(self): self.engine.shutdown()

    def test_original_execution_evidence_module_and_source_permissions(self):
        module=':agentic-ai-lab/modules/evidence-assessment/execution'
        source=files('agentic_ai_lab_runtime').joinpath('reasoning_rules/execution.ss').read_text()
        self.engine.register_module(module, source, trusted=True)
        with self.engine.open_module(module,'make-execution-evidence') as session:
            sources={r['name'] for r in session.descriptors if r['source']}
            self.assertIn('required_step',sources);self.assertIn('observed_step',sources);self.assertNotIn('checked_step',sources)
            session.run();session.replace({'required_step':[['finished'],['missing']], 'observed_step':[['finished','PASS','native.test']]})
            receipt=session.run(queries=['checked_step','missing_step'])
            self.assertEqual(receipt['relations']['checked_step'],[['finished']]);self.assertEqual(receipt['relations']['missing_step'],[['missing']])
            with session.result(receipt) as result:
                with result.explanation('missing_step') as declared:
                    self.assertIn('source refinement',str(declared.graph))
                with result.provenance('missing_step') as proof:
                    self.assertTrue(proof.verify())
                    with self.assertRaises(ascent.EngineError): session.replace({'checked_step':[['forged']]})
                    self.assertTrue(proof.verify())
