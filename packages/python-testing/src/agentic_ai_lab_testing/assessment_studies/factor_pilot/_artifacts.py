# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

"""Artifacts for the factor pilot study."""

import hashlib, json


def sha(b):
    return hashlib.sha256(b).hexdigest()


def save(p, x):
    p.write_text(json.dumps(x, ensure_ascii=False, indent=2) + "\n")
