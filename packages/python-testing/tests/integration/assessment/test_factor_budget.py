# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_testing.assessment_studies.factor_budget import charge_usage, input_reserve


class FactorBudget(unittest.TestCase):
    def test_gross_input_includes_cache_hits_and_reasoning_is_not_double_counted(self):
        usage = {'input_tokens': 1000, 'input_tokens_details': {'cached_tokens': 900},
                 'output_tokens': 500, 'output_tokens_details': {'reasoning_tokens': 400},
                 'total_tokens': 1500}
        self.assertEqual(charge_usage(usage), 1500)
        self.assertEqual(charge_usage(usage) + charge_usage(usage), 3000)

    def test_unknown_or_inconsistent_usage_cannot_be_admitted(self):
        for usage in [None, {}, {'input_tokens': True, 'output_tokens': 10},
                      {'input_tokens': 10, 'output_tokens': 20, 'total_tokens': 29},
                      {'input_tokens': 10, 'output_tokens': 20,
                       'output_tokens_details': {'reasoning_tokens': 21}}]:
            with self.subTest(usage=usage), self.assertRaises(ValueError):
                charge_usage(usage)

    def test_retransmitted_reasoning_increases_next_call_input_reservation(self):
        request = {'input': [{'role': 'user', 'content': '优化'}]}
        initial = input_reserve(request)
        request['input'].append({'type': 'reasoning', 'text': 'x' * 8192})
        self.assertGreater(input_reserve(request), initial + 8192)
