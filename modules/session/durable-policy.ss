;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Compatibility re-export of Durable's public durable-policy contract.
;;; Shared callers import :tao3k/agentic-ai-lab/modules/durable/interface
;;; so Session stays a closed Yuanxu Module with no reverse cycle.
(import (except-in :tao3k/agentic-ai-lab/modules/durable/interface Durable))
(export (import: :tao3k/agentic-ai-lab/modules/durable/interface))
