;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine configuration facade for existing config consumers.
;;; Invariant: interface.ss is the sole public module entrypoint; this role
;;; never imports outward through interface.ss.

(import :poo-flow/modules/module-authoring/module-config-syntax
        "core.ss"
        "policy-extension.ss"
        "runtime.ss"
        "runtime-projection.ss")

(export poo-flow-loop-engine-configs
        (import: "core.ss")
        (import: "policy-extension.ss")
        (import: "runtime.ss")
        (import: "runtime-projection.ss"))

;;; Module-owned user syntax delegates to the one generic config lowering.
(defsyntax (poo-flow-loop-engine-configs stx)
  (syntax-case stx ()
    ((_ config-form ...)
     (syntax
      (poo-flow-module-configs
       loop-engine
       poo-flow-user-loop-engine-poo-config-flags
       (quoted :config config-form ...)
       config-form ...)))))
