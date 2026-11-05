# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_runtime.reasoning import compact_feedback, expand_feedback


class FeedbackEncoding(unittest.TestCase):
    def test_lossless_factoring_preserves_scope_order_and_missing_fields(self):
        branches=[{'id':'A','status':'supported','sourceIdentity':'s','resultReference':'r','reference':'p1','nullable':None},
                  {'id':'H','status':'unknown','reason':'missing'},
                  {'id':'B','status':'contradicted','sourceIdentity':'s','resultReference':'r','reference':'p2','complete':True}]
        packet={'schema':'ascent.branch-feedback.v1','scope':'local','branches':branches,'taskCorrectnessCertified':False}
        self.assertEqual(expand_feedback(compact_feedback(packet)),packet)
        self.assertIn('branches',packet)

    def test_tool_errors_remain_unknown_without_invented_branch_proofs(self):
        packet={'status':'unknown','reason':'invalid arguments','taskCorrectnessCertified':False}
        self.assertEqual(expand_feedback(compact_feedback(packet)),packet)
