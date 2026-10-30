# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
"""Native Session contract through Python transport; no Python inference oracle."""
from pathlib import Path
from importlib.resources import files
import json
import subprocess
import sys
import unittest

from agentic_ai_lab_runtime.reasoning import ReasoningRuntime, ReasoningError


from checkpoint_fixture import (
    PROJECTION, exchange, trace_packet,
    resume_fixture, resume_trace_fixture, resume_progress_fixture,
)

class CheckpointTransport(unittest.TestCase):
    def setUp(self):
        source = files("agentic_ai_lab_runtime").joinpath("reasoning_rules/checkpoint_rules.ss")
        self.engine = ReasoningRuntime()
        self.session = self.engine.rules(source.read_text(), "make-evidence-checkpoint", trusted=True)
        self.addCleanup(self.session.close)

    def evaluate(self, facts):
        self.session.replace(facts)
        result = self.session.run()
        self.assertTrue(result["complete"])
        handle = self.session.result(result)
        self.addCleanup(handle.close)
        return result["relations"]

    def facts(self):
        return {"requirement": [("test",)], "contract": [("test", "checker")],
                "receipt": [("r", "test", "checker", "PASS")], "completed_outcome": [("PASS",)],
                "verified": [("r",)], "quiescent": [("r",)],
                "support_declaration": [("test", "checker", "scope", "manifest", "enumerator", 1, 1, 0)],
                "support_witness": [("r", "scope", "manifest", "enumerator")],
                "required_command": [("test", "checker", "child", 7)],
                "required_binding": [("test", "checker", "runtime")], "binding": [("r", "runtime", "sha")],
                "current_binding": [("runtime", "sha")], "command": [("r", "child", 7)],
                "command_observation": [("r", "child", 7, False, True, True)]}

    def progress_facts(self, counter=3):
        identity = ("phase", "worker", "incarnation", "completed-work", "source-sha")
        return {"progress_contract": [identity], "progress_active": [identity[:3]],
                "progress_cursor": [(*identity, 2)],
                "progress_sample": [("event", *identity, counter)],
                "progress_attested": [("event",)], "progress_completed": [("event",)]}

    def test_progress_requires_exact_active_identity_and_completed_attestation(self):
        facts = self.progress_facts()
        self.assertEqual(self.evaluate(facts)["progress_advanced"],
                         [["phase", "worker", "incarnation", "completed-work", "source-sha", 2, 3]])
        for field in range(1, 6):
            with self.subTest(field=field):
                facts = self.progress_facts()
                sample = list(facts["progress_sample"][0])
                sample[field] = "different"
                facts["progress_sample"] = [sample]
                result = self.evaluate(facts)
                self.assertEqual(result["progress_advanced"], [])
                self.assertIn(["event", "identity-or-contract"], result["progress_rejected"])
        for relation in ("progress_attested", "progress_completed"):
            facts = self.progress_facts()
            facts[relation] = []
            self.assertEqual(self.evaluate(facts)["progress_advanced"], [])

    def test_progress_frontier_rejects_replay_regression_and_conflicting_event(self):
        for counter in (0, 2, -1):
            self.assertEqual(self.evaluate(self.progress_facts(counter))["progress_advanced"], [])
        facts = self.progress_facts()
        facts["progress_sample"].append(("later", *facts["progress_sample"][0][1:-1], 5))
        facts["progress_attested"].append(("later",))
        facts["progress_completed"].append(("later",))
        self.assertEqual(self.evaluate(facts)["progress_advanced"][0][-1], 5)
        facts["progress_sample"].append(("event", *facts["progress_sample"][0][1:-1], 4))
        result = self.evaluate(facts)
        self.assertIn(["event", "conflicting-observation"], result["progress_rejected"])
        # An unrelated valid completion remains usable despite that conflict.
        self.assertEqual(result["progress_advanced"][0][-1], 5)

    def test_progress_restore_does_not_invent_new_work_or_receipt_completion(self):
        facts = self.progress_facts()
        first = self.evaluate(facts)
        self.assertEqual(first["historical_complete"], [])
        advanced = first["progress_advanced"][0]
        facts["progress_cursor"] = [(*advanced[:5], advanced[-1])]
        self.assertEqual(self.evaluate(facts)["progress_advanced"], [])
        facts["progress_active"] = [("phase", "worker", "new-incarnation")]
        self.assertEqual(self.evaluate(facts)["progress_advanced"], [])

    def test_progress_counter_uses_existing_integer_admission_not_bool_truthiness(self):
        with self.assertRaises(ReasoningError):
            self.evaluate(self.progress_facts(True))

    def test_missing_or_conflicting_cursor_and_active_epoch_remain_explicit_gaps(self):
        for cursors in ([], [("phase", "worker", "incarnation", "completed-work", "source-sha", -1)],
                        [("phase", "worker", "incarnation", "completed-work", "source-sha", 1),
                         ("phase", "worker", "incarnation", "completed-work", "source-sha", 2)]):
            facts = self.progress_facts()
            facts["progress_cursor"] = cursors
            result = self.evaluate(facts)
            self.assertEqual(result["progress_advanced"], [])
            self.assertIn(["event", "cursor-unavailable-or-conflicting"], result["progress_rejected"])
        facts = self.progress_facts()
        facts["progress_active"].append(("phase", "worker", "another-incarnation"))
        self.assertEqual(self.evaluate(facts)["progress_advanced"], [])

    def test_progress_cursor_survives_new_owner_without_replaying_old_samples(self):
        facts = self.progress_facts()
        advanced = self.evaluate(facts)["progress_advanced"][0]
        facts["progress_cursor"] = [(*advanced[:5], advanced[-1])]
        directory = str(Path(__file__).resolve().parent)
        code = ("import sys; sys.path.insert(0, sys.argv[1]); "
                "from test_checkpoint_contract import resume_progress_fixture; resume_progress_fixture()")
        def fresh():
            child = subprocess.run([sys.executable, "-c", code, directory],
                input=json.dumps(facts), text=True, capture_output=True, check=True, timeout=30)
            return json.loads(child.stdout)
        self.assertEqual(fresh()["progress_advanced"], [])
        facts["progress_sample"] = [("new-event", *facts["progress_sample"][0][1:-1], 4)]
        facts["progress_attested"] = facts["progress_completed"] = [("new-event",)]
        # Retained progress is not an attestation that its producer is still live.
        facts["progress_active"] = []
        self.assertEqual(fresh()["progress_advanced"], [])
        facts["progress_active"] = [("phase", "worker", "incarnation")]
        self.assertEqual(fresh()["progress_advanced"][0][-2:], [3, 4])
        facts["progress_active"] = [("phase", "worker", "restarted-process")]
        self.assertEqual(fresh()["progress_advanced"], [])

    def test_python_boolean_transport_is_not_integer_truthiness(self):
        for timeout, accepted in [(False, True), (0, False), (True, False)]:
            with self.subTest(timeout=timeout, cell_type=type(timeout).__name__):
                facts = self.facts()
                facts["command_observation"] = [("r", "child", 7, timeout, True, True)]
                result = self.evaluate(facts)
                self.assertEqual(bool(result["historical_complete"]), accepted)

    def test_component_support_does_not_complete_a_declared_native_goal(self):
        facts = self.facts()
        facts["requirement"].append(("native",))
        facts.update(dependency=[("native", "test")],
            checkpoint_claim=[("model-claim", "test", "finite-model", "declaration"),
                              ("native-claim", "native", "original-stress", "declaration")],
            checkpoint_source=[("declaration", "dsl", "declaration-sha"),
                               ("report", "receipt", "report-sha")],
            checkpoint_receipt_source=[("r", "report")])
        result = self.evaluate(facts)
        self.assertIn(["r", "report-sha", "model-claim", "support", "receipt",
                       "test", "finite-model", "applicable", "r"], result["checkpoint_observation"])
        self.assertIn(["native-claim", "declaration-sha", "native-claim", "counter",
                       "dsl", "native", "original-stress", "unclosed", ""],
                      result["checkpoint_observation"])
        self.assertEqual(result["checkpoint_dependency"], [["native-claim", "model-claim"]])
        self.assertEqual(result["unclosed"], [["native"]])

    def test_projection_keeps_history_when_a_binding_changes(self):
        facts = self.facts()
        facts.update(checkpoint_claim=[("claim", "test", "source-check", "declaration")],
            checkpoint_source=[("declaration", "dsl", "d"), ("report", "report", "h")],
            checkpoint_receipt_source=[("r", "report")], current_binding=[("runtime", "changed")])
        result = self.evaluate(facts)
        self.assertEqual(result["applicable"], [])
        self.assertEqual(result["historical_complete"], [["test", "r"]])
        self.assertEqual({row[7] for row in result["checkpoint_observation"]},
                         {"historical-only", "unclosed"})
        self.assertIn(["claim", "r", "r", "binding"], result["checkpoint_reason"])

    def test_cache_loss_is_not_loss_of_evidence_or_reuse_permission(self):
        facts = self.facts()
        facts.update(checkpoint_claim=[("claim", "test", "source-check", "declaration")],
            checkpoint_source=[("declaration", "dsl", "d"), ("report", "report", "h")],
            checkpoint_receipt_source=[("r", "report")], material=[("r", "binary")])
        result = self.evaluate(facts)
        self.assertEqual(result["applicable"], [["test", "r"]])
        self.assertEqual(result["reusable"], [])
        self.assertEqual(result["checkpoint_observation"][0][7], "applicable")
        self.assertIn(["claim", "r", "binary", "artifact-unavailable"], result["checkpoint_reason"])

    def test_missing_receipt_provenance_is_visible_without_erasing_history(self):
        facts = self.facts()
        facts.update(checkpoint_claim=[("claim", "test", "source-check", "declaration")],
            checkpoint_source=[("declaration", "dsl", "d")],
            checkpoint_receipt_source=[("r", "missing-report")])
        result = self.evaluate(facts)
        self.assertEqual(result["historical_complete"], [["test", "r"]])
        self.assertIn(["r", "d", "claim", "counter", "dsl", "test",
                       "source-check", "provenance-unavailable", "r"],
                      result["checkpoint_observation"])
        self.assertIn(["claim", "r", "r", "receipt-source-unavailable"],
                      result["checkpoint_reason"])

    def test_missing_receipt_source_association_is_not_a_silent_empty_slice(self):
        facts = self.facts()
        facts.update(checkpoint_claim=[("claim", "test", "source-check", "declaration")],
            checkpoint_source=[("declaration", "dsl", "d")])
        result = self.evaluate(facts)
        self.assertTrue(result["checkpoint_observation"])
        self.assertEqual(result["reusable"], [["test", "r"]])

    def test_provenance_gap_reaches_installed_clue_and_new_process(self):
        facts = self.facts()
        facts.update(checkpoint_claim=[("claim", "test", "source-check", "declaration")],
            checkpoint_source=[("declaration", "dsl", "d"), ("source", "report", "h")],
            checkpoint_receipt_source=[("r", "source")])
        first = trace_packet({"facts": facts})
        self.assertEqual(len(first["brief"]["families"]), 1)
        facts["checkpoint_receipt_source"] = []
        directory = str(Path(__file__).resolve().parent)
        code = ("import sys; sys.path.insert(0, sys.argv[1]); "
                "from test_checkpoint_contract import resume_trace_fixture; resume_trace_fixture()")
        def fresh(token):
            child = subprocess.run([sys.executable, "-c", code, directory],
                input=json.dumps({"facts": facts, "checkpoint": token}),
                text=True, capture_output=True, check=True, timeout=30)
            return json.loads(child.stdout)
        changed = fresh(first["checkpoint"])
        observations = changed["brief"]["families"][0]["observations"]
        self.assertTrue(any("provenance-unavailable" in row["factors"]["state"]
                            for row in observations))
        self.assertTrue(all(row["polarity"] == "counter" for row in observations))
        self.assertFalse(changed["brief"]["runtimeAdmitted"])
        resumed = fresh(changed["checkpoint"])
        self.assertEqual(resumed["brief"]["families"], [])
        facts["checkpoint_receipt_source"] = [("r", "source")]
        restored = fresh(resumed["checkpoint"])
        self.assertEqual(restored["brief"]["counts"]["counter"], 0)
        self.assertEqual(restored["brief"]["counts"]["support"], 1)
        self.assertGreater(restored["brief"]["delta"]["removed"], 0)
        self.assertTrue(restored["brief"]["explorationOpen"])
        self.assertFalse(restored["brief"]["executionAuthorized"])

    def test_failed_receipt_is_visible_without_becoming_completion(self):
        facts = self.facts()
        facts.update(receipt=[("failed", "test", "checker", "INCOMPLETE")],
            checkpoint_claim=[("claim", "test", "original-stress", "declaration")],
            checkpoint_source=[("declaration", "dsl", "d"), ("report", "failure", "h")],
            checkpoint_receipt_source=[("failed", "report")])
        result = self.evaluate(facts)
        self.assertEqual(result["historical_complete"], [])
        self.assertEqual({row[7] for row in result["checkpoint_observation"]},
                         {"recorded-noncompletion", "unclosed"})

    def test_missing_bound_input_is_not_an_empty_success(self):
        facts = self.facts()
        facts["binding"] = []
        result = self.evaluate(facts)
        self.assertTrue(result["historical_complete"])
        self.assertEqual(result["applicable"], [])
        self.assertEqual(result["binding_gap"], [["r", "runtime"]])

    def test_missing_exit_witness_cannot_promote_declared_pass(self):
        facts = self.facts()
        facts["command_observation"] = []
        self.assertEqual(self.evaluate(facts)["historical_complete"], [])

    def test_omission_is_not_a_legitimate_empty_declaration(self):
        facts = self.facts()
        facts.update(required_binding=[], binding=[], current_binding=[], command=[])
        self.assertEqual(self.evaluate(facts)["reusable"], [])
        facts["support_declaration"] = [("test", "checker", "scope", "empty-manifest", "enumerator", 0, 0, 0)]
        facts["support_witness"] = [("r", "scope", "empty-manifest", "enumerator")]
        facts["required_command"] = []
        self.assertEqual(self.evaluate(facts)["reusable"], [["test", "r"]])


