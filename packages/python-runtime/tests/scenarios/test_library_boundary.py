"""Application ownership is explicit and both installed artifacts bind one producer."""
import importlib.util
import unittest
import ascent
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_testing.assessment_studies.interface_tests import qualification_inputs

class LibraryBoundary(unittest.TestCase):
    def test_no_application_facade_in_rule_library(self):
        for name in ('EvidenceChain','EvidenceStore','ComputationalEvidence','ClueExchange','Trajectory','ResponseHistory','EvidenceReview','DomainEvidence','EvidenceInteraction','EvidenceOperation','EvidenceConversation'):
            self.assertFalse(hasattr(ascent,name),name)
        for name in ('evidence','derivations','trajectory','interaction','conversation','domain','review'):
            self.assertIsNone(importlib.util.find_spec('ascent.'+name),name)
        with ascent.Engine() as engine:
            self.assertTrue(callable(engine.rules))
            self.assertFalse(hasattr(engine,'evidence'))
        with ReasoningRuntime() as runtime:
            self.assertFalse(runtime.closed)

    def test_native_producer_content_matches_installed_core(self):
        self.assertEqual(len(qualification_inputs([])),2)
