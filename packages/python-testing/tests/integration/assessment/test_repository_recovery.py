# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from agentic_ai_lab_testing.assessment_studies.repository_recovery import recover


class RepositoryRecoveryTests(unittest.TestCase):
    def test_recovery_refuses_ambiguous_inventory_before_paid_calls(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);plan=root/'plan';plan.mkdir();(plan/'plan.json').write_text('{}')
            primary=root/'primary';primary.mkdir();interrupted=root/'interrupted';interrupted.mkdir()
            with patch('agentic_ai_lab_testing.assessment_studies.repository_recovery.continue_episode') as resume:
                with self.assertRaisesRegex(ValueError,'exactly one interrupted'):
                    recover(plan,primary,interrupted,root/'output')
                resume.assert_not_called()
                self.assertFalse((root/'output').exists())

    def test_unreceipted_response_cannot_trigger_another_paid_call(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);plan=root/'plan';plan.mkdir();(plan/'plan.json').write_text(json.dumps({'tasks':[{'name':'task'}],'maxTurns':1}))
            primary=root/'primary';primary.mkdir();interrupted=root/'interrupted';interrupted.mkdir()
            name='task-rep-0-scheme-retained';original=interrupted/name;original.mkdir()
            record={'status':'running','task':'task','repetition':0,'arm':'scheme-retained','attempts':[{'turn':1}]}
            (original/'episode.json').write_text(json.dumps(record))
            for i in range(11):
                directory=interrupted/f'terminal-{i}';directory.mkdir();(directory/'episode.json').write_text('{"status":"verified"}')
            source=primary/name;source.mkdir();(source/'1.request.json').write_text('{}');(source/'1.response.json').write_text('{"terminal":{"output":[]}}')
            with patch('agentic_ai_lab_testing.assessment_studies.repository_recovery.continue_episode') as resume:
                with self.assertRaisesRegex(ValueError,'no usage'):
                    recover(plan,primary,interrupted,root/'output')
                resume.assert_not_called()


if __name__=='__main__':unittest.main()