class ReadCheckpointProcesses(unittest.TestCase):
    def resumed(self, checkpoint, extra=None, **fields):
        directory = str(Path(__file__).resolve().parent)
        code = "import sys; sys.path.insert(0, sys.argv[1]); from test_checkpoint_contract import resume_fixture; resume_fixture()"
        result = subprocess.run([sys.executable, "-c", code, directory],
            input=json.dumps(dict(checkpoint=checkpoint, extra=extra, **fields)),
            text=True, capture_output=True, check=True, timeout=30)
        return json.loads(result.stdout)

    def initial(self):
        engine, owner = exchange()
        try:
            return owner.slice_selected([PROJECTION], "select", {"bindings": [["topic", "gc"]]})
        finally:
            owner.close()

    def test_fresh_process_rederives_snapshot_without_replaying_unrelated_updates(self):
        first = self.initial()
        self.assertEqual(len(first["brief"]["families"]), 1)
        refreshed = self.resumed(first["checkpoint"], extra="unrelated")
        self.assertEqual(refreshed["brief"]["mode"], "refresh")
        self.assertEqual(refreshed["brief"]["families"], [])
        self.assertGreater(refreshed["brief"]["delta"]["retained"], 0)
        self.assertFalse(refreshed["brief"]["executionAuthorized"])

    def test_new_counterevidence_is_displayed_then_acknowledged_across_processes(self):
        first = self.initial()
        changed = self.resumed(first["checkpoint"], extra="counter")
        family = changed["brief"]["families"][0]
        self.assertTrue(family["conflict"])
        self.assertEqual({row["polarity"] for row in family["observations"]}, {"support", "counter"})
        repeated = self.resumed(changed["checkpoint"], extra="counter")
        self.assertEqual(repeated["brief"]["families"], [])
        self.assertEqual(repeated["brief"]["mode"], "incremental")
        opened = self.resumed(repeated["checkpoint"], extra="counter", questions=["caller-new-hypothesis"])
        self.assertTrue(opened["brief"]["explorationOpen"])
        self.assertEqual(opened["brief"]["families"][0]["claim"], "caller-new-hypothesis")
        self.assertTrue(opened["brief"]["families"][0]["unknown"])


class SelectedComponentTransport(unittest.TestCase):
    def test_unselected_source_is_not_required_but_selected_source_remains_mandatory(self):
        manifest = {"schema": "ascent.rule-components.v1", "components": [
            {"id": "chosen", "source": "chosen.ss", "exports": ["make"], "dependencies": []},
            {"id": "elsewhere", "source": "not-retained.ss", "exports": [], "dependencies": []}]}
        source = "(define-program (make) (sources) (outputs fact) (relation fact (value) '((1))))"
        from ascent import Engine
        engine = Engine()
        with engine.components(manifest, {"chosen.ss": source}, "chosen", trusted=True) as module:
            self.assertEqual(module.components, ["chosen"])
            with module.call("make") as declaration:
                session = declaration.open_session()
                try:
                    result = session.run()
                    self.assertTrue(result["complete"])
                    self.assertEqual(result["relations"]["fact"], [[1]])
                    session.result(result).close()
                finally:
                    session.close()
        with self.assertRaises(ValueError):
            engine.components(manifest, {}, "chosen", trusted=True)


if __name__ == "__main__":
    unittest.main()
