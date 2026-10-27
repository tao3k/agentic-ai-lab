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
(export register-evaluator-cases-6!)

(def (register-evaluator-cases-6!)

    (yuanxu-test-case "current proof applies evidence validity and conflicting heads conservatively"
      (let* ((ctx (mrr-derivation-fixture)) (ph (agentic-ai-lab-temporal-support-policy-host))
             (host (agentic-ai-lab-temporal-proof-host ph))
             (p (agentic-ai-lab-temporal-support-policy "policy" "long" (at 1) (at 20)))
             (j (list-ref ctx 9)) (first (car (.ref j 'revisions)))
             (snapshot (agentic-ai-lab-temporal-proof-host-refresh! host "source" 1 (car ctx) j))
             (registration (register-selected host snapshot ctx)))
        (agentic-ai-lab-temporal-support-policy-host-refresh! ph p 1 (at 3))
        (check (.ref (proof-current host registration 1 1 p) 'status) => 'current)
        (let* ((a (agentic-ai-lab-temporal-evidence-journal (.ref j 'identity) (.ref j 'admission-domain-identity)
                    (append (.ref j 'revisions) (list (agentic-ai-lab-temporal-evidence-revision "first-branch"
                      (.ref first 'subject-identity) 'correct (.ref first 'identity) (at 2)
                      (agentic-ai-lab-temporal-interval "v2" (at 0) (at 20) #t #f) "changed")))))
               (conflict (agentic-ai-lab-temporal-evidence-journal (.ref j 'identity) (.ref j 'admission-domain-identity)
                 (append (.ref a 'revisions) (list (agentic-ai-lab-temporal-evidence-revision "other-branch"
                   (.ref first 'subject-identity) 'correct (.ref first 'identity) (at 3)
                   (agentic-ai-lab-temporal-interval "v3" (at 0) (at 20) #t #f) "other"))))))
          (agentic-ai-lab-temporal-proof-host-refresh! host "source" 2 (car ctx) conflict)
          (check (.ref (proof-current host registration 2 1 p) 'status) => 'unknown)
          (agentic-ai-lab-temporal-support-policy-host-refresh! ph p 2 (at 10))
          (check (.ref (proof-current host registration 2 2 p) 'status) => 'unsupported))))
    (yuanxu-test-case "selected recursive MRR Derivation authority and direct premises bind exact source leaves"
      (let* ((ctx (mrr-derivation-fixture)) (bindings (list-ref ctx 6)) (value (derive-selected ctx bindings))
             (qualified-support (.ref value 'support)) (journal-value (list-ref ctx 9))
             (program-value (agentic-ai-lab-temporal-support-program "qualified" "read-only" #t (list qualified-support))))
        (check (.ref value 'derivation-correspondence-verified?) => #t)
        (check (.ref value 'mrr-rule-equivalence-verified?) => #t)
        (check (.ref value 'action-authorized?) => #f)
        (check (.ref qualified-support 'proof-identity) => (.ref value 'semantic-digest))
        (check (length (.ref qualified-support 'premises)) => 2)
        (check (.ref (replay-selected value ctx bindings) 'semantic-digest) => (.ref value 'semantic-digest))
        (check-rejected (replay-selected (.o (:: @ value) node-bindings: '()) ctx bindings) )
        (check-rejected (replay-selected (.o (:: @ value) action-authorized?: #t) ctx bindings) )
        (check-rejected (replay-selected (.o (:: @ value) support: (.o (:: @ qualified-support) proof-identity: "forged")) ctx bindings) )
        (let* ((first (car (.ref journal-value 'revisions)))
               (changed (agentic-ai-lab-temporal-evidence-journal "original-lineage" "txn"
                 (append (.ref journal-value 'revisions) (list (agentic-ai-lab-temporal-evidence-revision "late-correction"
                   (.ref first 'subject-identity) 'correct (.ref first 'identity) (at 2)
                   (agentic-ai-lab-temporal-interval "v2" (at 0) (at 10) #t #f) "changed"))))))
          (check (.ref (car (.ref (agentic-ai-lab-temporal-support-evaluate program-value changed (at 1) #f 128) 'conclusions)) 'status) => 'supported)
          (check (.ref (car (.ref (agentic-ai-lab-temporal-support-evaluate program-value changed (at 2) #f 128) 'conclusions)) 'status) => 'unsupported))
        (when (getenv "AGENTIC_AI_LAB_MRR_DERIVATION_ADMISSION_ORACLE" #f)
          (let (out (make-hash-table))
            (hash-put! out "schema" "agentic-ai-lab.derivation-admission-receipt.v1")
            (for-each (lambda (slot) (hash-put! out (symbol->string slot) (.ref value slot)))
              '(root derivation-identity rule-identity node-bindings support-binding-digest rule-correspondence-digest semantic-digest
                derivation-correspondence-verified? mrr-rule-equivalence-verified? source-authenticated? selection-admitted? action-authorized? durable?))
            (hash-put! out "supportProof" (.ref qualified-support 'proof-identity))
            (call-with-output-file (getenv "AGENTIC_AI_LAB_MRR_DERIVATION_ADMISSION_ORACLE")
              (lambda (port) (display (scheme-wire-write out) port) (newline port)))))))
    (yuanxu-test-case "original direct support cannot be replaced by transitive leaves or another rule"
      (let* ((ctx (mrr-derivation-fixture)) (bindings (list-ref ctx 6)) (root (.ref (list-ref ctx 2) 'root))
             (root-binding (find (lambda (b) (= (.ref b 'node) root)) bindings))
             (d (.ref root-binding 'derivation))
             (replace-root (lambda (changed) (map (lambda (b) (if (= (.ref b 'node) root)
                          (agentic-ai-lab-temporal-proof-node-fact root (.ref root-binding 'fact) changed) b)) bindings)))
             (leaf-ids (map (lambda (b) (.ref (.ref b 'fact) 'identity)) (filter (lambda (b) (not (.ref b 'derivation))) bindings))))
        (check-rejected (derive-selected ctx (cdr bindings)) )
        (check-rejected (derive-selected ctx (append bindings (list (car bindings)))) )
        (check-rejected (derive-selected ctx (replace-root (agentic-ai-lab-temporal-mrr-derivation (.ref d 'identity)
          (.ref d 'rule-identity) (.ref d 'generation) (.ref d 'output) leaf-ids))) )
        (let (base-rule (car (.ref (car ctx) 'rules)))
          (check-rejected (derive-selected ctx (replace-root (agentic-ai-lab-temporal-mrr-derivation (.ref d 'identity)
            (.ref base-rule 'identity) (.ref d 'generation) (.ref d 'output) (.ref d 'supports)))) ))
        (check-rejected (derive-selected ctx (map (lambda (b) (if (= (.ref b 'node) root)
          (agentic-ai-lab-temporal-proof-node-fact root (.ref root-binding 'fact) #f) b)) bindings)) )))
    (yuanxu-test-case "original MRR recursive rules correspond to verified native proof nodes"
      (let* ((p (mrr-rule-program-fixture)) (s (source 1)) (r (reasoning-attempt s proposal 512))
             (a (admit s proposal r))
             (c (agentic-ai-lab-temporal-rule-correspondence-from-ascent p a s proposal r 512 32)))
        (check (.ref c 'rule-correspondence-verified?) => #t)
        (check (pair? (.ref c 'applications)) => #t)
        (for-each (lambda (rule) (check (and (member (.ref rule 'identity) (map cadr (.ref c 'applications))) #t) => #t)) (.ref p 'rules))
        (check (.ref c 'action-authorized?) => #f)
        (check (.ref (agentic-ai-lab-temporal-rule-correspondence-replay c p a s proposal r 512 32) 'semantic-digest) => (.ref c 'semantic-digest))
        (check-rejected (agentic-ai-lab-temporal-rule-correspondence-replay
          (.o (:: @ c) applications: '((999 "forged"))) p a s proposal r 512 32) )
        (check-rejected (agentic-ai-lab-temporal-rule-correspondence-replay
          (.o (:: @ c) action-authorized?: #t) p a s proposal r 512 32) )
        (when (getenv "AGENTIC_AI_LAB_MRR_RULE_CORRESPONDENCE_ORACLE" #f)
          (let (out (make-hash-table))
            (hash-put! out "schema" "agentic-ai-lab.rule-correspondence-receipt.v1")
            (for-each (lambda (slot) (hash-put! out (symbol->string slot) (.ref c slot)))
              '(program-digest proof-digest generation applications semantic-digest rule-correspondence-verified?
                source-authenticated? selection-admitted? action-authorized? durable?))
            (call-with-output-file (getenv "AGENTIC_AI_LAB_MRR_RULE_CORRESPONDENCE_ORACLE")
              (lambda (port) (display (scheme-wire-write out) port) (newline port)))))
        (check-rejected (agentic-ai-lab-temporal-rule-correspondence-from-ascent
          (.o (:: @ p) ascent-generation: 2) a s proposal r 512 32) )
        (check-rejected (agentic-ai-lab-temporal-rule-correspondence-from-ascent
          (.o (:: @ p) rules: (reverse (.ref p 'rules))) a s proposal r 512 32) )
        (let* ((old (car (.ref p 'rules)))
               (wrong (agentic-ai-lab-temporal-rule (.ref old 'identity) (.ref old 'head)
                        (list (agentic-ai-lab-temporal-rule-atom (.ref (.ref old 'head) 'relation-identity)
                          (.ref (.ref old 'head) 'terms)))))
               (changed (agentic-ai-lab-temporal-rule-program (.ref p 'identity) (.ref p 'catalog-digest)
                 (.ref p 'generation) 1 (.ref p 'relations) (cons wrong (cdr (.ref p 'rules))))))
          (check-rejected (agentic-ai-lab-temporal-rule-correspondence-from-ascent changed a s proposal r 512 32) ))))
    (yuanxu-test-case "native rule program rejects unsafe variables typed terms and missing relation"
      (let* ((p (mrr-rule-program-fixture)) (rs (.ref p 'relations)) (old (car (.ref p 'rules)))
             (head (.ref old 'head))
             (rebuild (lambda (rules) (agentic-ai-lab-temporal-rule-program "invalid" (.ref p 'catalog-digest)
                        (.ref p 'generation) 1 rs rules))))
        (check-rejected (rebuild (list (agentic-ai-lab-temporal-rule "unsafe"
          (agentic-ai-lab-temporal-rule-atom (.ref head 'relation-identity)
            (list (agentic-ai-lab-temporal-rule-variable "unbound") (agentic-ai-lab-temporal-rule-variable "y"))) (.ref old 'body)))) )
        (check-rejected (rebuild (list (agentic-ai-lab-temporal-rule "wrong-type" head
          (list (agentic-ai-lab-temporal-rule-atom (.ref (car (.ref old 'body)) 'relation-identity)
            (list (agentic-ai-lab-temporal-rule-literal #t) (agentic-ai-lab-temporal-rule-variable "y"))))))) )
        (check-rejected (rebuild (list (agentic-ai-lab-temporal-rule "missing" head
          (list (agentic-ai-lab-temporal-rule-atom "missing" (.ref head 'terms)))))) )
        (check-rejected (rebuild (list old old)) )))
    (yuanxu-test-case "native positive query and original proof replay produce POO admission"
      (let* ((s (source 1)) (receipt (reasoning-attempt s proposal 512)) (a (admit s proposal receipt))
             (replay (agentic-ai-lab-temporal-positive-proof-replay a s proposal receipt 512 32)))
        (check (reasoning-receipt-status receipt) => 'complete)
        (check (.ref a 'rows) => '((1 3)))
        (check (.ref a 'proof-admitted?) => #t)
        (check (.ref a 'source-authenticated?) => #f)
        (check (.ref a 'selection-admitted?) => #f)
        (check (.ref a 'action-authorized?) => #f)
        (check (.ref a 'durable?) => #f)
        (check (.ref replay 'semantic-digest) => (.ref a 'semantic-digest))))
    (yuanxu-test-case "stale snapshot changed proposal and forged admission reject"
      (let* ((s (source 1)) (receipt (reasoning-attempt s proposal 512)) (a (admit s proposal receipt))
             (changed '(candidate (relation path 2) (rule (path ?x ?y) (edge ?x ?y))
                          (query path 1 2) (limits 8 16 32))))
        (check-rejected (admit (source 2) proposal receipt) )
        (check-rejected (admit s changed receipt) )
        (check-rejected (agentic-ai-lab-temporal-positive-proof-replay
          (.o (:: @ a) proof-digest: "forged") s proposal receipt 512 32) )
        (check-rejected (agentic-ai-lab-temporal-positive-proof-replay
          (.o (:: @ a) rows: '((1 99))) s proposal receipt 512 32) )
        (check-rejected (agentic-ai-lab-temporal-positive-proof-replay
          (.o (:: @ a) action-authorized?: #t) s proposal receipt 512 32) )))
    (yuanxu-test-case "bounded proof and bounded verification do not become admitted"
      (let* ((s (source 1)) (bounded (reasoning-attempt s proposal 1))
             (complete (reasoning-attempt s proposal 512)))
        (check (reasoning-receipt-status bounded) => 'complete)
        (check (positive-proof-status (reasoning-receipt-proof bounded)) => 'bounded)
        (check-rejected (admit s proposal bounded) )
        (check-rejected (admit s proposal complete 512 1) )
        (check-rejected (admit s proposal complete 1 32) )
        (check-rejected (admit s proposal complete 4097 32) )
        (check-rejected (admit s proposal complete 512 129) )))
)
