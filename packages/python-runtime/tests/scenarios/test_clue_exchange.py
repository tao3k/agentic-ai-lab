"""Installed default-backend API: declarative sources, no consumer compiler."""
import unittest

from agentic_ai_lab_runtime.reasoning import ReasoningRuntime
from agentic_ai_lab_runtime.reasoning import ClueExchange


DECLARATIONS = """
(define-program (project)
 (sources clue factor link) (outputs clue factor link)
 (relation clue (id digest claim polarity role source))
 (relation factor (id digest name value))
 (relation link (claim target label id digest)))
(define-program (select)
 (sources clue factor binding) (outputs question)
 (relation clue (id digest claim polarity role source))
 (relation factor (id digest name value))
 (relation binding (name value))
 (relation question (claim))
 ((question C) <-- (clue I D C _ _ _) (binding (lit "free-claim") C)))
"""


class ClueExchangeTests(unittest.TestCase):
    def setUp(self):
        self.engine = ReasoningRuntime(workers=1)
        self.addCleanup(self.engine.close)
        self.owner = ClueExchange(self.engine, [DECLARATIONS], "project", {
            "clue": [["old", "sha", "old-is-unexplored", "counter", "observation", "receipt"]],
            "factor": [["old", "sha", "mechanism", "already-investigated"]], "link": [],
        }, {"receipt": "sha"})
        self.addCleanup(self.owner.close)

    def test_exact_read_and_scheme_data_have_no_row_json_wrapper(self):
        result = self.owner.read(["old-is-unexplored", "unlisted"])
        self.assertEqual(len(result["counterevidence"]), 1)
        self.assertEqual(result["unknown"], [["unlisted"]])
        rendered = self.owner.read(["old-is-unexplored"], scheme=True)
        self.assertTrue(rendered.startswith("("))
        self.assertIn('"counterevidence"', rendered)
        self.assertNotIn('"row"', rendered)
        self.assertFalse(result["runtimeAdmitted"])

    def test_caller_selector_and_new_hypothesis_remain_open(self):
        self.owner.submit([{"id": "novel", "claim": "new-mechanism", "polarity": "support",
                            "source": "agent", "factors": [["never-seen", "value"]]}])
        result = self.owner.read_selected([DECLARATIONS], "select", [["free-claim", "new-mechanism"]])
        self.assertEqual(result["questions"], ["new-mechanism"])
        self.assertEqual(result["support"], [])
        self.assertEqual(len(result["conditional"]), 1)
        self.assertEqual(result["unknown"], [["new-mechanism"]])
        changed = self.owner.read_selected([DECLARATIONS + "\n; revised selector source"],
                                           "select", [["free-claim", "new-mechanism"]])
        self.assertEqual(changed["questions"], result["questions"])
        self.assertNotEqual(changed["selectorIdentity"], result["selectorIdentity"])
        self.assertIn(["never-seen", "value"], self.owner.inventory()["factors"])

    def test_forged_authority_and_closed_owner_are_rejected(self):
        with self.assertRaises(ValueError):
            self.owner.submit([{"id": "forged", "claim": "x", "polarity": "support",
                                "source": "agent", "attested": True}])
        self.owner.close()
        with self.assertRaises(ValueError):
            self.owner.read(["x"])


if __name__ == "__main__":
    unittest.main()
