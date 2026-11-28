# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Artifacts for the factor budget study."""

import hashlib, json


def sha(b):
    return hashlib.sha256(b).hexdigest()


def save(p, x):
    p.write_text(json.dumps(x, ensure_ascii=False, indent=2) + "\n")


def canonical(x):
    return json.dumps(x, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
