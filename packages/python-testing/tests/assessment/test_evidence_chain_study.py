# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from agentic_ai_lab_testing.assessment_studies.evidence_chain_study import live, loose_json


class EvidenceChainStudy(unittest.TestCase):
    def test_equivalent_unambiguous_output_forms(self):
        for text in ('{"answer": []}', 'Result:\n```json\n{"answer": []}\n```', 'Here is the result: {"answer": []}.'):
            self.assertEqual(loose_json(text), {'answer': []})
        with self.assertRaises(ValueError): loose_json('First {"answer": []}, alternatively {"answer": [1]}')

    def test_synthetic_plan_cannot_start_paid_primary_calls(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp); (root / 'plan.json').write_text(json.dumps({'corpusKind': 'synthetic-mechanism-regression'}))
            with patch('agentic_ai_lab_testing.assessment_studies.evidence_chain_study.provider') as provider:
                with self.assertRaisesRegex(ValueError, 'external-source'):
                    live(root, root / 'paid')
                provider.assert_not_called()
                self.assertFalse((root / 'paid').exists())


if __name__ == '__main__': unittest.main()
