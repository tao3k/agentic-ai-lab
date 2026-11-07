;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine runtime agent row/list projection helpers.
;;; Invariant: helpers are pure datum transforms over already-materialized
;;; receipt rows; they do not realize runtime sessions or tool calls.

(import (only-in :std/list/list delete-duplicates/hash)
        "core.ss")

(export agentic-ai-lab-loop-engine-runtime-agent-field-values
        agentic-ai-lab-loop-engine-runtime-agent-flat-field-values
        agentic-ai-lab-loop-engine-runtime-agent-unique)

;;; Field projection preserves row order for receipt comparison.
;; : (forall (a) (-> [Alist] Symbol [a]))
;; : (-> [Alist] Symbol [Datum])
(def (agentic-ai-lab-loop-engine-runtime-agent-field-values rows key)
  (map (lambda (row)
         (agentic-ai-lab-user-loop-engine-intent-ref row key #f))
       rows))

;;; Flat field projection preserves row and in-row order without building
;;; intermediate nested rows.
;; : (forall (a) (-> [Alist] Symbol [a]))
;; : (-> [Alist] Symbol [Datum])
(def (agentic-ai-lab-loop-engine-runtime-agent-flat-field-values rows key)
  (reverse
   (foldl (lambda (row values)
            (let (value
                  (agentic-ai-lab-user-loop-engine-intent-ref row key #f))
              (cond
               ((not value) values)
               ((list? value) (foldl cons values value))
               (else (cons value values)))))
          '()
          rows)))

;;; Uniqueness keeps the first visible declaration for topology diagnostics.
;; : (-> [Datum] [Datum])
(def (agentic-ai-lab-loop-engine-runtime-agent-unique values)
  (delete-duplicates/hash values from-end?: #t))
