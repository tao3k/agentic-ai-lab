# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
import pytest
from agentic_ai_lab_runtime.scheme_wire import dumps, loads


def test_scheme_data_roundtrip():
    value = {'text': '时态\n"\\', 'list': [False, None, -2, 0.25], 'empty': {}}
    assert loads(dumps(value)) == value
    assert dumps({'z': 1, 'a': 2}) == dumps({'a': 2, 'z': 1})


@pytest.mark.parametrize('text', ['{}', '#.(exit)', '#0=(list #0#)', "'x", '(object ("x" 1) ("x" 2))', '(list) (list)', '(list +inf.0)', '(list . (list))', '(object ("a" 1 2))', '(list '+ '(list '*65 +')'*65+')'])
def test_scheme_reader_rejects_extensions_and_ambiguous_data(text):
    with pytest.raises(ValueError):
        loads(text)
