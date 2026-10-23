import unittest
from ascent.datalog import read_datalog
from agentic_ai_lab_runtime.reasoning import ReasoningRuntime, ReasoningError, EvidenceChain, FactLimits
class ApplicationDatalogReuse(unittest.TestCase):
    def setUp(self):
        self.engine=ReasoningRuntime()
        self.addCleanup(self.engine.close)
    def test_exact_repeat_keeps_native_session_without_reimporting_outputs(self):
            facts = {"input": [[str(n)] for n in range(2100)]}
            program, _ = read_datalog(facts, "out(X) <= input(X)", {"answer": "out(X)"})
            with EvidenceChain(self.engine, [r for r in program["relations"] if r["source"]]) as chain:
                first=chain.query(program)
                second=chain.query(program)
                self.assertEqual(first["result"], second["result"])
                self.assertEqual(len(second["result"]["relations"]["out"]), 2100)
                self.assertTrue(second["retainedCompleted"])
                self.assertEqual(second["freshComponents"], [])
                self.assertEqual(first["pathIdentity"], second["pathIdentity"])
                self.assertTrue(first['evaluated'])
                self.assertFalse(second['evaluated'])
                self.assertEqual(first['evaluationCount'],1)
                self.assertEqual(second['evaluationCount'],1)
    def test_total_input_fact_limit_is_not_relaxed_by_repeat_fix(self):
            from agentic_ai_lab_runtime.reasoning import FactLimits
            program, _ = read_datalog({"a": [[str(n)] for n in range(2050)],
                                          "b": [[str(n)] for n in range(2050)]},
                                         "out(X) <= a(X) & b(X)", {"answer": "out(X)"})
            with self.assertRaises(ReasoningError):
                with EvidenceChain(self.engine, [r for r in program["relations"] if r["source"]],
                                   limits=FactLimits(input=4096)):
                    pass
    def test_replacement_invalidates_negative_results(self):
            rules = "out(X) <= domain(X) & ~denied(X)"
            first, _ = read_datalog({"domain": [["a"]], "denied": []}, rules, {"answer": "out(X)"})
            second, _ = read_datalog({"domain": [["a"]], "denied": [["a"]]}, rules, {"answer": "out(X)"})
            with EvidenceChain(self.engine, [r for r in first["relations"] if r["source"]]) as chain:
                old = chain.query(first)
                self.assertEqual(old["result"]["relations"]["out"], [['a']])
                chain.replace([r for r in second["relations"] if r["source"]])
                new = chain.query(second)
                self.assertEqual(new["result"]["relations"]["out"], [])
                self.assertEqual(new["reusedComponents"], [])
    def test_aggregate_dependency_and_operator_change_do_not_reuse_wrong_claim(self):
            facts = {"n": [[2], [5]]}
            schema = {"n": ["integer"], "sum": ["integer"], "out": ["integer"]}
            first, _ = read_datalog(facts,
                'sum(T) <= reduce(T, "sum", n(X), X)\nout(Y) <= sum(T) & bind(Y, T + 1)',
                {"answer": "out(Y)"}, schema=schema)
            second, _ = read_datalog(facts,
                'sum(T) <= reduce(T, "sum", n(X), X)\nout(Y) <= sum(T) & bind(Y, T + 2)',
                {"answer": "out(Y)"}, schema=schema)
            with EvidenceChain(self.engine, [r for r in first["relations"] if r["source"]]) as chain:
                self.assertEqual(chain.query(first)["result"]["relations"]["out"], [[8]])
                changed = chain.query(second)
                self.assertEqual(changed["result"]["relations"]["out"], [[9]])
                self.assertEqual([r["relations"] for r in changed["reusedComponents"]], [["sum"]])
                repeated = chain.query(second)
                self.assertEqual(repeated["result"], changed["result"])
                self.assertEqual(repeated["pathIdentity"], changed["pathIdentity"])
                self.assertTrue(repeated["retainedCompleted"])
                self.assertEqual(repeated["freshComponents"], [])
