;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session config data and linear row projection functions.
;;; Invariant: functions stay below syntax/config and perform no runtime work.

(import "funs-attempt.ss"
        (only-in :clan/poo/object .ref)
        :yuanxu/module-system/selection/objects
        :agentic-ai-lab/modules/module-authoring/module-config-syntax)

(export (import: "funs-attempt.ss") +agentic-ai-lab-session-config-kind+
        session-config
        agentic-ai-lab-session-poo-config?
        agentic-ai-lab-session-poo-config->rows
        agentic-ai-lab-session-poo-configs->rows
        agentic-ai-lab-session-poo-config-flags)

(def (agentic-ai-lab-session-config-rows/tail rows tail)
  (append rows tail))

(def +agentic-ai-lab-session-config-kind+ 'agentic-ai-lab.session.config)

(defpoo-module-config-prototype
  session-config
  (slots ((kind +agentic-ai-lab-session-config-kind+)
          (rows '())
          (metadata '())
          (runtime-owner "marlin-agent-core")
          (runtime-executed #f))))

(defpoo-module-config-kind-predicate
  agentic-ai-lab-session-poo-config?
  +agentic-ai-lab-session-config-kind+)

(def (agentic-ai-lab-session-poo-config->rows config)
  (let (rows (.ref config 'rows))
    (if (list? rows)
      rows
      (error "session config rows must be a list" rows))))

(def (agentic-ai-lab-session-poo-configs->rows configs)
  (cond
   ((null? configs) '())
   ((pair? configs)
    (agentic-ai-lab-session-config-rows/tail
     (agentic-ai-lab-session-poo-config->rows (car configs))
     (agentic-ai-lab-session-poo-configs->rows (cdr configs))))
   (else
    (error "session POO configs must be a list" configs))))

(def (agentic-ai-lab-session-poo-config-flags prototypes user-config)
  (let* ((configs (filter agentic-ai-lab-session-poo-config? prototypes))
         (rows (agentic-ai-lab-session-poo-configs->rows configs)))
    (list '+policy
          '+typed-receipts
          (cons ':config rows)
          (cons ':session-rows rows)
          (cons ':session-config-prototypes configs)
          (cons ':user-config user-config))))
