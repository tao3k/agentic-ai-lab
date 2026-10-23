;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public loop-agent facade.
;;; Invariant: this facade exports policy descriptors only, not execution.

(import :agentic-ai-lab/modules/loop-engine/control/descriptor
        :agentic-ai-lab/modules/loop-engine/control/strategy
        :agentic-ai-lab/modules/loop-engine/control/governor
        :agentic-ai-lab/modules/loop-engine/control/governor-marlin
        :agentic-ai-lab/modules/loop-engine/control/human-audit
        :agentic-ai-lab/modules/loop-engine/control/spec-evolution)

(export (import: :agentic-ai-lab/modules/loop-engine/control/descriptor)
        (import: :agentic-ai-lab/modules/loop-engine/control/strategy)
        (import: :agentic-ai-lab/modules/loop-engine/control/governor)
        (import: :agentic-ai-lab/modules/loop-engine/control/governor-marlin)
        (import: :agentic-ai-lab/modules/loop-engine/control/human-audit)
        (import: :agentic-ai-lab/modules/loop-engine/control/spec-evolution))
