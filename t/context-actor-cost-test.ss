;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Separate transport, proof and storage costs. Never replace cold qualification.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/sync/channel make-channel)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
                 agentic-ai-lab-temporal-support-policy-host)
        :agentic-ai-lab/t/temporal-evaluator-test
        (prefix-in :agentic-ai-lab/t/context-durable-owner originals.)
        :agentic-ai-lab/modules/ai-agentic-context/durable-owner
        :agentic-ai-lab/modules/ai-agentic-context/session-host
        :agentic-ai-lab/modules/ai-agentic-context/objects
        :agentic-ai-lab/modules/ai-agentic-context/funs-projection
        :agentic-ai-lab/modules/ai-agentic-context/funs-features
        :agentic-ai-lab/modules/query/semantic/context-restriction
        :agentic-ai-lab/modules/temporal-causality/evaluator/proof-host
        :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
        :agentic-ai-lab/modules/temporal-causality/runtime/policy-clock)
(export actor-cost-probe)

(def (require value message) (unless value (error message)))
(def (rejected? operation)
  (with-catch (lambda (error) #t) (lambda () (operation) #f)))
(def (measure phase count operation)
  (let ((before (##process-statistics)) (result #f))
    (let loop ((index 0))
      (when (< index count)
        (set! result (operation index)) (loop (+ index 1))))
    (let (after (##process-statistics))
      (def (delta index) (- (f64vector-ref after index) (f64vector-ref before index)))
      (displayln "ACTOR-COST phase=" phase " count=" count " wall=" (delta 2)
        " cpu=" (+ (delta 0) (delta 1)) " gc-cpu=" (+ (delta 3) (delta 4))
        " gcs=" (delta 6) " allocated=" (delta 7)))
    result))

(def (transport-probe!)
  (let* ((caller (current-thread))
         (echo (thread-start! (make-thread
                 (lambda ()
                   (let loop ()
                     (let (message (thread-receive))
                       (if (eq? message 'stop) 'echo-stopped
                           (begin (thread-send caller message) (loop))))))))))
    (measure 'gambit-mailbox-roundtrip 20000
      (lambda (index)
        (thread-send echo index)
        (require (= (thread-receive 5 'echo-timeout) index) "Native mailbox roundtrip mismatch")))
    ;; A bounded burst measures scheduler throughput separately from synchronous
    ;; caller handoffs; it changes neither the workload nor any authority state.
    (measure 'gambit-mailbox-burst 1
      (lambda (unused)
        (let send ((index 0))
          (when (< index 20000) (thread-send echo index) (send (+ index 1))))
        (let receive ((index 0))
          (when (< index 20000)
            (require (= (thread-receive 5 'burst-timeout) index) "Native mailbox burst mismatch")
            (receive (+ index 1))))))
    (thread-send echo 'stop)
    (require (eq? (thread-join! echo 2 'join-timeout) 'echo-stopped) "Native echo Actor did not join"))
  (measure 'fresh-reply-channel 20000 (lambda (index) (make-channel 1)))
  (let ((clock (policy-clock-owner
                (lambda () (values #f (agentic-ai-lab-temporal-support-policy-host)))
                "txn" 1 1000. 0. 1 #f #f))
        (nop (lambda (resource) #t)))
    (measure 'owner-rpc-roundtrip 20000
      (lambda (index) (require (policy-clock-call! clock nop) "RPC reply mismatch")))
    (measure 'owner-resource-query 20000
      (lambda (index)
        (require (= (.ref (policy-clock-resource-state clock) 'waiters) 0) "Unexpected owner waiter")))
    (policy-clock-stop! clock)
    (require (.ref (policy-clock-stop-receipt clock) 'owner-joined?) "Transport owner did not join")))

(def (raw-storage-probe! path)
  (let (clock
        (policy-clock-owner
         (lambda () (values (journal-open path) (agentic-ai-lab-temporal-support-policy-host)))
         "txn" 1 1000. 0. 1 #f #f))
    (measure 'journal-transaction 60
      (lambda (index)
        (policy-clock-call! clock
          (lambda (journal)
            (let (id (string-append "storage:" (number->string index)))
              (journal-receive! journal id (.o value: index))
              (journal-begin! journal id)
              (journal-put! journal "value" index)
              (journal-commit! journal))))))
    (policy-clock-call! clock
      (lambda (journal)
        (require (= (journal-get journal "value") 59) "Journal lost a transaction")
        (require (journal-verify! journal) "Raw storage chain mismatch")
        (require (= (length (journal-rows journal)) 60) "Raw storage inbox count mismatch")
        (journal-close! journal)))
    (policy-clock-stop! clock)))

(def (context-probe! path durable?)
  (let* ((clock
          (policy-clock-owner
           (lambda ()
             (let* ((journal (and durable? (journal-open path)))
                    (ctx (clock-original-context))
                    (fixture (authority-fixture #t ctx 1000000 #f)))
               (if journal
                 (begin
                   (originals.originals! journal path)
                   (journal-evidence! journal "original-ascent" (originals.proof-evidence ctx))
                   (values fixture (.ref fixture 'policies)
                     (context-durable-adapter journal (.ref fixture 'host) (.ref fixture 'grants)
                       (.ref fixture 'policies) (lambda (registration) (.ref fixture 'proof)))))
                 (values fixture (.ref fixture 'policies)))))
           "txn" 1 1000. 0. 1 #f #f))
         (query (lambda (fixture)
                  (let (result (agentic-ai-lab-temporal-proof-host-current
                                 (.ref fixture 'proof) (.ref (.ref fixture 'registration-a) 'identity)
                                 1 1 (.ref (.ref fixture 'policy) 'semantic-digest) 128))
                    (require (.ref result 'current?) "Current proof rejected during steady query") #t))))
    (measure (if durable? 'context-current-durable 'context-current-memory) 60
      (lambda (index) (policy-clock-call! clock query)))
    (unless durable? (policy-clock-call! clock (lambda (fixture) (context-host-dispose! (.ref fixture 'host)))))
    (policy-clock-stop! clock)
    (require (.ref (policy-clock-stop-receipt clock) 'owner-joined?) "Context owner did not join")))

;; Repeated replay still parses current source bytes every time. The digest
;; must stay identical across the baseline/candidate source cuts; this phase
;; measures removal of duplicate work, never reuse of a cached admission.
(def (projection-probe!)
  (let* ((source "#+SEQ_TODO: TODO | DONE\n* TODO Review source evidence\n:PROPERTIES:\n:ID: cost-evidence\n:END:\n* DONE Historical task\n")
         (scope (.o (:: @ AiAgenticContextScope.)
                  bundle: "bundle:1" organization: "org:1" epoch: 1 project: "project:1"
                  worktree: "worktree:1" source-cut: "cut:1" actor: "actor:1"
                  task: "task:1" destination: "provider:1"))
         (restriction (agentic-ai-lab-context-restriction
                       "domain:1" '("actor:1") '("provider:1") '("org:1") 0 10))
         (projection (agentic-ai-lab-ai-agentic-context-org-project
                      scope source restriction (agentic-ai-lab-ai-agentic-context-profile #f)))
         (expected (.ref projection 'semantic-digest)))
    (measure 'org-current-replay 60
      (lambda (index)
        (require (equal? expected
                   (.ref (agentic-ai-lab-ai-agentic-context-org-replay source projection scope)
                         'semantic-digest))
                 "Current Org replay changed the source-derived projection")))
    (displayln "ACTOR-ORG projection=" expected)
    ;; These controls call the production replay boundary after the timed
    ;; phase. A fresh canonical observation must not bypass provenance checks.
    (let (observation (.ref projection 'observation))
      (for-each
        (lambda (forged)
          (require (rejected? (lambda ()
                     (agentic-ai-lab-ai-agentic-context-org-replay source forged scope)))
                   "Forged native observation passed Context replay"))
        (list
          (.o (:: @ projection) observation:
            (.o (:: @ observation) source-sha256: "forged-source-cut"))
          (.o (:: @ projection) observation:
            (.o (:: @ observation) parser-identity: "foreign-parser"))
          (.o (:: @ projection) observation:
            (.o (:: @ observation) query:
              (.o (:: @ (.ref observation 'query)) identity: "foreign-query")))
          (.o (:: @ projection) action-authorized?: #t))))
    (require (rejected? (lambda ()
               (agentic-ai-lab-ai-agentic-context-org-replay
                "* DONE Changed source\n" projection scope)))
             "Changed source reused a prior Context admission")
    (displayln "ACTOR-ORG-CONTROLS source=refused parser=refused query=refused edited=refused authority=refused")))

(def (parallel-context-probe!)
  (let ((clocks '()) (events 0))
    (dynamic-wind void
      (lambda ()
        ;; Eight isolated fixture domains share one heap-fenced Gambit VM.
        ;; Construction remains visible separately from long-lived owner use.
        (measure 'parallel-context-construction 8
          (lambda (index)
            (let (clock
                   (policy-clock-owner
                     (lambda ()
                       (let (f (authority-fixture #t (clock-original-context) 1000000 #f))
                         (values f (.ref f 'policies))))
                     "txn" 1 1000. 0. 1 #f #f))
              (set! clocks (cons clock clocks)))))
        (measure 'parallel-current-batch 1
          (lambda (unused)
            (let (producers
                   (map (lambda (clock)
                     (thread-start! (make-thread
                       (lambda ()
                         (let loop ((count 0))
                           (if (= count 60) count
                             (begin
                               (policy-clock-call! clock
                                 (lambda (f)
                                   (let (result
                                          (agentic-ai-lab-temporal-proof-host-current
                                            (.ref f 'proof) (.ref (.ref f 'registration-a) 'identity)
                                            1 1 (.ref (.ref f 'policy) 'semantic-digest) 128))
                                     (require (.ref result 'current?) "Parallel owner lost current proof"))))
                               (loop (+ count 1))))))))) clocks))
              (set! events
                (apply + (map (lambda (producer)
                  (let (count (thread-join! producer 30 'producer-timeout))
                    (require (eqv? count 60) "Parallel producer did not finish 60 actual calls")
                    count)) producers)))))))
      (lambda ()
        (for-each (lambda (clock)
          (policy-clock-call! clock (lambda (f) (context-host-dispose! (.ref f 'host))))
          (policy-clock-stop! clock)
          (require (.ref (policy-clock-stop-receipt clock) 'owner-joined?)
                   "Parallel owner did not join")) clocks)))
    (require (= events 480) "Parallel event count changed")
    (displayln "ACTOR-PARALLEL owners=8 producers=8 events=480 closed=8")))

(def (actor-cost-probe directory)
  (let (stats (##process-statistics))
    (displayln "ACTOR-STARTUP cpu=" (+ (f64vector-ref stats 0) (f64vector-ref stats 1))
      " gc-cpu=" (+ (f64vector-ref stats 3) (f64vector-ref stats 4))
      " allocated=" (f64vector-ref stats 7)))
  (transport-probe!)
  (projection-probe!)
  (raw-storage-probe! (string-append directory "/raw.sqlite"))
  (context-probe! #f #f)
  (context-probe! (string-append directory "/context.sqlite") #t)
  (parallel-context-probe!)
  (displayln "MODULE-OK t/context-actor-cost-test.ss")
  (displayln "HARNESS-OK context-actor-cost")
  (displayln "OK"))
