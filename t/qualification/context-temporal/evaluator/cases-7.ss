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
(import "./fixtures.ss")
(export register-evaluator-cases-7!)

(def (register-evaluator-cases-7!)

    (yuanxu-test-case "hypothetical premise and empty query have no source-only positive admission"
      (let* ((s (reasoning-source-snapshot 'graph 1 '((edge 2 ((1 2))))))
             (hypothetical '(candidate (relation path 2) (fact edge 2 3)
                              (rule (path ?x ?y) (edge ?x ?y))
                              (rule (path ?x ?z) (path ?x ?y) (edge ?y ?z))
                              (query path 1 3) (limits 8 16 32)))
             (h (reasoning-attempt s hypothetical 512))
             (empty (reasoning-attempt s proposal 512)))
        (check (reasoning-receipt-status h) => 'complete)
        (check-rejected (admit s hypothetical h) )
        (check (reasoning-receipt-status empty) => 'complete)
        (check-rejected (admit s proposal empty) )))
    (yuanxu-test-case "host refresh selects registered time and refuses stale generation"
      (let* ((host (agentic-ai-lab-temporal-support-policy-host)) (p (policy "rev1"))
             (registered (agentic-ai-lab-temporal-support-policy-host-refresh! host p 1 (at 1)))
             (historical (guard host 1 p)))
        (check (.ref registered 'generation) => 1)
        (check (.ref historical 'policy-status) => 'applicable)
        (agentic-ai-lab-temporal-support-policy-host-refresh! host p 2 (at 4))
        (check (.ref (guard host 2 p) 'policy-status) => 'expired-policy)
        (check-rejected (guard host 1 p) )
        (check (.ref (agentic-ai-lab-temporal-support-guard-replay historical program journal p) 'policy-status) => 'applicable)
        (check (.ref (guard host 2 p) 'action-authorized?) => #f)))
    (yuanxu-test-case "host replacement preserves revision identity and rollback failures preserve current"
      (let* ((host (agentic-ai-lab-temporal-support-policy-host)) (old (policy "rev1")) (new (policy "rev2")))
        (agentic-ai-lab-temporal-support-policy-host-refresh! host old 1 (at 1))
        (agentic-ai-lab-temporal-support-policy-host-refresh! host new 2 (at 2))
        (check (.ref (guard host 2 old) 'policy-status) => 'stale-policy)
        (check (.ref (guard host 2 new) 'policy-status) => 'applicable)
        (check-rejected (agentic-ai-lab-temporal-support-policy-host-refresh! host old 1 (at 2)) )
        (check-rejected (agentic-ai-lab-temporal-support-policy-host-refresh! host new 3 (at 1)) )
        (check-rejected (agentic-ai-lab-temporal-support-policy-host-refresh! host old 2 (at 2)) )
        (check-rejected (agentic-ai-lab-temporal-support-policy-host-refresh! host
          (agentic-ai-lab-temporal-support-policy "policy" "rev2" (at 1) (at 6)) 3 (at 3)) )
        (check (.ref (guard host 2 new) 'policy-status) => 'applicable)))
    (yuanxu-test-case "host capability instances are isolated and exact snapshot replay is idempotent"
      (let* ((a (agentic-ai-lab-temporal-support-policy-host)) (b (agentic-ai-lab-temporal-support-policy-host))
             (p (policy "rev1"))
             (first (agentic-ai-lab-temporal-support-policy-host-refresh! a p 1 (at 1))))
        (check-rejected (guard b 1 p) )
        (check (.ref (agentic-ai-lab-temporal-support-policy-host-refresh! a p 1 (at 1)) 'generation) => 1)
        (check (.ref (guard a 1 p) 'source-authenticated?) => #f)
        (check-rejected (agentic-ai-lab-temporal-support-policy-host-refresh! a p 2
          (agentic-ai-lab-temporal-instant "wrong" "foreign" 2 "host" 'observed)) )
        (check-rejected (agentic-ai-lab-temporal-support-policy-host-refresh! a p 2
          (agentic-ai-lab-temporal-instant "uncertain" "txn" 2 "host" 'uncertain)) )
        (check (.ref first 'durable?) => #f)))
    (yuanxu-test-case "original evaluator rule node tamper rejects despite intact native rows and binding"
      (let* ((s (source 1)) (receipt (reasoning-attempt s proposal 512))
             (nodes (positive-proof-nodes (reasoning-receipt-proof receipt)))
             (last-node (list-ref nodes (- (length nodes) 1))))
        (set-car! (proof-node-row last-node) 99)
        (check (reasoning-receipt-bound? receipt s proposal) => #t)
        (check (reasoning-receipt-rows receipt) => '((1 3)))
        (check-rejected (admit s proposal receipt) )))
    (yuanxu-test-case "full host revision inventory rejects overflow without replacing current"
      (let ((host (agentic-ai-lab-temporal-support-policy-host)))
        (let loop ((n 1))
          (when (<= n 128)
            (agentic-ai-lab-temporal-support-policy-host-refresh! host (policy (number->string n)) n (at 1))
            (loop (+ n 1))))
        (check-rejected (agentic-ai-lab-temporal-support-policy-host-refresh! host (policy "129") 129 (at 1)) )
        (check (.ref (guard host 128 (policy "128")) 'policy-status) => 'applicable)))
    (yuanxu-test-case "positive query row projection uses canonical set order"
      (let* ((s (source 1))
             (all '(candidate (relation path 2)
                     (rule (path ?x ?y) (edge ?x ?y))
                     (rule (path ?x ?z) (path ?x ?y) (edge ?y ?z))
                     (query path ?x ?y) (limits 8 16 32)))
             (receipt (reasoning-attempt s all 512))
             (a (admit s all receipt)))
        (check (.ref a 'rows) => '((1 2) (1 3) (2 3)))
        (check (.ref (agentic-ai-lab-temporal-positive-proof-replay a s all receipt 512 32) 'semantic-digest)
               => (.ref a 'semantic-digest))))
    (yuanxu-test-case "proof root and exact source leaves bind fact content into Temporal support"
      (let* ((s (source 1)) (receipt (reasoning-attempt s proposal 512)) (a (admit s proposal receipt))
             (root (car (positive-proof-roots (reasoning-receipt-proof receipt))))
             (leaves (filter (lambda (n) (eq? (proof-node-kind n) 'source))
                             (positive-proof-nodes (reasoning-receipt-proof receipt))))
             (facts (map (lambda (n) (agentic-ai-lab-temporal-mrr-fact-content
                       (number->string (proof-node-id n)) "generation" "edge-id" "edge" (proof-node-row n))) leaves))
             (out (agentic-ai-lab-temporal-mrr-fact-content "output" "generation" "path-id" "path" '(1 3)))
             (bindings (map (lambda (n f) (agentic-ai-lab-temporal-proof-source-binding (proof-node-id n)
                            f (.ref f 'identity) (.ref f 'identity))) leaves facts))
             (j (agentic-ai-lab-temporal-evidence-journal "bound" "txn"
                  (map (lambda (f) (agentic-ai-lab-temporal-evidence-revision (.ref f 'identity) (.ref f 'identity)
                    'assert #f (at 1) (agentic-ai-lab-temporal-interval "v" (at 0) (at 10) #t #f)
                    (.ref f 'semantic-digest))) facts)))
             (bound (agentic-ai-lab-temporal-proof-support "derivation" a s proposal receipt 512 32 root out bindings j))
             (p (agentic-ai-lab-temporal-support-program "bound" "policy" #t (list (.ref bound 'support))))
             (current (agentic-ai-lab-temporal-support-evaluate p j (at 1) #f 128)))
        (check (.ref bound 'proof-admitted?) => #t)
        (check (.ref bound 'binding-verified?) => #t)
        (check (.ref bound 'mrr-rule-equivalence-verified?) => #f)
        (check (.ref (car (.ref current 'conclusions)) 'status) => 'supported)
        (let* ((first (car facts))
               (changed (agentic-ai-lab-temporal-evidence-journal "bound" "txn"
                 (append (.ref j 'revisions)
                   (list (agentic-ai-lab-temporal-evidence-revision "correction" (.ref first 'identity)
                     'correct (.ref first 'identity) (at 2)
                     (agentic-ai-lab-temporal-interval "v2" (at 0) (at 10) #t #f) "changed-content"))))))
          (check (.ref (car (.ref (agentic-ai-lab-temporal-support-evaluate p changed (at 2) #f 128) 'conclusions)) 'status) => 'unsupported)
          (check (.ref (car (.ref (agentic-ai-lab-temporal-support-evaluate p changed (at 1) #f 128) 'conclusions)) 'status) => 'supported)
          (check (.ref bound 'proof-admitted?) => #t))
        (check (.ref (agentic-ai-lab-temporal-proof-support-replay bound a s proposal receipt 512 32 out bindings j)
                     'semantic-digest) => (.ref bound 'semantic-digest))
        (check-rejected (agentic-ai-lab-temporal-proof-support "derivation" a s proposal receipt 512 32
          root (agentic-ai-lab-temporal-mrr-fact-content "output" "generation" "path-id" "path" '(1 99)) bindings j) )
        (check-rejected (agentic-ai-lab-temporal-proof-support "derivation" a s proposal receipt 512 32
          root out (cdr bindings) j) )
        (check-rejected (agentic-ai-lab-temporal-proof-support "derivation" a s proposal receipt 512 32
          root out (cons (car bindings) bindings) j) )
        (check-rejected (agentic-ai-lab-temporal-proof-support "derivation" a s proposal receipt 512 32
          root (agentic-ai-lab-temporal-mrr-fact-content "output" "foreign-generation" "path-id" "path" '(1 3)) bindings j) )
        (check-rejected (agentic-ai-lab-temporal-proof-support "derivation" a s proposal receipt 512 32
          root out bindings (agentic-ai-lab-temporal-evidence-journal "wrong" "txn"
            (map (lambda (f) (agentic-ai-lab-temporal-evidence-revision (.ref f 'identity) (.ref f 'identity)
              'assert #f (at 1) (agentic-ai-lab-temporal-interval "v" (at 0) (at 10) #t #f) "unbound-content")) facts))) )
        (check-rejected (agentic-ai-lab-temporal-proof-support-replay
          (.o (:: @ bound) output: (.o (:: @ (.ref bound 'output)) row: '(9 9)))
          a s proposal receipt 512 32 out bindings j) )
        (check-rejected (agentic-ai-lab-temporal-proof-support-replay
          (.o (:: @ bound) support: (.o (:: @ (.ref bound 'support)) proof-identity: "forged"))
          a s proposal receipt 512 32 out bindings j) )))
)
