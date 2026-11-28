# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import unittest
from agentic_ai_lab_testing.assessment_studies.tool_inference_recovery import continuation_history


class ExhaustedThinkingContinuation(unittest.TestCase):
    def test_exhausted_thinking_and_paired_prior_tools_survive_without_gold(self):
        prior={'type':'reasoning','status':'completed','content':[{'type':'reasoning_text','text':'opaque prior'}]}
        incomplete={'type':'reasoning','status':'incomplete','content':[{'type':'reasoning_text','text':'opaque exhausted'}]}
        request={'input':[{'role':'user','content':'complex question'},prior,
                          {'type':'function_call','call_id':'scan','name':'scan_facts','arguments':'{}'},
                          {'type':'function_call_output','call_id':'scan','output':'finite facts'}]}
        result=continuation_history(request,{'output':[incomplete]})
        self.assertEqual(result.reasoning_items,2)
        self.assertEqual(result.input()[:-2],request['input'])
        self.assertEqual(result.input()[-2],incomplete)
        with self.assertRaises(ValueError):
            result.append_response({'output':[{'type':'function_call','call_id':'scan','name':'scan_facts','arguments':'{}'}]})
        result.snapshot()[1]['content'][0]['text']='changed'
        self.assertEqual(prior['content'][0]['text'],'opaque prior')


if __name__=='__main__':unittest.main()
