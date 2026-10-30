"""Exact migration inventory: each original configuration and fault remains with its owner."""
import json
from pathlib import Path
import unittest
from agentic_ai_lab_testing.checks.assessment_models import MODEL_ORDER, CONFIGURATIONS, FAULTS
class FormalInventory(unittest.TestCase):
    def test_frozen_obligations(self):
        expected=json.loads((Path(__file__).parent/'fixtures/formal-obligations.json').read_text())
        self.assertEqual(set(MODEL_ORDER),set(expected))
        actual={n:{'configuration':CONFIGURATIONS[n],'faults':FAULTS.get(n,())} for n in MODEL_ORDER}
        self.assertEqual(json.loads(json.dumps(actual)),expected)
