;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Bounded compiler unit; register the unchanged native Cases in order.
(import (only-in :agentic-ai-lab/modules/workflow/runtime/scheme-wire scheme-wire-read scheme-wire-write)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/objects AiAgenticContextScope.)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/funs-features agentic-ai-lab-ai-agentic-context-profile)
        :agentic-ai-lab/modules/ai-agentic-context/session-host
        :agentic-ai-lab/modules/ai-agentic-context/use-host
        :agentic-ai-lab/modules/session/funs-attempt
        :agentic-ai-lab/modules/query/semantic/context-restriction
        :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock
        :std/test (only-in :clan/poo/object .o .ref object?)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case yuanxu-test-case/with yuanxu-selected-testing-case-profile)
        (only-in :yuanxu/ops/progress execution-progress!)
        (only-in :gerbil-ascent/candidate/checked-program
                 reasoning-source-snapshot reasoning-attempt reasoning-receipt-status reasoning-receipt-proof
                 reasoning-receipt-rows reasoning-receipt-bound?)
        (only-in :gerbil-ascent/candidate/provenance positive-proof-status positive-proof-nodes positive-proof-roots proof-node-id proof-node-kind proof-node-row proof-node-relation proof-node-inputs)
        :agentic-ai-lab/modules/temporal-causality/evaluator/interface
        :agentic-ai-lab/modules/temporal-causality/time/objects
        :agentic-ai-lab/modules/temporal-causality/revisions/interface
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/interface
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host)
(import :agentic-ai-lab/t/qualification/context-temporal/evaluator/fixtures)
(export register-evaluator-cases-8!)

(def (register-evaluator-cases-8!)

    (yuanxu-test-case "fact digest rejects unsupported scalar types and forged content"
      (let (f (agentic-ai-lab-temporal-mrr-fact-content "id" "generation" "relation" "edge" '(1 #t)))
        (check-rejected (agentic-ai-lab-temporal-mrr-fact-content "id" "generation" "relation" "edge" '(1.0)) )
        (check-rejected (agentic-ai-lab-temporal-mrr-fact-content "id" "generation" "relation" "edge" '()) )
        (check-rejected (agentic-ai-lab-temporal-mrr-fact-content-replay (.o (:: @ f) row: '(2 #t))) )))
    (yuanxu-test-case "original MRR fact and Derivation fixture binds to native proof leaves"
      (let* ((cases (call-with-input-file "t/qualification/temporal-library-basic/fact-binding-v1/typed-facts.ss"
                      (lambda (p) (read-line p) (read-line p) (scheme-wire-read (read-line p)))))
             (facts (map (lambda (c) (let (r (hash-ref c "request"))
                       (agentic-ai-lab-temporal-mrr-fact-content (hash-ref r "identity") (hash-ref r "generation")
                         (hash-ref r "relationId") (hash-ref r "evaluatorRelation") (hash-ref r "row")))) cases))
             (inputs (list (car facts) (cadr facts))) (out (caddr facts))
             (origin (hash-ref (caddr cases) "originalDerivation"))
             (s (source 1)) (receipt (reasoning-attempt s proposal 512)) (a (admit s proposal receipt))
             (proof (reasoning-receipt-proof receipt))
             (nodes (filter (lambda (n) (eq? (proof-node-kind n) 'source)) (positive-proof-nodes proof)))
             (bindings (map (lambda (f)
               (let (node (car (filter (lambda (n) (equal? (proof-node-row n) (.ref f 'row))) nodes)))
                 (agentic-ai-lab-temporal-proof-source-binding (proof-node-id node) f (.ref f 'identity) (.ref f 'identity)))) inputs))
             (j (agentic-ai-lab-temporal-evidence-journal "typed" "txn"
                  (map (lambda (f) (agentic-ai-lab-temporal-evidence-revision (.ref f 'identity) (.ref f 'identity)
                    'assert #f (at 1) (agentic-ai-lab-temporal-interval "v" (at 0) (at 10) #t #f)
                    (.ref f 'semantic-digest))) inputs)))
             (bound (agentic-ai-lab-temporal-proof-support (hash-ref origin "identity") a s proposal receipt 512 32
                      (car (positive-proof-roots proof)) out bindings j))
             (support (.ref bound 'support)))
        (for-each (lambda (c f) (check (.ref f 'semantic-digest) => (hash-ref (hash-ref c "expected") "contentDigest"))) cases facts)
        (check (list-sort string<? (map (lambda (f) (.ref f 'identity)) inputs))
               => (list-sort string<? (hash-ref origin "supports")))
        (check (.ref support 'identity) => (hash-ref origin "identity"))
        (check (.ref support 'conclusion-identity) => (hash-ref origin "output"))
        (check (.ref bound 'binding-verified?) => #t)
        (check (.ref bound 'mrr-rule-equivalence-verified?) => #f)
        (check (.ref bound 'action-authorized?) => #f)))
)
