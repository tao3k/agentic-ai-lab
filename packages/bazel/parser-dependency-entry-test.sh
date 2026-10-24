#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 tao3k team and Contributors
# SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
set -euo pipefail
exec "$1" -:max-heap=1G,debug=q "$2" "$3" "$4" "$5" "$6"
