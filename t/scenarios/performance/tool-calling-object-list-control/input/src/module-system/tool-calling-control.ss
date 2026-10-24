;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o .ref))

;;; Scenario input: this is the rejected hot-path shape.
;;; It keeps public POO objects, but reuses slot identifiers as RHS bindings and
;;; rebuilds index data at the same object boundary.  In Gerbil POO this can
;;; force expansion/runtime lookup onto a pathological path.

(def (agentic-ai-lab-tool-call-entry key value)
  (.o (kind 'agentic-ai-lab-tool-call-entry)
      (key key)
      (value value)))

(def (agentic-ai-lab-tool-call-plan name entries)
  (.o (kind 'agentic-ai-lab-tool-call-plan)
      (name name)
      (entries entries)
      (index (map (lambda (entry)
                    (cons (.ref entry 'key)
                          (.ref entry 'value)))
                  entries))))

(def (agentic-ai-lab-tool-call-fact-set name entries)
  (.o (kind 'agentic-ai-lab-tool-call-fact-set)
      (name name)
      (entries entries)
      (index (map (lambda (entry)
                    (cons (.ref entry 'key)
                          (.ref entry 'value)))
                  entries))))
