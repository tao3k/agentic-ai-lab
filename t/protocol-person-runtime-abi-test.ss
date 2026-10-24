;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :agentic-ai-lab/modules/governance/policy/protocol-person-promotion
        :agentic-ai-lab/modules/workflow/contracts/runtime-v0-abi-schema
        :agentic-ai-lab/modules/workflow/contracts/protocol-person-runtime-abi)

(export protocol-person-runtime-abi-test)

(def provenance
  (agentic-ai-lab-provenance
   'org-bundle "source-digest-1" 101 '("parent-digest-0") '(receipt-1)))

(def intent
  (agentic-ai-lab-promotion-intent
   'promotion-1 "candidate-digest-1" 'subject-1 'commitment-1
   'history 'active 'organization 11 7 5 3 "evidence-root-1"
   'materialization-1 'org-bundle-active 'history-slot-1))

(def current-world
  (agentic-ai-lab-promotion-world 11 7 5 3))

(def stale-world
  (agentic-ai-lab-promotion-world 12 7 5 3))

(def approved-facts
  (agentic-ai-lab-promotion-decision-facts #t #t #t #t 0 #f))

(def denied-facts
  (agentic-ai-lab-promotion-decision-facts #f #t #t #t 0 #f))

(def approval-receipt
  (agentic-ai-lab-promotion-intent-validate intent current-world approved-facts))

(def required-capabilities
  +agentic-ai-lab-runtime-language-promotion-required-capabilities+)

(def request
  (agentic-ai-lab-runtime-language-promotion-request intent approval-receipt))

(def (read-text-file path)
  (call-with-input-file
   path
   (lambda (port)
     (let loop ((characters '()))
       (let (character (read-char port))
         (if (eof-object? character)
             (list->string (reverse characters))
             (loop (cons character characters))))))))

(def (runtime-receipt world capabilities outcome
                      materialization injection rollback causal . maybe-attempt)
  (agentic-ai-lab-runtime-language-promotion-receipt
   request world 'python-runtime "0.1.0" 'python capabilities
   (if (pair? maybe-attempt) (car maybe-attempt) 1)
   outcome materialization injection rollback causal))

(def protocol-person-runtime-abi-test
  (test-suite
   "RFC 150 Runtime Language ABI promotion lane"

   (yuanxu-test-case "approved promotion lowers to an implementation-neutral request"
     (let (key (.ref request 'idempotency-key))
       (check (.ref request 'kind)
              => 'agentic-ai-lab.runtime-language.promotion-request.1)
       (check (.ref request 'abi-minor) => 1)
       (check (.ref request 'runtime-executed) => #f)
       (check (.ref key 'promotion-id) => 'promotion-1)
       (check (.ref key 'materialization-id) => 'materialization-1)
       (check (.ref key 'candidate-digest) => "candidate-digest-1")
       (check (.ref key 'injection-target) => 'org-bundle-active)
       (check (.ref request 'required-capabilities) => required-capabilities)))

   (yuanxu-test-case "unapproved promotion cannot cross the ABI boundary"
     (let (denied
           (agentic-ai-lab-promotion-intent-validate intent current-world denied-facts))
       (check
        (with-catch
         (lambda (_failure) #t)
         (lambda ()
           (agentic-ai-lab-runtime-language-promotion-request intent denied)
           #f))
        => #t)))

   (yuanxu-test-case "qualification vector and C header share the ABI identity"
     (let ((vector (agentic-ai-lab-runtime-language-promotion-request->vector request))
           (header (agentic-ai-lab-runtime-language-promotion-abi->c-header))
           (runtime-header
            (agentic-ai-lab-runtime-v0-abi-schema->c-header
             +agentic-ai-lab-runtime-v0-abi-schema+)))
       (check vector
              => (read-text-file
                  "t/fixtures/runtime-language-abi/promotion-request-v1.vector"))
       (check (and (string-contains vector "abi-minor=1") #t) => #t)
       (check (and (string-contains vector "promotion-id=promotion-1") #t)
              => #t)
       (check (and (string-contains vector "materialization-id=materialization-1")
                   #t)
              => #t)
       (check (and (string-contains header "PROMOTION_MATERIALIZE") #t)
              => #t)
       (check (and (string-contains header "LANGUAGE_QUALIFICATION") #t)
              => #t)
       (check (and (string-contains header "SOURCE_QUERY_DATA") #t)
              => #t)
       (check (and (string-contains header
                                    "CONTRACT_ADMISSION_RECEIPT")
                   #t)
              => #t)
       (check (and (string-contains header
                                    "CONTRACT_ARTIFACT_PROJECTION")
                   #t)
              => #t)
       (check (and (string-contains header
                                    "QUERY_EXECUTION_CANDIDATE")
                   #t)
              => #t)
       (check (.ref +agentic-ai-lab-runtime-v0-abi-schema+ 'abi-minor) => 1)
       (check (.ref +agentic-ai-lab-runtime-v0-abi-schema+
                    'source-query-receipt-schema)
              => "agentic-ai-lab.runtime-language.source-query-receipt.1")
       (check (.ref +agentic-ai-lab-runtime-v0-abi-schema+
                    'query-execution-candidate-schema)
              => "agentic-ai-lab.query.execution-candidate.1")
       (check (.ref +agentic-ai-lab-runtime-v0-abi-schema+
                    'runtime-admission-receipt-schema)
              => "agentic-ai-lab.runtime-language.admission-receipt.1")
       (check (.ref +agentic-ai-lab-runtime-v0-abi-schema+
                    'contract-artifact-projection-receipt-schema)
              => "agentic-ai-lab.contract.artifact-projection-receipt.1")
       (check (and (string-contains runtime-header
                                    "CAP_LANGUAGE_QUALIFICATION")
                   #t)
              => #t)))

   (yuanxu-test-case "qualified current runtime can return a complete injection receipt"
     (let (receipt
           (runtime-receipt current-world required-capabilities 'injected
                            "materialization-digest-1"
                            "injection-receipt-digest-1" #f #f))
       (check (agentic-ai-lab-runtime-language-promotion-receipt-valid? receipt)
              => #t)
       (check (agentic-ai-lab-runtime-language-promotion-receipt-active? receipt)
              => #t)
       (check (.ref receipt 'runtime-executed) => #t)))

   (yuanxu-test-case "capability negotiation fails closed"
     (let ((rejected
            (runtime-receipt current-world '(PROMOTION_MATERIALIZE)
                             'rejected-capability #f #f #f #f))
           (illegal
            (runtime-receipt current-world '(PROMOTION_MATERIALIZE)
                             'injected "materialization-digest-1"
                             "injection-receipt-digest-1" #f #f)))
       (check (agentic-ai-lab-runtime-language-promotion-receipt-valid? rejected)
              => #t)
       (check (agentic-ai-lab-runtime-language-promotion-receipt-valid? illegal)
              => #f)
       (check (memq 'unsupported-capability-effect
                    (agentic-ai-lab-runtime-language-promotion-receipt-failures
                     illegal))
              => '(unsupported-capability-effect))))

   (yuanxu-test-case "runtime epoch fence rejects stale requests before effects"
     (let ((rejected
            (runtime-receipt stale-world required-capabilities
                             'rejected-stale-epoch #f #f #f #f))
           (illegal
            (runtime-receipt stale-world required-capabilities 'injected
                             "materialization-digest-1"
                             "injection-receipt-digest-1" #f #f)))
       (check (agentic-ai-lab-runtime-language-promotion-receipt-valid? rejected)
              => #t)
       (check (agentic-ai-lab-runtime-language-promotion-receipt-valid? illegal)
              => #f)
       (check (memq 'stale-epoch-effect
                    (agentic-ai-lab-runtime-language-promotion-receipt-failures
                     illegal))
              => '(stale-epoch-effect))))

   (yuanxu-test-case "injection and rollback receipts are structurally complete"
     (let ((incomplete
            (runtime-receipt current-world required-capabilities 'injected
                             "materialization-digest-1" #f #f #f))
           (rolled-back
            (runtime-receipt current-world required-capabilities 'rolled-back
                             #f #f "rollback-receipt-digest-1" #f)))
       (check (agentic-ai-lab-runtime-language-promotion-receipt-valid? incomplete)
              => #f)
       (check (agentic-ai-lab-runtime-language-promotion-receipt-valid? rolled-back)
              => #t)))

   (yuanxu-test-case "replay is causal and does not count as a second commit"
     (let* ((injected
             (runtime-receipt current-world required-capabilities 'injected
                              "materialization-digest-1"
                              "injection-receipt-digest-1" #f #f))
            (replay
             (runtime-receipt current-world required-capabilities
                              'replayed-active
                              "materialization-digest-1"
                              "injection-receipt-digest-1" #f
                              "original-runtime-receipt-digest" 2))
            (duplicate
             (runtime-receipt current-world required-capabilities 'injected
                              "materialization-digest-2"
                              "injection-receipt-digest-2" #f #f 2)))
       (check (agentic-ai-lab-runtime-language-promotion-receipt-valid? replay)
              => #t)
       (check
        (agentic-ai-lab-runtime-language-promotion-receipts-exactly-once?
         (list injected replay))
        => #t)
       (check
        (agentic-ai-lab-runtime-language-promotion-receipts-exactly-once?
         (list injected duplicate))
        => #f)))

   (yuanxu-test-case "Org AST query results remain data before Contract admission"
     (let ((json-query
            (agentic-ai-lab-runtime-language-source-query-receipt
             'org "org-content-blake3-1" "7"
             'orgize "0.10" 'promotion-candidates "3"
             '(node-17 node-23) 'json
             "org-provenance-root-1" "query-result-digest-json-1"))
           (ast-query
            (agentic-ai-lab-runtime-language-source-query-receipt
             'org "org-content-blake3-1" "7"
             'orgize "0.10" 'promotion-candidates "3"
             '(node-17 node-23) 'ast-data
             "org-provenance-root-1" "query-result-digest-ast-1")))
       (check
        (agentic-ai-lab-runtime-language-source-query-receipt-valid? json-query)
        => #t)
       (check
        (agentic-ai-lab-runtime-language-source-query-receipt-valid? ast-query)
        => #t)
       (check (.ref json-query 'source-language) => 'org)
       (check (.ref json-query 'representation) => 'json)
       (check (.ref ast-query 'representation) => 'ast-data)
       (check (.ref json-query 'result-digest)
              => "query-result-digest-json-1")))

   (yuanxu-test-case "source query identity and provenance fail closed"
     (let ((missing-nodes
            (agentic-ai-lab-runtime-language-source-query-receipt
             'org "org-content-blake3-1" "7"
             'orgize "0.10" 'promotion-candidates "3"
             '() 'json "org-provenance-root-1" #f))
           (unsupported
            (agentic-ai-lab-runtime-language-source-query-receipt
             'org "org-content-blake3-1" "7"
             'orgize "0.10" 'promotion-candidates "3"
             '(node-17) 'raw-text
             "org-provenance-root-1" "query-result-digest-raw-1"))
           (numeric-version
            (agentic-ai-lab-runtime-language-source-query-receipt
             'org "org-content-blake3-1" 7
             'orgize "0.10" 'promotion-candidates "3"
             '(node-17) 'json
             "org-provenance-root-1" "query-result-digest-json-1")))
       (check
        (agentic-ai-lab-runtime-language-source-query-receipt-valid? missing-nodes)
        => #f)
       (check
        (memq 'missing-selected-node-identities
              (agentic-ai-lab-runtime-language-source-query-receipt-failures
               missing-nodes))
        => '(missing-selected-node-identities missing-query-result-digest))
       (check
        (agentic-ai-lab-runtime-language-source-query-receipt-valid? unsupported)
        => #f)
       (check
        (memq 'unsupported-source-representation
              (agentic-ai-lab-runtime-language-source-query-receipt-failures
               unsupported))
        => '(unsupported-source-representation))
       (check
        (agentic-ai-lab-runtime-language-source-query-receipt-valid?
         numeric-version)
        => #f)
       (check
        (memq 'missing-source-version
              (agentic-ai-lab-runtime-language-source-query-receipt-failures
               numeric-version))
        => '(missing-source-version))))

   (yuanxu-test-case "Runtime Language admission requires the identified POO Contract"
     (let* ((query
             (agentic-ai-lab-runtime-language-source-query-receipt
              'org "org-content-blake3-1" "7"
              'orgize "0.10" 'promotion-candidates "3"
              '(node-17 node-23) 'json
              "org-provenance-root-1" "query-result-digest-json-1"))
            (admitted
             (agentic-ai-lab-runtime-language-admission-receipt
              query (.ref request 'kind) "1"
              'agentic-ai-lab-python-runtime "0.1" 'python
              "normalized-contract-semantics-1" 'admitted '()))
            (rejected
             (agentic-ai-lab-runtime-language-admission-receipt
              query (.ref request 'kind) "1"
              'marlin-gerbil-scheme "0.1" 'rust
              #f 'rejected '(contract-field-mismatch)))
            (illegal
             (agentic-ai-lab-runtime-language-admission-receipt
              query #f "1"
              'agentic-ai-lab-python-runtime "0.1" 'python
              "normalized-contract-semantics-1" 'admitted
              '(ignored-failure))))
       (check
        (agentic-ai-lab-runtime-language-admission-receipt-valid? admitted)
        => #t)
       (check
        (agentic-ai-lab-runtime-language-admission-receipt-admitted? admitted)
        => #t)
       (check (.ref admitted 'contract-id) => (.ref request 'kind))
       (check (.ref admitted 'source-query-result-digest)
              => "query-result-digest-json-1")
       (check
        (agentic-ai-lab-runtime-language-admission-receipt-valid? rejected)
        => #t)
       (check
        (agentic-ai-lab-runtime-language-admission-receipt-admitted? rejected)
        => #f)
       (check
        (agentic-ai-lab-runtime-language-admission-receipt-valid? illegal)
        => #f)
       (check
        (agentic-ai-lab-runtime-language-admission-receipt-failures illegal)
        => '(missing-contract-id admitted-projection-has-failures))))

   (yuanxu-test-case "Contract artifact projections do not require a source query"
     (let ((vector-receipt
            (agentic-ai-lab-contract-artifact-projection-receipt
             'promotion-request-vector-v1
             (.ref request 'kind) "1" "poo-contract-digest-1"
             'agentic-ai-lab-runtime-v0-abi-projector "0.3"
             'abi-vector
             "t/fixtures/runtime-language-abi/promotion-request-v1.vector"
             "promotion-vector-digest-1"))
           (header-receipt
            (agentic-ai-lab-contract-artifact-projection-receipt
             'runtime-v0-c-header-v3
             (.ref +agentic-ai-lab-runtime-v0-abi-schema+ 'kind) "1"
             "runtime-v0-contract-digest-1"
             'agentic-ai-lab-runtime-v0-abi-projector "0.3"
             'c-header
             "bindings/runtime-c/include/agentic_ai_lab/runtime_v0_contract.h"
             "runtime-v0-header-digest-1"))
           (invalid
            (agentic-ai-lab-contract-artifact-projection-receipt
             'invalid-projection
             (.ref request 'kind) "1" "poo-contract-digest-1"
             'agentic-ai-lab-runtime-v0-abi-projector "0.3"
             'raw-text "invalid-artifact" #f)))
       (check
        (agentic-ai-lab-contract-artifact-projection-receipt-valid?
         vector-receipt)
        => #t)
       (check
        (agentic-ai-lab-contract-artifact-projection-receipt-valid?
         header-receipt)
        => #t)
       (check (.ref vector-receipt 'artifact-kind) => 'abi-vector)
       (check (.ref header-receipt 'artifact-kind) => 'c-header)
       (check
        (agentic-ai-lab-contract-artifact-projection-receipt-valid? invalid)
        => #f)
       (check
        (agentic-ai-lab-contract-artifact-projection-receipt-failures invalid)
        => '(unsupported-artifact-kind missing-output-digest))))))
