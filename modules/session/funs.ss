;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session config data and linear row projection functions.
;;; Invariant: functions stay below syntax/config and perform no runtime work.

(import "funs-attempt.ss"
        (only-in :clan/poo/object .ref)
        :core/module-system/selection/objects
        :poo-flow/modules/module-authoring/module-config-syntax)

(export (import: "funs-attempt.ss") +poo-flow-session-config-kind+
        session-config
        poo-flow-session-poo-config?
        poo-flow-session-poo-config->rows
        poo-flow-session-poo-configs->rows
        poo-flow-session-poo-config-flags)

(def (poo-flow-session-config-rows/tail rows tail)
  (append rows tail))

(def +poo-flow-session-config-kind+ 'poo-flow.session.config)

(defpoo-module-config-prototype
  session-config
  (slots ((kind +poo-flow-session-config-kind+)
          (rows '())
          (metadata '())
          (runtime-owner "marlin-agent-core")
          (runtime-executed #f))))

(defpoo-module-config-kind-predicate
  poo-flow-session-poo-config?
  +poo-flow-session-config-kind+)

(def (poo-flow-session-poo-config->rows config)
  (let (rows (.ref config 'rows))
    (if (list? rows)
      rows
      (error "session config rows must be a list" rows))))

(def (poo-flow-session-poo-configs->rows configs)
  (cond
   ((null? configs) '())
   ((pair? configs)
    (poo-flow-session-config-rows/tail
     (poo-flow-session-poo-config->rows (car configs))
     (poo-flow-session-poo-configs->rows (cdr configs))))
   (else
    (error "session POO configs must be a list" configs))))

(def (poo-flow-session-poo-config-flags prototypes user-config)
  (let* ((configs (filter poo-flow-session-poo-config? prototypes))
         (rows (poo-flow-session-poo-configs->rows configs)))
    (list '+policy
          '+typed-receipts
          (cons ':config rows)
          (cons ':session-rows rows)
          (cons ':session-config-prototypes configs)
          (cons ':user-config user-config))))
