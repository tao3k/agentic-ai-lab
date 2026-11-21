import unittest
from agentic_ai_lab_testing.checks.assessment_formal import configuration, obligations
class AssessmentFormal(unittest.TestCase):
    def test_integrated_checkpoint_extensions_retain_all_fault_controls(self):
            for model, faults in [('ModelApplicability', 7), ('CheckpointProjection', 8)]:
                with self.subTest(model=model):
                    checks = obligations(configuration(model, {}))
                    self.assertEqual(len(checks), faults + 1)
                    self.assertEqual(checks[0].expected, 0)
                    self.assertTrue(all(item.expected == 12 for item in checks[1:]))
    def test_trajectory_faults_are_checked_as_state_invariants(self):
            for model in ("TrajectoryExploration", "TrajectoryEvidenceChain",
                          "TrajectoryRuleEvolution"):
                for fault in obligations(configuration(model, {}))[1:]:
                    with self.subTest(model=model, fault=fault.name):
                        self.assertEqual(fault.expected, 12)
                        self.assertIn(fault.property, fault.configuration.invariants)
                        self.assertEqual(fault.configuration.properties, ())

    def test_concurrent_delivery_and_query_controls_survive_migration(self):
        anchored = {o.name: o for o in obligations(configuration("AnchoredEvidenceSlice", {}))}
        self.assertEqual({name: o.property for name, o in anchored.items() if name != "correct"}, {
            "index-only-hit": "SoundHit",
            "mix-witnesses": "SoundHit",
            "invalid-declaration-hit": "SoundHit",
            "ack-collapsed": "Acknowledged",
            "ack-before-delivery": "DeliveryAcknowledged",
            "reuse-unverified-delivery": "VerifiedReuse",
            "drop-query-on-replay": "QueryRetained",
            "drop-first-hit": "FirstHit", "invent-hit": "SoundHit", "dump-graph": "Local",
            "hide-counter": "Family", "wrong-chain": "Traceable",
            "hide-truncation": "HonestPresentation", "gap-as-absent": "Gaps",
            "mask-gap": "Gaps", "count-only-delta": "ExactDelta",
            "hide-discovery": "DiscoveryExact", "invent-discovery": "DiscoveryExact",
            "select-action": "Open", "close-scope": "Open",
        })
        self.assertTrue(all(o.expected == 12 for name, o in anchored.items() if name != "correct"))
