;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Expected: proof facts are projected into stable POO family members.

(import (only-in :clan/poo/object .o .ref))

(def proof-fact-family
  (.o (kind 'proof-fact-family)
      (name 'proof-fact-family)
      (source 'agentic-ai-lab.performance.policy-proof)))

(def (proof-fact fact-name status-value source-value)
  (.o (family 'proof-fact-family)
      (name fact-name)
      (status status-value)
      (source source-value)))

(def tool-scope-fact
  (proof-fact 'tool-scope 'passed 'policy))

(def (proof-fact-hot-loop fact rounds)
  (let (status-value (.ref fact 'status))
    (let loop ((round 0) (accepted 0))
      (if (>= round rounds)
        accepted
        (loop (+ round 1)
              (if (eq? status-value 'passed)
                (+ accepted 1)
                accepted))))))
