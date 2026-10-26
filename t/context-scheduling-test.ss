;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native reference adapter and cross-language path replay, not a cluster gate.
(import (only-in :clan/poo/object .ref)
        (only-in :std/list/list delete-duplicates/hash)
        :agentic-ai-lab/modules/temporal-causality/runtime/scheduling)
(export scheduling-probe)

(def operations '(offer-data offer-control dispatch complete drain close idle))
(def (ensure value message) (unless value (error message)))
(def (apply-event state operation)
  (context-scheduling-step state (context-scheduling-event operation)))
(def (advance state operation) (.ref (apply-event state operation) 'state))

;; Scalar rows are a final diagnostic/proof projection, never the public API.
(def (row state)
  (list (.ref state 'queued-data) (.ref state 'queued-controls)
        (case (.ref state 'active) ((data) 1) ((control) 2) (else 0))
        (.ref state 'consecutive-controls)
        (case (.ref state 'phase) ((draining) 1) ((closed) 2) (else 0))))

(def (safe? state)
  (let* ((contract (.ref state 'contract))
         (data (.ref state 'queued-data))
         (controls (.ref state 'queued-controls))
         (active (.ref state 'active)))
    (and (<= 0 data) (<= 0 controls)
         (<= (+ data (if (eq? active 'data) 1 0)) (.ref contract 'data-capacity))
         (<= (+ controls (if (eq? active 'control) 1 0)) (.ref contract 'control-capacity))
         (or (not (eq? (.ref state 'phase) 'closed))
             (and (= data 0) (= controls 0) (eq? active 'idle))))))

(def (reachable-probe)
  (let loop ((pending (list (context-scheduling-state (context-scheduling-contract 2 1 2))))
             (seen '()) (edges 0))
    (if (null? pending)
      (begin
        (displayln "SCHEDULING-REACHABLE states=" (length seen) " transitions=" edges)
        (ensure (> (length seen) 20) "Native finite exploration did not run"))
      (let* ((current (car pending)) (key (row current)))
        (if (member key seen)
          (loop (cdr pending) seen edges)
          (let (successors
                 (map (lambda (operation)
                        (let* ((decision (apply-event current operation))
                               (next (.ref decision 'state))
                               (selected (.ref decision 'selected)))
                          (ensure (safe? next) "Native scheduling invariant failed")
                          (when (and (eq? operation 'dispatch)
                                     (eq? (.ref current 'active) 'idle)
                                     (> (.ref current 'queued-controls) 0)
                                     (> (.ref current 'queued-data) 0))
                            (ensure (eq? selected
                                      (if (< (.ref current 'consecutive-controls) 2)
                                        'control 'data))
                                    "Native control/data selection obligation failed"))
                          next)) operations))
            (loop (append successors (cdr pending)) (cons key seen) (+ edges 7))))))))

(def (replay-probe path)
  (let ((cases (call-with-input-file path read)) (steps 0) (negatives 0))
    (for-each
     (lambda (case)
       (let ((current (context-scheduling-state (context-scheduling-contract 2 1 2)))
             (different #f))
         (for-each
          (lambda (event)
            (set! current (advance current (list-ref operations (- (car event) 1))))
            (set! steps (+ steps 1))
            (unless (equal? (row current) (cadr event)) (set! different #t))
            (ensure (safe? current) "Native ITF replay became unsafe"))
          (caddr case))
         ;; Every safe prefix agrees; each actual broken projection must
         ;; diverge from the corrected kernel on the same input path.
         (when different (set! negatives (+ negatives 1)))
         (ensure (eq? different (cadr case)) "Quint/native path mismatch"))) cases)
    (ensure (= (length cases) 25) "Missing native ITF paths")
    (ensure (= negatives 5) "Broken contracts were not rejected independently")
    (displayln "SCHEDULING-REPLAY paths=" (length cases) " steps=" steps
      " corrected-counterexamples=" negatives)))

(def (actor-probe)
  (let* ((lock (make-mutex 'scheduling-reference))
         (current (context-scheduling-state (context-scheduling-contract 32 8 2)))
         (data '()) (controls '()) (accepted 0) (refused 0)
         (processed '()) (actor #f))
    (def (locked operation)
      (mutex-lock! lock)
      (dynamic-wind void operation (lambda () (mutex-unlock! lock))))
    (def (offer operation payload)
      ;; Admission happens BEFORE any payload can enter an Actor mailbox.
      ;; No overflow sender blocks while holding a credit or a mutex.
      (locked (lambda ()
        (let (decision (apply-event current operation))
          (set! current (.ref decision 'state))
          (if (.ref decision 'accepted?)
            (begin
              (set! accepted (+ accepted 1))
              (if (eq? operation 'offer-data)
                (set! data (cons payload data))
                (set! controls (cons payload controls))))
            (set! refused (+ refused 1)))))))
    (set! actor
      (thread-start! (make-thread
        (lambda ()
          ;; Holding drain until producers finish makes saturation observable
          ;; without timing sleeps or scheduler-dependent expected counts.
          (ensure (eq? (thread-receive) 'drain) "Missing Actor drain handoff")
          (locked (lambda ()
            (set! data (reverse data)) (set! controls (reverse controls))
            (set! current (advance current 'drain))))
          (let loop ()
            (let (payload
                   (locked (lambda ()
                     (let* ((decision (apply-event current 'dispatch))
                            (selected (.ref decision 'selected)) (payload #f))
                       (set! current (.ref decision 'state))
                       (case selected
                         ((data) (set! payload (car data)) (set! data (cdr data)))
                         ((control) (set! payload (car controls)) (set! controls (cdr controls))))
                       payload))))
              (if payload
                (begin
                  ;; Short reference effect outside the admission mutex.
                  (set! processed (cons payload processed))
                  (locked (lambda () (set! current (advance current 'complete))))
                  (loop))
                (locked (lambda ()
                  (set! current (advance current 'close))
                  (ensure (eq? (.ref current 'phase) 'closed) "Actor closed with outstanding work")
                  'owner-closed)))))))))
    (let (producers
           (map (lambda (producer)
                  (thread-start! (make-thread
                    (lambda ()
                      (let loop ((index 0))
                        (when (< index 100)
                          (offer (if (even? index) 'offer-data 'offer-control)
                                 (cons producer index))
                          (loop (+ index 1))))))))
                '(0 1 2 3 4 5 6 7)))
      (for-each (lambda (producer)
        (ensure (not (eq? (thread-join! producer 10 'producer-timeout) 'producer-timeout))
                "Producer did not join")) producers))
    ;; Complete the owner handoff before reporting count assertions, so even
    ;; a regression in admission does not strand the reference Actor waiting.
    ;; Only the owner receives this one handoff message; producer payloads
    ;; were retained in the two bounded queues, not an unbounded mailbox.
    (thread-send actor 'drain)
    (ensure (eq? (thread-join! actor 10 'join-timeout) 'owner-closed) "Owner did not join")
    (ensure (= accepted 40) "Reserved capacities did not bound admission")
    (ensure (= refused 760) "Overflow did not return explicit refusal")
    (ensure (safe? current) "Drained native state became unsafe")
    (ensure (= (length processed) accepted) "Admitted payload was lost")
    (ensure (= (length (delete-duplicates/hash processed)) accepted) "Payload ran twice")
    (displayln "SCHEDULING-ACTOR producers=8 offers=800 accepted=40 refused=760 completed=40 joined=1")))

(def (scheduling-probe path)
  (reachable-probe)
  (replay-probe path)
  (actor-probe)
  (displayln "MODULE-OK t/context-scheduling-test.ss")
  (displayln "HARNESS-OK context-scheduling")
  (displayln "OK"))
