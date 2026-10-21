"""Installed Rust-only wheel transport conformance; no DSL interpreter here."""
import os
from pathlib import Path
import unittest
from ascent import Engine, EngineError, EXECUTION_BACKEND


class EvidenceWheelTests(unittest.TestCase):
    def setUp(self):
        self.root = Path(__file__).resolve().parents[4] / "modules/evidence-assessment/native/tests/fixtures/evidence"
        self.engine = Engine(backend="rust", workers=2)

    def tearDown(self):
        self.engine.close()

    def source(self, *paths):
        return "\n".join((self.root / path).read_text() for path in paths)

    def test_complete_catalog_review_history_declarations(self):
        self.assertEqual(EXECUTION_BACKEND, "rust")
        for paths, constructor in [
            (("catalog.ss", "catalog/reports.ss", "catalog/observations.ss", "catalog/protocols.ss"), "make-catalog"),
            (("review.ss", "review/receipts.ss"), "make-review"),
            (("history.ss",), "make-history"),
        ]:
            owner = self.engine.rules(self.source(*paths), constructor, trusted=True)
            try:
                result = owner.run()
                self.assertTrue(result["complete"])
                self.assertEqual(set(result["relations"]), set(owner.queries))
            finally:
                owner.close()

    def test_history_withdrawal_and_generation_refs(self):
        owner = self.engine.rules(self.source("history.ss"), trusted=True)
        try:
            owner.replace({"previous_row": [["query", "old"]], "current_row": [["query", "new"]]})
            receipt = owner.run()
            self.assertEqual(receipt["relations"]["added"], [["query", "new"]])
            self.assertEqual(receipt["relations"]["removed"], [["query", "old"]])
            result = owner.result(receipt)
            value = result.reference("added", 0, 1)
            self.assertEqual(value.scalar(), "new")
            other = self.engine.rules(self.source("history.ss"), trusted=True)
            try:
                with self.assertRaises(ValueError):
                    other.replace({"current_row": [["query", value]]})
            finally:
                other.close()
            explanation = owner.explanation(receipt, "added")
            self.assertEqual(explanation.summary()["status"], "Complete")
            result.close()
            self.assertEqual(explanation.summary()["status"], "Complete")
            owner.replace({"current_row": [["query", "old"]]})
            updated = owner.run()
            self.assertEqual(updated["relations"]["added"], [])
            self.assertEqual(updated["relations"]["removed"], [])
            with self.assertRaises(ValueError):
                value.scalar()
            with self.assertRaises(ValueError):
                explanation.summary()
        finally:
            owner.close()

    def test_no_backend_or_semantic_fallback(self):
        for backend in ("auto", "scheme", "rayon"):
            with self.assertRaises(ValueError):
                Engine(backend=backend)
        with self.assertRaises(ValueError):
            self.engine.rules(self.source("history.ss"))
        with self.assertRaises(ValueError):
            self.engine.rules("(def answer (lambda () 1))", trusted=True)

    def test_result_rows_and_zero_budget_retain_only_completed_answers(self):
        source = """(define-program (check)
          (sources input) (outputs output)
          (relation input ((n integer?)) '((7)))
          (relation output ((n integer?)))
          ((output n) <-- (input n)))"""
        # Direct source loading has no completed public result yet.
        with self.engine.open_sources("(ascent-fragment (relation input ((n integer?))))") as pending:
            with self.assertRaisesRegex(EngineError, 'deadline'):
                pending.run(0)
            completed = pending.run()
            self.assertTrue(completed['complete'])
            with self.assertRaisesRegex(EngineError, 'deadline'):
                pending.run(0)
        with self.assertRaises(ValueError):
            pending.run()
        with self.engine.rules(source, trusted=True) as owner:
            receipt = owner.run()
            result = owner.result(receipt)
            self.assertEqual(result.rows('output')['rows'], [[7]])
            result.close()
            with self.assertRaises(ValueError):
                result.rows('output')

    def test_component_value_release_does_not_destroy_an_opened_session(self):
        manifest = {'schema': 'ascent.rule-components.v1', 'components': [
            {'id': 'check', 'source': 'check.ss', 'dependencies': [], 'exports': ['make-check']}]}
        source = """(define-program (make-check) (sources input) (outputs input)
                    (relation input ((n integer?))))"""
        with self.engine.components(manifest, {'check.ss': source}, 'check', trusted=True) as module:
            with module.call('make-check') as declaration:
                session = declaration.open_session()
            with self.assertRaises(ValueError):
                declaration.open_session()
        with self.assertRaises(ValueError):
            module.call('make-check')
        try:
            session.replace({'input': [[11]]})
            self.assertEqual(session.run()['relations']['input'], [[11]])
        finally:
            session.close()

    def test_structured_values_and_public_roles_use_rust_objects(self):
        import ascent
        for name in ('Module', 'Declaration', 'Value', 'Result', 'Explanation'):
            self.assertTrue(hasattr(ascent, name))
        for name in ('RuleComponents', 'RuleDeclaration', 'OwnedValue', 'RuleResult'):
            self.assertFalse(hasattr(ascent, name))
        source = """(define-program (shapes) (sources) (outputs packed)
          (relation packed (value) '((#(2 9)) (#()) ((a b)) (()))))"""
        with self.engine.rules(source, trusted=True) as session:
            receipt = session.run()
            self.assertEqual(receipt['scalarProjection'], 'partial')
            rows = receipt['relations']['packed']
            self.assertEqual(len(rows), 4)
            for row in rows:
                self.assertIsInstance(row[0], ascent.Value)
                self.assertEqual(row[0].graph['format'], 'native-value-graph.v1')
            result = session.result(receipt)
            self.assertIsInstance(result, ascent.Result)
            self.assertEqual(result.graph('packed')['format'], 'native-value-graph.v1')
            self.assertEqual(result.rows('packed')['value']['format'], 'native-value-graph.v1')
            result.close()
            with self.assertRaises(ValueError):
                result.graph('packed')

    def test_real_investigation_components_preserve_recursive_operator_results(self):
        import json
        manifest = json.loads((self.root / 'components.json').read_text())
        sources = {item['source']: self.source(item['source']) for item in manifest['components']}
        with self.engine.components(manifest, sources, 'investigation', trusted=True) as module:
            with module.call('make-investigation') as declaration:
                session = declaration.open_session()
        try:
            session.replace({'contracts': [['a', 'b', 'one'], ['b', 'c', 'two']]})
            first = session.run()
            self.assertEqual(first['relations']['ancestry'], [['a', 'b'], ['a', 'c'], ['b', 'c']])
            proof = session.explanation(first, 'ancestry')
            self.assertTrue(proof.current)
            self.assertEqual(proof.source_generation, first['sourceGeneration'])
            historical = proof.graph
            self.assertIn('one', str(historical))
            session.replace({'contracts': [['a', 'b', 'one']]})
            self.assertFalse(proof.current)
            self.assertEqual(proof.graph, historical)
            self.assertEqual(proof.source_generation, first['sourceGeneration'])
            proof.close()
            second = session.run()
            self.assertEqual(second['relations']['ancestry'], [['a', 'b']])
            self.assertGreater(second['sourceGeneration'], first['sourceGeneration'])
        finally:
            session.close()


if __name__ == "__main__":
    unittest.main()
