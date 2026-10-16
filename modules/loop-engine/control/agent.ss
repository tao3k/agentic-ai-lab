;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public loop-agent facade.
;;; Invariant: this facade exports policy descriptors only, not execution.

(import :poo-flow/modules/loop-engine/control/descriptor
        :poo-flow/modules/loop-engine/control/strategy
        :poo-flow/modules/loop-engine/control/governor
        :poo-flow/modules/loop-engine/control/governor-marlin
        :poo-flow/modules/loop-engine/control/human-audit
        :poo-flow/modules/loop-engine/control/spec-evolution)

(export (import: :poo-flow/modules/loop-engine/control/descriptor)
        (import: :poo-flow/modules/loop-engine/control/strategy)
        (import: :poo-flow/modules/loop-engine/control/governor)
        (import: :poo-flow/modules/loop-engine/control/governor-marlin)
        (import: :poo-flow/modules/loop-engine/control/human-audit)
        (import: :poo-flow/modules/loop-engine/control/spec-evolution))
