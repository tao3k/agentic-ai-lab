;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Consumer qualification of the pinned package; no new POO causal authority.
(import (only-in :std/error Error?)
        (only-in :agentic-ai-lab/modules/temporal-causality/objects agentic-ai-lab-causal-event agentic-ai-lab-temporal-observation)
        (only-in :agentic-ai-lab/modules/temporal-causality/funs agentic-ai-lab-causal-event-graph agentic-ai-lab-causal-cut)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/objects agentic-ai-lab-temporal-instant)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/uncertainty-funs agentic-ai-lab-temporal-bounded-observation)
        :agentic-ai-lab/modules/temporal-causality/ascent-exchange
        (only-in :std/test test-suite test-case check-equal? check-exception)
        (only-in :clan/poo/object object? .o)
        (only-in :gerbil-ascent/temporal/lens
                 temporal-lens temporal-source temporal-solve temporal-rows
                 temporal-status temporal-evidence-verdicts temporal-verify))
(export ascent-temporal-lens-test)
(def ascent-temporal-lens-test
  (test-suite "pinned ASCENT temporal value consumer"
    (test-case "POO values keep native evidence separate from cut authority"
      (let* ((lens (temporal-lens 0 'owner-clock 0 5 4 'owner-cut '(a b c) 3 #t))
             (source (temporal-source 'owner-source 0 'owner-clock
                       '((a 0 0) (b 1 1) (c 2 4)) '((a b) (b c))))
             (answer (temporal-solve lens source 'a))
             (open (temporal-solve
                    (temporal-lens 0 'owner-clock 0 5 3 'owner-cut '(a b c) 3 #t)
                    source 'a)))
        (check-equal? (object? lens) #t)
        (check-equal? (object? source) #t)
        (check-equal? (object? answer) #t)
        (check-equal? (temporal-status answer) 'complete)
        (check-equal? (temporal-rows answer) '((a b) (a c)))
        (check-equal? (temporal-evidence-verdicts answer) '(valid valid))
        (check-equal? (temporal-verify lens source 'a answer) 'valid)
        (check-equal? (temporal-status open) 'partial)
        (check-equal? (temporal-rows open) [])
        (check-equal? (temporal-evidence-verdicts open) '(not-produced not-produced))
        (check-equal? (temporal-verify lens source 'a open) 'invalid)))
    (test-case "explicit cut bridge preserves uncertainty and original identity binding"
      (def (instant id domain p) (agentic-ai-lab-temporal-instant id domain p "owner" 'observed))
      (def (event id p parents)
        (agentic-ai-lab-causal-event id "subject" 'observed
          (agentic-ai-lab-temporal-observation (string-append id "-logical") 'logical-version p "ledger")
          (string-append id "-payload") parents 'observed #t))
      (let* ((graph (agentic-ai-lab-causal-event-graph "subject"
                      (list (event "A" 0 []) (event "B" 1 '("A")) (event "C" 2 '("B")))))
             (cut (agentic-ai-lab-causal-cut graph 2)))
        (def (bindings upper (provenance "b-valid"))
          (list
           (agentic-ai-lab-ascent-event-binding "A" 'a (instant "a-valid" "valid" 0) (instant "a-known" "knowledge" 0))
           (agentic-ai-lab-ascent-event-binding "B" 'b
             (agentic-ai-lab-temporal-bounded-observation "b-bound" 'event "clock-owner"
               (instant provenance "valid" 1) (instant "b-upper" "valid" upper)
               (- upper 1) (instant "acquired" "ingress" 99) "receipt" #f "attempt" "time.v1")
             (instant "b-known" "knowledge" 1))
           (agentic-ai-lab-ascent-event-binding "C" 'c (instant "c-valid" "valid" 3) (instant "c-known" "knowledge" 4))))
        (def (exchange bs (as-of 4) (closed? #t))
          (agentic-ai-lab-ascent-exchange graph cut bs 'owner-source 0 'owner-clock
            "valid" "knowledge" 'owner-cut 0 5 as-of 3 closed?))
        (let* ((ex (exchange (bindings 2)))
               (answer (agentic-ai-lab-ascent-exchange-solve ex "A")))
          (check-equal? (temporal-status answer) 'complete)
          (check-equal? (temporal-rows answer) '((a b) (a c)))
          (check-equal? (agentic-ai-lab-ascent-exchange-verify ex "A" answer) 'valid)
          (check-equal? (agentic-ai-lab-ascent-exchange-verify
                         (exchange (reverse (bindings 2))) "A" answer) 'valid)
          ;; Identical native bounds and rows; changed original instant identity.
          (check-equal? (agentic-ai-lab-ascent-exchange-verify
                         (exchange (bindings 2 "renamed")) "A" answer) 'invalid)
          (for-each
           (lambda (partial)
             (check-equal? (temporal-status partial) 'partial)
             (check-equal? (temporal-rows partial) [])
             (check-equal? (temporal-evidence-verdicts partial) '(not-produced not-produced)))
           (list (agentic-ai-lab-ascent-exchange-solve (exchange (bindings 5)) "A")
                 (agentic-ai-lab-ascent-exchange-solve (exchange (bindings 2) 3) "A")
                 (agentic-ai-lab-ascent-exchange-solve (exchange (bindings 2) 4 #f) "A")))
          (check-exception (exchange (cdr (bindings 2))) Error?)
          (check-exception
           (agentic-ai-lab-ascent-exchange graph (.o (:: @ cut) identity: "relabeled-cut")
             (bindings 2) 'owner-source 0 'owner-clock "valid" "knowledge" 'owner-cut 0 5 4 3 #t)
           Error?)
          (check-exception
           (agentic-ai-lab-ascent-event-binding "A" 'a
             (agentic-ai-lab-temporal-instant "declared" "valid" 0 "owner" 'declared)
             (instant "known" "knowledge" 0)) Error?)
          (check-exception (exchange (cons (car (bindings 2)) (bindings 2))) Error?)
          (check-exception (agentic-ai-lab-ascent-exchange graph cut (bindings 2) 'owner-source 0 'owner-clock
                            "wrong-domain" "knowledge" 'owner-cut 0 5 4 3 #t) Error?))))))
