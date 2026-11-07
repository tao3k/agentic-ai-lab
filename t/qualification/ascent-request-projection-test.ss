;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test check-equal? check-exception test-case test-suite)
        (only-in :clan/poo/object .o .ref .slot?)
        (only-in :agentic-ai-lab/modules/workflow/qualification/ascent-request-projection
                 agentic-ai-lab-ascent-project-request))

(export ascent-request-projection-test)

(def ascent-request-projection-test
  (test-suite "ASCENT inert request projection"
    (test-case "projects an opaque source identity without a receipt schema"
      (let* ((declaration
              (.o mrr-bundle-identity: "bundle-1"
                  mrr-rule-pack-identity: "pack-1"
                  mrr-generation-identity: "generation-1"
                  organization-epoch: 1
                  capability-identity: "capability-1"
                  max-input-facts: 8
                  max-derived-pairs: 16
                  max-results: 16))
             (request (agentic-ai-lab-ascent-project-request declaration)))
        (check-equal? (.ref request 'mrr-bundle-identity) "bundle-1")
        (check-equal? (.ref request 'capability-identity) "capability-1")
        (check-equal? (.ref request 'runtime-executed?) #f)
        (check-equal? (.slot? request 'expected-receipt-schema) #f)))
    (test-case "rejects a zero evaluation bound"
      (check-exception
       (agentic-ai-lab-ascent-project-request
        (.o mrr-bundle-identity: "bundle-1"
            mrr-rule-pack-identity: "pack-1"
            mrr-generation-identity: "generation-1"
            organization-epoch: 1
            capability-identity: "capability-1"
            max-input-facts: 0
            max-derived-pairs: 16
            max-results: 16))
       true))))
