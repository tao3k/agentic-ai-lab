;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; AOT-only leaf. The official build compiles C; importing this leaf acquires
;;; no Context, Session, Actor or journal. The Suite owns runtime acquisition.
(import :std/ffi :agentic-ai-lab/modules/workflow/runtime/semantic)
(export c-roundtrip)
(C-declare "#include \"t/qualification/context-temporal/context-c-caller.c\"")
(def-C-lambda c-roundtrip (int UTF-8-string) int "context_c_roundtrip")
