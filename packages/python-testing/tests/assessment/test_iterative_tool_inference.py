# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_testing.assessment_studies.iterative_tool_inference_study import tool_definitions


class MatchedThinkingTools(unittest.TestCase):
    def test_evidence_is_the_only_additional_tool_and_query_is_not_forced(self):
        control=tool_definitions(False);assisted=tool_definitions(True)
        self.assertEqual([t['name'] for t in control],['scan_facts','submit_answer'])
        shared=[t for t in assisted if t['name']!='check_evidence']
        self.assertEqual(shared,control)
        evidence=next(t for t in assisted if t['name']=='check_evidence')
        self.assertEqual(set(evidence['parameters']['properties']),{'contract','queries'})
        self.assertNotIn('action',evidence['parameters']['properties'])


if __name__=='__main__':unittest.main()
