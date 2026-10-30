;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: stable downstream Agentic AI Lab user-interface presentation mechanics.
;;; Invariant: Module System and concrete module APIs are imported through their
;;; own owner interfaces; they never widen this User Interface facade.

(import :agentic-ai-lab/modules/workflow/scenario/configuration/entrypoints
        :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config)

(export (import: :agentic-ai-lab/modules/workflow/scenario/configuration/entrypoints)
        (import: :agentic-ai-lab/modules/workflow/scenario/configuration/presentation-config))
