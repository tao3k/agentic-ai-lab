# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_runtime.reasoning import ResponseHistory


class ReasoningToolHistory(unittest.TestCase):
    def test_reasoning_and_tool_receipt_survive_the_next_stateless_request(self):
        history=ResponseHistory('Complete complex question')
        original={'output':[{'type':'reasoning','content':[{'type':'reasoning_text','text':'opaque provider state'}]},
                            {'type':'function_call','call_id':'call-a','name':'check','arguments':'{}'}]}
        history.append_response(original)
        with self.assertRaises(ValueError):history.input()
        history.append_result('call-a',{'sourceIdentity':'current','verifiedEvidence':['witness']})
        result=history.input()
        self.assertEqual(result[1],original['output'][0])
        self.assertEqual(result[-1]['call_id'],'call-a')
        self.assertEqual(history.reasoning_items,1)
        result[1]['content'][0]['text']='mutated'
        self.assertEqual(history.input()[1],original['output'][0])

    def test_duplicate_tool_identity_cannot_trigger_repeated_execution(self):
        history=ResponseHistory('question')
        reply={'output':[{'type':'function_call','call_id':'same','name':'check','arguments':'{}'}]}
        history.append_response(reply);history.append_result('same',{})
        before=history.input()
        with self.assertRaises(ValueError):history.append_response(reply)
        self.assertEqual(history.input(),before)
        with self.assertRaises(ValueError):history.append_result('same',{})


if __name__=='__main__':unittest.main()
