;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Diagnostic execution costs are process-wide counters, never admission facts.
(import (only-in :clan/poo/object .o .ref)
        (only-in :agentic-ai-lab/t/qualification/context-temporal/evaluator/fixtures
                 authority-fixture clock-original-context policy)
        :agentic-ai-lab/modules/ai-agentic-context/session-host
        :agentic-ai-lab/modules/temporal-causality/evaluator/proof-host
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock)
(export runtime-cost-probe)

(def (require value message) (unless value (error message)))
;;; Gambit's native process-statistics fields: CPU 0+1, wall 2, GC CPU 3+4,
;;; GC count 6, allocated bytes 7. Sampling does not force a collection.
(def (measure phase count operation)
  (let* ((before (##process-statistics))
         (value (let loop ((remaining count) (last #f))
                  (if (= remaining 0) last (loop (- remaining 1) (operation))))))
    (let (after (##process-statistics))
      (def (delta index) (- (f64vector-ref after index) (f64vector-ref before index)))
      (displayln "RUNTIME-COST phase=" phase " count=" count
        " wall=" (delta 2) " cpu=" (+ (delta 0) (delta 1))
        " gc-cpu=" (+ (delta 3) (delta 4)) " gcs=" (delta 6) " allocated=" (delta 7)
        " latest-gc-heap=" (f64vector-ref after 15)
        " latest-gc-live=" (f64vector-ref after 17)))
    value))

(def (runtime-cost-probe)
  (let* ((clock
          (policy-clock-owner
           (lambda ()
             (let (fixture (measure 'context-construction 1
                             (lambda () (authority-fixture #t (clock-original-context) 1000000 #f))))
               (values fixture (.ref fixture 'policies))))
           "txn" 1 1000. 0. 1 #f #f)))
    ;; All host access stays inside the same real owner Actor used by production.
    ;; The timer Actor is present but has no enabled deadline deliveries here.
    (policy-clock-call! clock
      (lambda (fixture)
        (let* ((host (.ref fixture 'host)) (proof (.ref fixture 'proof))
               (registration (.ref (.ref fixture 'registration-a) 'identity))
               (original (.ref (.ref fixture 'registration-a) 'proof-digest))
               (policy-digest (.ref (.ref fixture 'policy) 'semantic-digest)))
          (measure 'retained-proof-read 10
            (lambda ()
              (require (equal? original (agentic-ai-lab-temporal-proof-host-retained-digest proof registration))
                       "Historical proof digest changed")))
          (measure 'current-proof-replay 10
            (lambda ()
              (require (.ref (agentic-ai-lab-temporal-proof-host-current proof registration 1 1 policy-digest 128) 'current?)
                       "Diagnostic proof is not currently supported")))
          (let (checkpoint (measure 'checkpoint 10 (lambda () (context-host-checkpoint host))))
            (measure 'pack-checkpoint 10 (lambda () (journal-pack checkpoint))))
          (context-host-dispose! host)
          ;; Repeated construction/disposal separates steady GC behavior from
          ;; the first collection after imports. All ten scopes share this Actor.
          (measure 'context-construction-repeat 10
            (lambda ()
              (let (next (authority-fixture #t (clock-original-context) 1000000 #f))
                (context-host-dispose! (.ref next 'host)) #t))))))
    (policy-clock-stop! clock)
    (require (.ref (policy-clock-stop-receipt clock) 'owner-joined?) "Diagnostic owner did not join")
    (displayln "MODULE-OK t/context-runtime-cost-test.ss")
    (displayln "HARNESS-OK context-runtime-cost")
    (displayln "OK")))
