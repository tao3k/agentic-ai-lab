;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in :agentic-ai-lab/testing-api yuanxu-test-case)
        :agentic-ai-lab/modules/workflow/runtime/scheme-wire :agentic-ai-lab/modules/workflow/runtime/context-restriction)
(export context-restriction-wire-test)
(def (wire x) (scheme-wire-read (scheme-wire-write x)))
(def (restriction readers destinations source start end)
  (hash (schema "agentic-ai-lab.context-restriction.v1") (domain "scope-clock")
    (readers readers) (destinations destinations) (provenance (list source)) (leaseStart start) (leaseEnd end)))
(def (restrictions)
  (list (restriction '("alice" "bob") '("model" "store") "source-a" 1 10)
        (restriction '("bob") '("store") "source-b" 2 8)))
(def context-restriction-wire-test
  (test-suite "Context Library wire projection"
    (yuanxu-test-case "composition and flow remain material-bound declarations"
      (let* ((composed (context-restriction-compose-call (wire
                         (hash (schema "agentic-ai-lab.context-restriction-compose-request.v1") (restrictions (restrictions))))))
             (query (wire (hash (schema "agentic-ai-lab.context-flow-request.v1") (restrictions (restrictions))
                      (expectedRestrictionDigest (hash-ref composed 'bindingDigest))
                      (sourceDigest (string-append "sha256:" (make-string 64 #\a)))
                      (contentDigest (string-append "sha256:" (make-string 64 #\b)))
                      (principal "bob") (destination "store") (declaredAt 2))))
             (flow (context-flow-evaluate-call query)))
        (check (hash-ref (hash-ref composed 'restriction) 'readers) => '("bob"))
        (check (hash-ref (hash-ref composed 'restriction) 'provenance) => '("source-a" "source-b"))
        (check (hash-ref flow 'status) => "eligible")
        (for-each (lambda (k) (check (hash-ref flow k) => #f))
                  '(sourceAuthenticated flowAdmitted actionAuthorized durable))
        (hash-put! query "declaredAt" 8)
        (check (hash-ref (context-flow-evaluate-call query) 'status) => "expired-lease")
        (hash-put! query "expectedRestrictionDigest" "forged")
        (check-exception (context-flow-evaluate-call query) true)
        (hash-put! query "expectedRestrictionDigest" #f)
        (hash-put! query "actionAuthorized" #t)
        (check-exception (context-flow-evaluate-call query) true)))))
