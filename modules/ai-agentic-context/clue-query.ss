;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :gerbil-ascent/rules/interface)
(export make-clue-query-evidence)

;; The same declaration is loaded by the Rust Evidence runtime.
(include "../../packages/python-runtime/src/agentic_ai_lab_runtime/reasoning_rules/clue_query_rules.ss")
