;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .ref))

;;; Scenario expected: native POO remains the control-plane surface.
;;; The repair is object-list/index discipline, not replacing POO with vectors
;;; or raw records.

(def (agentic-ai-lab-tool-call-entry entry-key entry-value)
  (.o (kind 'agentic-ai-lab-tool-call-entry)
      (key entry-key)
      (value entry-value)))

(def (agentic-ai-lab-tool-call-entry-index entry-list)
  (let loop ((rest entry-list) (index-cache '()))
    (if (null? rest)
      index-cache
      (let* ((entry (car rest))
             (entry-key (.ref entry 'key))
             (entry-value (.ref entry 'value)))
        (loop (cdr rest)
              (cons (cons entry-key entry-value)
                    index-cache))))))

(def (agentic-ai-lab-tool-call-plan plan-name plan-entry-list)
  (let ((plan-index-cache
         (agentic-ai-lab-tool-call-entry-index plan-entry-list)))
    (.o (kind 'agentic-ai-lab-tool-call-plan)
        (name plan-name)
        (entries plan-entry-list)
        (index plan-index-cache))))

(def (agentic-ai-lab-tool-call-fact-set fact-set-name fact-entry-list)
  (let ((fact-index-cache
         (agentic-ai-lab-tool-call-entry-index fact-entry-list)))
    (.o (kind 'agentic-ai-lab-tool-call-fact-set)
        (name fact-set-name)
        (entries fact-entry-list)
        (index fact-index-cache))))
