;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Expected: runtime request shape is projected once into a POO family.

(import (only-in :clan/poo/object .o .ref))

(def runtime-request-family
  (.o (kind 'runtime-request-family)
      (name 'runtime-request-family)
      (source 'agentic-ai-lab.performance.runtime-request)))

(def (runtime-request-family-object request-id-value
                                    runtime-value
                                    operation-value
                                    policy-value
                                    artifact-value)
  (.o (family 'runtime-request-family)
      (request-id request-id-value)
      (runtime runtime-value)
      (operation operation-value)
      (policy policy-value)
      (artifact artifact-value)))

(def runtime-request
  (runtime-request-family-object 'request-42
                                 'rust
                                 'tool-call
                                 'proof-gated
                                 'artifact-42))

(def (runtime-request-hot-loop request rounds)
  (let ((runtime-value (.ref request 'runtime))
        (operation-value (.ref request 'operation))
        (policy-value (.ref request 'policy)))
    (let loop ((round 0) (accepted 0))
      (if (>= round rounds)
        accepted
        (loop (+ round 1)
              (if (and runtime-value operation-value policy-value)
                (+ accepted 1)
                accepted))))))
