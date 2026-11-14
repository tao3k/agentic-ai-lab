;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine intent lookup, use-case naming, and runtime ids.
;;; Invariant: helpers normalize report data only; they do not build manifests.

(export agentic-ai-lab-user-loop-engine-intent-ref
        agentic-ai-lab-user-loop-engine-section-ref
        agentic-ai-lab-user-loop-engine-use-case-name
        agentic-ai-lab-user-loop-engine-intent-use-case-name
        agentic-ai-lab-user-loop-engine-use-case-names/add
        agentic-ai-lab-user-loop-engine-use-case-names
        agentic-ai-lab-user-loop-engine-use-case-name?
        agentic-ai-lab-user-loop-engine-runtime-id
        agentic-ai-lab-user-loop-engine-intent-workflow-ref)

;;; Intent lookup is total because partial loop declarations still need a
;;; presentable handoff report and unresolved sandbox diagnostics.
;; : (-> Alist Symbol Value Value)
(def (agentic-ai-lab-user-loop-engine-intent-ref intent key default-value)
  (let (entry (assoc key intent))
    (if entry (cdr entry) default-value)))

;;; Section lookup supports the Doom-style nested config rows where section
;;; names are carried as association keys inside init declarations.
;; : (-> [Value] Symbol Value Value)
(def (agentic-ai-lab-user-loop-engine-section-ref entries key default-value)
  (cond
   ((null? entries) default-value)
   ((and (pair? (car entries))
         (equal? (caar entries) key))
    (cdar entries))
   (else
    (agentic-ai-lab-user-loop-engine-section-ref (cdr entries) key default-value))))

;;; Use-case names become runtime ids, so this normalizer accepts an explicit
;;; single use-case row, then falls back to the first declared use-case list row.
;; : (-> Value [Value] Symbol)
(def (agentic-ai-lab-user-loop-engine-use-case-name use-case use-cases)
  (cond
   ((and (pair? use-case) (symbol? (car use-case))) (car use-case))
   ((and (pair? use-cases)
         (pair? (car use-cases))
         (symbol? (caar use-cases)))
    (caar use-cases))
   (else 'loop-engine)))

;; : (-> Alist Symbol)
(def (agentic-ai-lab-user-loop-engine-intent-use-case-name intent)
  (agentic-ai-lab-user-loop-engine-use-case-name
   (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-case '())
   (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-cases '())))

;;; Use-case accumulation preserves declaration order while ignoring malformed
;;; rows that cannot produce stable runtime identifiers.
;; : (-> [Value] [Symbol])
(def (agentic-ai-lab-user-loop-engine-use-case-names/add use-cases)
  (cond
   ((null? use-cases) '())
   ((and (pair? (car use-cases))
         (symbol? (caar use-cases)))
    (cons (caar use-cases)
          (agentic-ai-lab-user-loop-engine-use-case-names/add (cdr use-cases))))
   (else
    (agentic-ai-lab-user-loop-engine-use-case-names/add (cdr use-cases)))))

;;; The use-case set is intentionally empty when no explicit rows exist. The
;;; runtime workflow ref still falls back through the single-use-case path.
;; : (-> Alist [Symbol])
(def (agentic-ai-lab-user-loop-engine-use-case-names intent)
  (let ((use-case
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-case '()))
        (use-cases
         (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-cases '())))
    (append
     (if (and (pair? use-case) (symbol? (car use-case)))
       (list (car use-case))
       '())
     (agentic-ai-lab-user-loop-engine-use-case-names/add use-cases))))

;;; Use-case membership is Boolean-normalized for sandbox rows that use
;;; `(case . profile)` shorthand.
;; : (-> Symbol [Symbol] Boolean)
(def (agentic-ai-lab-user-loop-engine-use-case-name? value use-case-names)
  (and (member value use-case-names) #t))

;;; Runtime ids are stable report identifiers. They are not executable names and
;;; must remain independent from Marlin CLI routing.
;; : (-> Symbol String Symbol)
(def (agentic-ai-lab-user-loop-engine-runtime-id use-case-name suffix)
  (string->symbol
   (string-append "loop-engine/"
                  (symbol->string use-case-name)
                  "/"
                  suffix)))

;;; Workflow refs fall back to `loop-engine` so incomplete declarations remain
;;; presentable while diagnostics explain missing or malformed sections.
;; : (-> Alist Symbol)
(def (agentic-ai-lab-user-loop-engine-intent-workflow-ref intent)
  (let ((workflow-ref
         (agentic-ai-lab-user-loop-engine-section-ref
          (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-case '())
          'workflow
          #f)))
    (if workflow-ref workflow-ref 'loop-engine)))
