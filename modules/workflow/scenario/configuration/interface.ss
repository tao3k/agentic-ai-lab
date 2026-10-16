;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: stable downstream POO Flow user-interface presentation mechanics.
;;; Invariant: Module System and concrete module APIs are imported through their
;;; own owner interfaces; they never widen this User Interface facade.

(import :poo-flow/modules/workflow/scenario/configuration/entrypoints
        :poo-flow/modules/workflow/scenario/configuration/presentation-config)

(export (import: :poo-flow/modules/workflow/scenario/configuration/entrypoints)
        (import: :poo-flow/modules/workflow/scenario/configuration/presentation-config))
