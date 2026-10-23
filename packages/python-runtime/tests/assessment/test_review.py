# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Installed Rust review semantics through the typed PyO3 API."""
import copy
import os
from pathlib import Path
import unittest

from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import EvidenceReview, review_sources as sources


def facts():
    return {
        "Candidate": [["candidate", "gc", "new-inputs"]],
        "Failure": [["failure", "gc", "old-inputs", "report.json"]],
        "Passed": [["model-receipt", "bounded-model"], ["cause-receipt", "reviewed-source-cause"]],
        "ReceiptInput": [["model-receipt", "model", "v1"], ["cause-receipt", "source", "s1"]],
        "CurrentInput": [["model", "v1"], ["source", "s1"]],
        "ReceiptDepends": [["cause-receipt", "model-receipt"]],
        "Requires": [["candidate", "reviewed-source-cause"]],
        "ClaimDepends": [["reviewed-source-cause", "bounded-model"]],
        "Cause": [["candidate", "failure", "cause-receipt"]],
    }


class ReviewIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.engine=ReasoningRuntime()

    @classmethod
    def tearDownClass(cls):
        cls.engine.close()

    def result(self, value):
        with EvidenceReview(self.engine, value) as review:
            return review.review()

    def reasons(self, result):
        return {row[1] for row in result["result"]["relations"]["Denial"]}

    def test_reuse_explains_all_four_views_and_never_authorizes(self):
        with EvidenceReview(self.engine, facts()) as review:
            first = review.review()
            second = review.review()
            self.assertEqual(first["result"], second["result"])
            self.assertTrue(second["reusedComponents"])
            self.assertFalse(first["reusedComponents"])
            self.assertFalse(second["executionAuthorized"])
            self.assertEqual(second["decisions"][0]["decision"], "REVIEW_REQUIRED")
            rows = second["result"]["relations"]
            self.assertEqual(len(rows["KnownFailure"]), 1)
            self.assertEqual(len(rows["Established"]), 2)
            self.assertEqual(len(rows["Reusable"]), 2)
            self.assertEqual(rows["Missing"], [])

    def test_new_binary_and_unbacked_cause_do_not_pass(self):
        value = facts()
        value["Cause"][0][2] = "I-expect-this-to-fix-it"
        self.assertIn("missing-causal-evidence", self.reasons(self.result(value)))

    def test_unchanged_failure_is_denied_even_with_cause(self):
        value = facts()
        value["Candidate"][0][2] = "old-inputs"
        self.assertIn("unchanged-failed-inputs", self.reasons(self.result(value)))

    def test_context_update_withdraws_transitive_evidence_and_cached_answers(self):
        value = facts()
        with EvidenceReview(self.engine, value) as review:
            first = review.review()
            value["CurrentInput"][0][1] = "v2"
            review.replace(value)
            second = review.review()
            self.assertFalse(second["reusedComponents"])
            self.assertNotEqual(first["sourceIdentity"], second["sourceIdentity"])
            self.assertEqual(second["result"]["relations"]["Reusable"], [])
            self.assertIn("missing-premise", self.reasons(second))
            with self.assertRaisesRegex(ValueError, "closed|unknown result"):
                review.answer(first["resultReference"], "Established")

    def test_unbound_missing_and_cyclic_dependencies_cannot_justify_claim(self):
        for dependency in ("absent", "cause-receipt"):
            value = facts()
            value["ReceiptDepends"].append(["model-receipt", dependency])
            self.assertEqual(self.result(value)["result"]["relations"]["Reusable"], [])
        value = facts()
        value["ReceiptInput"] = value["ReceiptInput"][1:]
        self.assertEqual(self.result(value)["result"]["relations"]["Reusable"], [])

    def test_missing_transitive_premise_and_empty_requirements(self):
        value = facts()
        value["ClaimDepends"].append(["bounded-model", "native-origin"])
        result = self.result(value)
        self.assertIn(["candidate", "native-origin"], result["result"]["relations"]["Missing"])
        value["Requires"] = []
        self.assertIn("missing-requirement-set", self.reasons(self.result(value)))

    def test_input_validation_rejects_conflicting_identity(self):
        value = facts()
        value["CurrentInput"].append(["model", "v2"])
        with self.assertRaisesRegex(ValueError, "conflicting identity"):
            sources(value)

    def test_engine_failure_propagates_without_a_review_receipt(self):
        with ReasoningRuntime() as engine, EvidenceReview(engine,facts()) as review:
            engine.close()
            with self.assertRaisesRegex(ValueError,"closed"):
                review.review()



if __name__ == "__main__":
    unittest.main()
