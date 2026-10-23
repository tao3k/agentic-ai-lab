"""Installed fixed C exports over actual Evidence definitions, no SDK or VM."""
import concurrent.futures
import os
from pathlib import Path
import unittest

from ascent import Engine


class CoreCAbiTests(unittest.TestCase):
    def test_declarative_dsl_rejects_ordinary_procedures_without_fallback(self):
        with self.engine.dsl(self.source("history.ss"), trusted=True) as owner:
            self.assertTrue(owner.run().value()["complete"])
            self.assertFalse(owner.runtime().value()["schemeVm"])
        for source in ("(def (answer) 42)", "(def (make x) (lambda () x))",
                       "(import :gerbil/runtime)", "(set! answer 42)"):
            with self.assertRaises(ValueError):
                self.engine.dsl(source, trusted=True)

    def test_precompiled_graph_captures_and_retained_state(self):
        graph = {"algorithm": "projection", "source": "input", "width": 2,
                 "rows": [[2, 9], [3, 10]], "output": "answer", "captures": {"columns": [1]}}
        with self.engine.core_graph(graph, trusted=True) as owner:
            retained = owner.run(result_format="typed-rows")
            self.assertEqual(retained.value()["relations"]["answer"], [[9], [10]])
            owner.replace({"input": [[4, 12]]}).value()
            self.assertEqual(owner.run(result_format="typed-rows").value()["relations"]["answer"], [[12]])
            owner.replace({"input": []}).value()
            self.assertEqual(owner.run(result_format="typed-rows").value()["relations"]["answer"], [])
        self.assertEqual(retained.value()["relations"]["answer"], [[9], [10]])
        retained.close()
        for invalid in (dict(graph, algorithm="eval"), dict(graph, width=17),
                        dict(graph, captures={"columns": [2]})):
            with self.assertRaises(ValueError):
                self.engine.core_graph(invalid, trusted=True)

    def test_component_scope_and_withdrawal_use_the_actual_c_export(self):
        components = [
            {"id": "shared", "source": "(def f (ascent-fragment ((answer X) <-- (input X))))",
             "exports": ["f"], "dependencies": []},
            {"id": "entry", "source": """(define-program (make)
              (sources input) (outputs answer)
              (relation input ((x exact-integer?)) ((3) (7)))
              (relation answer ((x exact-integer?))) (include f))""",
             "exports": ["make"],
             "dependencies": [{"component": "shared", "bindings": ["f"]}]},
        ]
        with self.assertRaises(ValueError):
            self.engine.core_components(components, "entry", "make")
        with self.engine.core_components(components, "entry", "make", trusted=True) as owner:
            original = owner.run(result_format="typed-rows")
            self.assertEqual(original.value()["relations"]["answer"], [[3], [7]])
            owner.replace({"input": []}).value()
            self.assertEqual(owner.run(result_format="typed-rows").value()["relations"]["answer"], [])
            hidden = [dict(components[0], exports=[]), components[1]]
            with self.assertRaises(ValueError):
                self.engine.core_components(hidden, "entry", "make", trusted=True)
        self.assertEqual(original.value()["relations"]["answer"], [[3], [7]])
        original.close()
        with self.assertRaises(ValueError):
            owner.run()

    def test_typed_rows_preserve_scalars_and_non_scalar_graphs(self):
        source = """(define-program (typed) (sources) (outputs objects)
          (relation objects (value)
            ((17) (#t) ((object-graph (ref 0) ((0 vector (ref 0))))))))"""
        owner = self.engine.core_rules(source, trusted=True)
        try:
            typed = owner.run(result_format="typed-rows").value()
            self.assertEqual(typed["resultFormat"], "typed-rows")
            rows = typed["relations"]["objects"]
            self.assertIn([17], rows)
            self.assertIn([True], rows)
            graphs = [row[0] for row in rows if isinstance(row[0], dict)]
            self.assertEqual(len(graphs), 1)
            self.assertEqual(graphs[0]["type"], "graph")
            self.assertIn("namespace", graphs[0])
            vector = next(node for node in graphs[0]["value"]["nodes"] if node["type"] == "vector")
            self.assertEqual(vector["items"], [{"ref": vector["id"]}])
            with self.assertRaises(ValueError):
                owner.run(result_format="auto").value()
        finally:
            owner.close()

    def test_diagnostics_are_opt_in_and_do_not_replace_execution(self):
        source = self.source("history.ss")
        owner = self.engine.core_rules(source, trusted=True, diagnostics=True)
        try:
            result = owner.run()
            answer = result.value()
            self.assertTrue(answer["complete"])
            native = owner.diagnose().value()
            again = owner.diagnose().value()
            self.assertEqual(native, again)
            self.assertTrue(native["enabled"])
            for phase in ("open.rayonPool", "open.dslReadAndLower", "run.coreSnapshot",
                          "run.objectGraphAndPacket", "abi.outputEncode"):
                self.assertGreaterEqual(native["timingsNanoseconds"][phase], 0)
            host = result.diagnose()["timingsNanoseconds"]
            self.assertIn("host.decodeOwned", host)
            self.assertIn("host.pythonProjection", host)
        finally:
            owner.close()
        owner = self.engine.core_rules(source, trusted=True)
        try:
            self.assertFalse(owner.diagnose().value()["enabled"])
        finally:
            owner.close()

    def setUp(self):
        self.root = Path(__file__).resolve().parents[4] / "modules/evidence-assessment/native/tests/fixtures/evidence"
        self.engine = Engine(backend="rust", workers=2)

    def tearDown(self):
        self.engine.close()

    def source(self, *paths):
        return "\n".join((self.root / path).read_text() for path in paths)

    def test_real_catalog_review_history_answers_match_existing_core(self):
        for paths, constructor in [
            (("catalog.ss", "catalog/reports.ss", "catalog/observations.ss", "catalog/protocols.ss"), "make-catalog"),
            (("review.ss", "review/receipts.ss"), "make-review"),
            (("history.ss",), "make-history"),
        ]:
            source = self.source(*paths)
            direct = self.engine.rules(source, constructor, trusted=True)
            foreign = self.engine.core_rules(source, constructor, trusted=True)
            try:
                receipt = direct.run()
                result = direct.result(receipt)
                actual = foreign.run().value()
                self.assertTrue(actual["complete"])
                self.assertEqual(actual["relations"], {
                    name: result.graph(name) for name in receipt["relations"]
                })
                result.close()
            finally:
                direct.close()
                foreign.close()

    def test_history_withdrawal_rollback_and_independent_results(self):
        owner = self.engine.core_rules(self.source("history.ss"), trusted=True)
        owner.run().value()
        owner.replace({"previous_row": [["q", "old"]], "current_row": [["q", "new"]]}).value()
        retained = owner.run()
        before = retained.value()
        explanation = owner.explanation(before["resultHandle"], "added")
        metadata = explanation.value()
        self.assertEqual(metadata["status"], "recorded-only")
        with self.assertRaises(ValueError):
            owner.replace({"unknown-source": []}).value()
        self.assertEqual(owner.run().value()["sourceGeneration"], before["sourceGeneration"])
        owner.replace({"current_row": [["q", "old"]]}).value()
        after = owner.run().value()
        self.assertEqual(after["relations"]["added"]["root"], {"type": "null"})
        self.assertEqual(after["relations"]["removed"]["root"], {"type": "null"})
        owner.close()
        self.assertEqual(retained.value(), before)
        self.assertEqual(explanation.value(), metadata)
        retained.close()
        with self.assertRaises(ValueError):
            retained.value()
        with self.assertRaises(ValueError):
            owner.run()

    def test_no_vm_or_backend_fallback_and_explicit_trust(self):
        with self.assertRaises(ValueError):
            self.engine.core_rules(self.source("history.ss"))
        with self.assertRaises(ValueError):
            self.engine.core_rules("(import :gerbil/runtime)", trusted=True)
        owner = self.engine.core_rules(self.source("history.ss"), trusted=True)
        try:
            with self.assertRaises(ValueError):
                owner.call({"method": "evaluate-arbitrary-code"}).value()
            self.assertTrue(owner.run().value()["complete"])
        finally:
            owner.close()

    def test_cyclic_non_scalar_execution_and_update_do_not_require_projection(self):
        source = """(define-program (objects) (sources edge) (outputs objects)
          (relation edge (value))
          (relation objects (value)
            (((object-graph (ref 0) ((0 vector (ref 0)))))
             ((object-graph (ref 0) ((0 opaque "external-object")))))))"""
        owner = self.engine.core_rules(source, trusted=True)
        try:
            result = owner.run().value()
            self.assertTrue(result["complete"])
            owner.replace({"edge": []}).value()
            self.assertEqual(owner.run().value()["relations"], result["relations"])
        finally:
            owner.close()

    def test_fixed_independent_owners_use_parallel_host_threads(self):
        source = self.source("history.ss")

        def run(_):
            engine = Engine(backend="rust", workers=1)
            try:
                owner = engine.core_rules(source, trusted=True)
                try:
                    return owner.run().value()["complete"]
                finally:
                    owner.close()
            finally:
                engine.close()

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(list(pool.map(run, range(2))), [True, True])

    def test_parent_shutdown_blocks_child_calls(self):
        owner = self.engine.core_rules(self.source("history.ss"), trusted=True)
        result = owner.run()
        self.engine.close()
        self.assertTrue(result.value()["complete"])
        with self.assertRaises(ValueError):
            owner.run()
        owner.close()


if __name__ == "__main__":
    unittest.main()
