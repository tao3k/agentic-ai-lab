;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Expected: durable identity is projected once into a POO receipt family.

(import (only-in :clan/poo/object .o .ref))

(def durable-receipt-family
  (.o (kind 'durable-receipt-family)
      (name 'durable-receipt-family)
      (source 'agentic-ai-lab.performance.durable-receipt)))

(def (durable-receipt job-id-value
                      operation-value
                      store-value
                      artifact-value
                      status-value)
  (.o (family 'durable-receipt-family)
      (job-id job-id-value)
      (operation operation-value)
      (store store-value)
      (artifact artifact-value)
      (status status-value)))

(def durable-receipt-value
  (durable-receipt 'job-42 'checkpoint 'turso 'artifact-42 'committed))

(def (durable-receipt-hot-loop receipt rounds)
  (let ((job-id-value (.ref receipt 'job-id))
        (artifact-value (.ref receipt 'artifact)))
    (let loop ((round 0) (accepted 0))
      (if (>= round rounds)
        accepted
        (loop (+ round 1)
              (if (and job-id-value artifact-value)
                (+ accepted 1)
                accepted))))))
