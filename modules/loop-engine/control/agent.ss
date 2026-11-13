;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public loop-agent facade.
;;; Invariant: this facade exports policy descriptors only, not execution.

(import :tao3k/agentic-ai-lab/modules/loop-engine/control/descriptor
        :tao3k/agentic-ai-lab/modules/loop-engine/control/strategy
        :tao3k/agentic-ai-lab/modules/loop-engine/control/governor
        :tao3k/agentic-ai-lab/modules/loop-engine/control/governor-marlin
        :tao3k/agentic-ai-lab/modules/loop-engine/control/human-audit
        :tao3k/agentic-ai-lab/modules/loop-engine/control/spec-evolution)

(export (import: :tao3k/agentic-ai-lab/modules/loop-engine/control/descriptor)
        (import: :tao3k/agentic-ai-lab/modules/loop-engine/control/strategy)
        (import: :tao3k/agentic-ai-lab/modules/loop-engine/control/governor)
        (import: :tao3k/agentic-ai-lab/modules/loop-engine/control/governor-marlin)
        (import: :tao3k/agentic-ai-lab/modules/loop-engine/control/human-audit)
        (import: :tao3k/agentic-ai-lab/modules/loop-engine/control/spec-evolution))
