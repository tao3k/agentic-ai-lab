;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native owner reactor and real monotonic deadline thread. No wire evaluator.
(import (only-in :clan/poo/object .o .ref .call object<-alist)
        (only-in :std/sync/channel make-channel channel-put channel-get)
        (only-in :std/crypto/digest sha256) (only-in :std/encoding/hex hex-encode)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/objects agentic-ai-lab-temporal-instant)
        :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
        ;; The platform primitive is a compiled library. A source-path import
        ;; would ask the interpreter to evaluate its C-declare forms.
        :agentic-ai-lab/modules/temporal-causality/runtime/monotonic-clock
        "scheduling.ss" "owner-ingress.ss")
(export policy-clock-owner policy-clock-owner/scheduled policy-clock-call! policy-clock-await-events!
        policy-clock-pause! policy-clock-resume! policy-clock-retry!
        policy-clock-audit policy-clock-stop! policy-clock-observed policy-clock-command! policy-clock-replace-policy! policy-clock-stop-receipt policy-clock-resource-state policy-clock-admission-state)
(defstruct clock-client (thread phase receipt lock ingress))
(defstruct clock-request (kind operation reply))
(defstruct clock-ticket (identity policy generation digest end due))
(defstruct clock-delivery (ticket observed monotonic key))
(def (fingerprint value) (string-append "sha256:" (hex-encode (sha256 (string->utf8
  (call-with-output-string (lambda (p) (write value p))))))))
(def (copy-instant value)
  (agentic-ai-lab-temporal-instant (string-copy (.ref value 'identity))
    (string-copy (.ref value 'domain-identity)) (.ref value 'coordinate)
    (string-copy (.ref value 'provenance-identity)) (.ref value 'modality)))
(def (copy-audit row)
  (object<-alist (map (lambda (key)
    (let (value (.ref row key))
      (cons key (cond ((eq? key 'observed) (copy-instant value))
                      ((string? value) (string-copy value)) (else value)))))
    '(kind phase cause ticket policy generation policy-digest end observed epoch deadline-monotonic sample-monotonic))))
(def (with-client-lock client operation)
  (mutex-lock! (clock-client-lock client))
  (dynamic-wind void operation (lambda () (mutex-unlock! (clock-client-lock client)))))
(def (request host kind operation)
  (let* ((client (.ref host 'private-clock-client)) (reply (make-channel 1)))
    ;; Phase check and mailbox admission form one short critical section.
    ;; Never hold the client lock while waiting for an owner reply.
    (with-client-lock client (lambda ()
      (unless (or (eq? (clock-client-phase client) 'open)
                  (and (eq? kind 'stop) (eq? (clock-client-phase client) 'stopping)))
        (error "Clock owner is stopping or closed"))
      (when (eq? (current-thread) (clock-client-thread client)) (error "Recursive owner RPC"))
      (let ((message (make-clock-request kind operation reply))
            (ingress (clock-client-ingress client)))
        (if (eq? kind 'stop)
          (ingress-drain! ingress message)
          (unless (ingress-offer! ingress
                    (if (or (memq kind '(pause resume retry))
                            (and (eq? kind 'command)
                                 (not (eq? (.ref (car operation) 'operation) 'result))))
                      'control 'data) message)
            ;; Refusal is not an ACK. The producer retains its command and
            ;; durable upstream outbox item; no effect has been admitted.
            (error "Context owner admission full or draining" kind))))))
    (let (answer (channel-get reply 10 'clock-owner-timeout))
      (when (eq? answer 'clock-owner-timeout) (error "Clock owner request timed out" kind))
      (if (car answer) (cadr answer) (raise (cadr answer))))))
(def (policy-clock-command! host intent operation) (request host 'command (cons intent operation)))
;;; Policy effects are dispatched by the durable owner itself. A caller does
;;; not supply a compute hook capable of overriding the admitted CAS decision.
(def (policy-clock-replace-policy! host intent)
  (unless (and (eq? (.ref intent 'kind) 'context.durable-command.v1)
               (memq (.ref intent 'operation) '(policy-transition policy-replacement)))
    (error "Expected a durable policy transition"))
  (policy-clock-command! host intent #f))
(def (policy-clock-call! host operation) (request host 'call operation))
(def (policy-clock-await-events! host count) (request host 'await count))
(def (policy-clock-pause! host) (request host 'pause #f))
(def (policy-clock-resume! host) (request host 'resume #f))
(def (policy-clock-retry! host) (request host 'retry #f))
(def (policy-clock-admission-state host)
  (ingress-resources (clock-client-ingress (.ref host 'private-clock-client))))
(def (policy-clock-resource-state host) (request host 'resources #f))
(def (policy-clock-audit host) (request host 'audit #f))
(def (policy-clock-observed host) (request host 'observed #f))
(def (policy-clock-stop-receipt host)
  (let (client (.ref host 'private-clock-client))
    (with-client-lock client (lambda ()
      (unless (eq? (clock-client-phase client) 'closed) (error "Owner has not joined"))
      (clock-client-receipt client)))))
(def (policy-clock-stop! host)
  (let* ((client (.ref host 'private-clock-client))
         (already-closed?
          (with-client-lock client (lambda ()
            (cond ((eq? (clock-client-phase client) 'closed) #t)
                  ((not (eq? (clock-client-phase client) 'open)) (error "Owner stop is already pending"))
                  (else (set! (clock-client-phase client) 'stopping) #f))))))
    (if already-closed? #t
      (let ((thread-value (clock-client-thread client))
            (receipt-value (request host 'stop #f)))
        (unless (eq? (thread-join! thread-value 2 'clock-stop-timeout) 'clock-owner-stopped)
          (error "Clock owner failed to stop"))
        (with-client-lock client (lambda ()
          (set! (clock-client-receipt client) (.o (:: @ receipt-value) owner-joined?: #t))
          (set! (clock-client-thread client) #f)
          (set! (clock-client-phase client) 'closed)))
        #t))))
(def (policy-clock-owner bootstrap domain-value origin-value tick-value
                         (delay-value 0.) (copies-value 1) (paused-value #f) (enabled-value #t))
  ;; Preserve the compiled eight-argument entrypoint for existing consumers.
  (policy-clock-owner/scheduled (context-scheduling-contract 64 16 2)
    bootstrap domain-value origin-value tick-value delay-value copies-value paused-value enabled-value))

(def (policy-clock-owner/scheduled scheduling-value bootstrap domain-value origin-value tick-value
                                   (delay-value 0.) (copies-value 1) (paused-value #f) (enabled-value #t))
  (unless (and (procedure? bootstrap) (string? domain-value) (< 0 (string-length domain-value) 257)
               (exact-integer? origin-value) (real? tick-value) (< 0 tick-value 3601)
               (real? delay-value) (<= 0 delay-value 60) (memv copies-value '(1 2))
               (boolean? paused-value) (boolean? enabled-value)) (error "Invalid native clock profile"))
  (let* ((ready (make-channel 1))
         (ingress (context-owner-ingress scheduling-value))
         (owner-thread (make-thread (lambda ()
           (with-catch (lambda (e) (channel-put ready (list #f e)))
             ;; Transfer the initializer once. The long-lived owner closure
             ;; must not retain caller state after bootstrap has acquired it.
             (lambda () (clock-loop (begin0 bootstrap (set! bootstrap #f))
                           (string-copy domain-value) origin-value tick-value
                           delay-value copies-value paused-value enabled-value ready ingress))))))
         (client (make-clock-client owner-thread 'open #f (make-mutex 'policy-clock-client) ingress)))
    (thread-start! owner-thread)
    (let (answer (channel-get ready 10 'clock-start-timeout))
      (when (eq? answer 'clock-start-timeout) (error "Clock owner bootstrap timed out"))
      (unless (car answer)
        ;; Failure is returned only after the native owner has finished its
        ;; acquisition rollback. Do not leave a failed initializer unjoined.
        (when (eq? (thread-join! owner-thread 2 'bootstrap-join-timeout) 'bootstrap-join-timeout)
          (error "Failed bootstrap owner did not join" (cadr answer)))
        (raise (cadr answer))))
    (.o kind: 'temporal.policy-clock-owner.v1 private-clock-client: client)))

;; No clock lease or timer exists until this anchor succeeds. The resource has
;; already crossed the bootstrap boundary, so this owner must release it on
;; failure, including rollback of a partially written bootstrap transaction.
(def (anchor-epoch durability domain origin tick)
  (with-catch
    (lambda (failure)
      (when durability
        (with-catch
          (lambda (cleanup-failure)
            (error "Anchor failure and resource cleanup both failed" failure cleanup-failure))
          (lambda ()
            (.call durability .abort! durability)
            (.call durability .close! durability))))
      (raise failure))
    (lambda ()
      (let (now (native-monotonic-seconds))
        (if durability
          (.call durability .anchor! durability domain origin tick now (native-boot-identity))
          now)))))

(def (clock-loop bootstrap domain-value origin-value tick-value delay-value copies-value paused-value enabled-value ready ingress)
  (let* ((setup (call-with-values bootstrap list)) (resource (car setup)) (policy-host (cadr setup))
         (durability (and (= (length setup) 3) (caddr setup))))
    (set! bootstrap #f)
    (let* ((owner (current-thread))
           (epoch (anchor-epoch durability domain-value origin-value tick-value))
           (epoch-id (fingerprint (list domain-value origin-value epoch)))
           (scheduled (make-hash-table)) (seen (make-hash-table))
           (pending '()) (audit '()) (received 0) (waiters '()) (fault #f) (cause 'setup)
           (paused? paused-value) (stopped? #f) (recovery '()) (timer #f) (calls 0) (clock-cap #f) (clock-observer #f))
      (def (ticket-data ticket)
        (let ((id-value (clock-ticket-identity ticket)) (policy-value (clock-ticket-policy ticket))
              (gen-value (clock-ticket-generation ticket)) (dg-value (clock-ticket-digest ticket))
              (end-value (clock-ticket-end ticket)) (due-value (clock-ticket-due ticket)))
          (.o kind: 'context.durable-ticket.v1 identity: id-value policy: policy-value generation: gen-value
              digest: dg-value end: end-value due: due-value epoch: epoch-id)))
      (def (data-ticket data)
        (unless (equal? (.ref data 'epoch) epoch-id) (error "Old clock epoch cannot schedule current owner"))
        (make-clock-ticket (.ref data 'identity) (.ref data 'policy) (.ref data 'generation)
          (.ref data 'digest) (.ref data 'end) (.ref data 'due)))
      (def (delivery-data event)
        (let ((ticket-value (ticket-data (clock-delivery-ticket event)))
              (observed-value (clock-delivery-observed event)) (sample-value (clock-delivery-monotonic event)))
          (.o kind: 'context.durable-delivery.v1 ticket: ticket-value observed: observed-value sample: sample-value)))
      (def (begin-delivery! event)
        (when durability (.call durability .begin! durability (clock-delivery-key event) (delivery-data event))))
      (def (finish-delivery! event applied?)
        (when durability (.call durability .finish! durability (clock-delivery-key event) applied?)))
      (def (cycle-call intent operation)
        (set! calls (+ calls 1))
        (let* ((id (if intent (.ref intent 'identity)
                      (string-append "call:" (number->string (.call durability .epoch durability)) ":" (number->string calls))))
               (payload (or intent (.o kind: 'context.opaque-owner-call.v1 identity: id))))
          ;; A historical ACK is valid only for the same original bytes. Check
          ;; before the fast path; duplicate IDs do not permit body substitution.
          (.call durability .verify-input! durability id payload)
          (if (.call durability .applied? durability id)
            (.o kind: 'context.durable-ack.v1 identity: id historical?: #t action-authorized?: #f)
            (begin
              (.call durability .begin! durability id payload)
              (with-catch (lambda (e) (.call durability .abort! durability) (set! fault e) (raise e))
                (lambda ()
                  (let (answer
                         (if (and intent (memq (.ref intent 'operation)
                                               '(policy-transition policy-replacement)))
                           ;; Includes legacy command names. Their callback must
                           ;; never bypass the common CAS or replay semantics.
                           (.call durability .replace-policy! durability intent)
                           (operation resource)))
                    (.call durability .finish! durability id #t)
                    (if intent (.o kind: 'context.durable-ack.v1 identity: id historical?: #f action-authorized?: #f) answer))))))))
      (def (observe)
        (let* ((now (native-monotonic-seconds))
               (coordinate (+ origin-value (inexact->exact (floor (/ (- now epoch) tick-value))))))
          (agentic-ai-lab-temporal-instant (string-append epoch-id ":" (number->string coordinate))
            domain-value coordinate epoch-id 'observed)))
      (def (record! phase-value ticket observed-value (sample-value (native-monotonic-seconds)))
        (when (>= (length audit) 4096) (error "Clock audit capacity"))
        (let ((ticket-id-value (clock-ticket-identity ticket)) (policy-id-value (clock-ticket-policy ticket))
              (generation-value (clock-ticket-generation ticket)) (digest-value (clock-ticket-digest ticket))
              (end-value (clock-ticket-end ticket)) (cause-value cause)
              (deadline-value (- (clock-ticket-due ticket) delay-value)))
          (set! audit (cons (.o kind: 'temporal.clock-delivery.v1 phase: phase-value cause: cause-value
            ticket: ticket-id-value policy: policy-id-value generation: generation-value policy-digest: digest-value
            end: end-value observed: observed-value epoch: epoch-id
            deadline-monotonic: deadline-value sample-monotonic: sample-value) audit))))
      (def (ticket-for snapshot)
        (let* ((p (.ref snapshot 'policy)) (end-value (.ref p 'end))
               (id (.ref p 'identity)) (gen (.ref snapshot 'generation)) (dg (.ref p 'semantic-digest))
               (coordinate (.ref end-value 'coordinate)))
          (unless (equal? domain-value (.ref end-value 'domain-identity)) (error "Unenrolled clock domain"))
          (make-clock-ticket (fingerprint (list epoch-id id gen dg coordinate)) (string-copy id) gen
            (string-copy dg) coordinate (+ epoch (* (- coordinate origin-value) tick-value) delay-value))))
      (def (enqueue! snapshot)
        (let* ((ticket (ticket-for snapshot)) (id (clock-ticket-identity ticket)))
          (when (< (.ref (.ref snapshot 'effective-at) 'coordinate) (clock-ticket-end ticket))
            (unless (hash-get scheduled id)
              (when durability (.call durability .ticket! durability (ticket-data ticket)))
              (hash-put! scheduled id ticket)
              (when enabled-value (thread-send timer ticket))))))
      (def (process! event)
        (let* ((ticket (clock-delivery-ticket event)) (id (clock-ticket-identity ticket))
               (now (observe)))
          (if (or (hash-get seen id) (and durability (.call durability .seen? durability id))) (record! 'duplicate ticket now)
            (let* ((snapshot (agentic-ai-lab-temporal-support-policy-host-registered policy-host (clock-ticket-policy ticket)))
                   (p (.ref snapshot 'policy)))
              (cond
                ((or (not (= (.ref snapshot 'generation) (clock-ticket-generation ticket)))
                     (not (equal? (.ref p 'semantic-digest) (clock-ticket-digest ticket)))
                     (not (= (.ref (.ref p 'end) 'coordinate) (clock-ticket-end ticket))))
                 (hash-put! seen id #t) (when durability (.call durability .seen! durability id)) (record! 'stale ticket now))
                ((< (.ref now 'coordinate) (clock-ticket-end ticket)) (error "OS timer fired early"))
                (else
                  (agentic-ai-lab-temporal-support-policy-host-fire-deadline! policy-host
                    (clock-ticket-policy ticket) (clock-ticket-generation ticket) now)
                  (hash-put! seen id #t) (when durability (.call durability .seen! durability id)) (record! 'applied ticket now)))))))
      (def (drain!)
        (let loop ()
          (when (and (pair? pending) (not paused?) (not fault))
            (with-catch
              (lambda (e) (when durability (.call durability .abort! durability)) (set! fault e) (record! 'fault (clock-delivery-ticket (car pending)) (observe)))
              (lambda ()
                (begin-delivery! (car pending)) (process! (car pending)) (finish-delivery! (car pending) #t) (set! pending (cdr pending)) (loop))))))
      (def (notify!)
        (set! waiters (filter (lambda (request-value)
          (if (<= (clock-request-operation request-value) received)
            (begin (channel-put (clock-request-reply request-value) (list #t received)) #f) #t)) waiters)))
      ;; The native provider is enrolled once. It selects real current time for
      ;; support/use guards; generations change on actual lifecycle publication.
      (set! clock-cap (.o kind: 'temporal.native-clock.v1 .observe: (lambda (self policy-id) (observe))))
      (agentic-ai-lab-temporal-support-policy-host-enroll-clock! policy-host clock-cap)
      (set! clock-observer (.o kind: 'temporal.source-observer.v1
          .prepare: (lambda (self event-value)
            (let ((snapshot (.ref event-value 'revised)))
              (when (>= (hash-length scheduled) 256) (error "Native timer capacity"))
              (ticket-for snapshot)
              (.o kind: 'temporal.source-propagation-batch.v1
                  .publish!: (lambda (self) (enqueue! snapshot) #t))))))
      (agentic-ai-lab-temporal-support-policy-host-watch! policy-host clock-observer)
      (set! timer (thread-start! (make-thread (lambda ()
        (let loop ((tickets '()))
          (let* ((ordered (list-sort (lambda (a b) (< (clock-ticket-due a) (clock-ticket-due b))) tickets))
                 (wait (if (pair? ordered) (max 0. (- (clock-ticket-due (car ordered)) (native-monotonic-seconds))) #f))
                 (message (if wait (thread-receive wait 'timer-wakeup) (thread-receive))))
            (cond ((eq? message 'stop) 'clock-timer-stopped)
                  ((clock-ticket? message) (loop (cons message ordered)))
                  (else
                    (let* ((now (native-monotonic-seconds))
                           (due (filter (lambda (ticket) (<= (clock-ticket-due ticket) now)) ordered))
                           (future (filter (lambda (ticket) (> (clock-ticket-due ticket) now)) ordered)))
                      (let ((deferred '()) (halted? #f))
                        (def (deliver! event)
                          (let retry ()
                            (unless (or halted? (ingress-offer! ingress 'control event))
                              ;; The ticket already lives in the durable journal.
                              ;; One timer retains this event while backpressured;
                              ;; stop remains observable, so join cannot deadlock.
                              (let (signal (thread-receive 0.001 'retry))
                                (cond ((eq? signal 'stop) (set! halted? #t))
                                      ((clock-ticket? signal) (set! deferred (cons signal deferred)))))
                              (retry))))
                        (for-each (lambda (ticket)
                          (let (event (make-clock-delivery ticket (observe) now #f))
                            (deliver! event)
                            (when (= copies-value 2) (deliver! event)))) due)
                        (if halted? 'clock-timer-stopped (loop (append future deferred)))))))))))))
      (for-each (lambda (ticket)
        (enqueue! (agentic-ai-lab-temporal-support-policy-host-registered policy-host (.ref ticket 'identity))))
        (agentic-ai-lab-temporal-support-policy-host-deadlines policy-host))
      (when durability
        (for-each (lambda (data)
          (let (ticket (data-ticket data))
            (unless (hash-get scheduled (clock-ticket-identity ticket))
              (hash-put! scheduled (clock-ticket-identity ticket) ticket)
              (when enabled-value (thread-send timer ticket))))) (.call durability .tickets durability))
        (for-each (lambda (row)
          (let (data (.ref row 'payload))
            (set! recovery (cons (make-clock-delivery (data-ticket (.ref data 'ticket))
              (.ref data 'observed) (.ref data 'sample) (.ref row 'id)) recovery)))) (.call durability .pending durability))
        (set! recovery (reverse recovery)))
      (channel-put ready (list #t #t))
      (let loop ()
        ;; Journal recovery is a cursor, not an unbounded mailbox refill.
        ;; Admit at most one recovered event per turn, using normal credits.
        (when (and (pair? recovery) (ingress-offer! ingress 'control (car recovery)))
          (set! recovery (cdr recovery)))
        (let (message (ingress-next! ingress))
          (dynamic-wind void (lambda ()
          (cond
            ((clock-delivery? message)
             (set! cause 'timer) (set! received (+ received 1))
             (when (and durability (not (clock-delivery-key message)))
               (set! (clock-delivery-key message) (string-append "delivery:" (number->string (.call durability .epoch durability))
                 ":" (number->string received) ":" (clock-ticket-identity (clock-delivery-ticket message)))))
             (record! 'received (clock-delivery-ticket message) (clock-delivery-observed message) (clock-delivery-monotonic message))
             (set! pending (append pending (list message)))
             (when (and durability paused?) (begin-delivery! message) (finish-delivery! message #f))
             (drain!) (notify!))
            ((clock-request? message)
             (set! cause 'operation)
             (with-catch (lambda (e) (channel-put (clock-request-reply message) (list #f e)))
               (lambda ()
                 (let ((kind (clock-request-kind message)) (op (clock-request-operation message)))
                   (if (and (eq? kind 'await) (> op received))
                     (begin
                       (when (>= (length waiters) 128) (error "Clock waiter capacity"))
                       (set! waiters (cons message waiters)))
                     (let (answer
                       (case kind
                         ((call) (when fault (raise fault)) (if durability (cycle-call #f op) (op resource)))
                         ((command) (when fault (raise fault))
                           (if durability (cycle-call (car op) (cdr op))
                             (begin
                               ;; A named policy command cannot silently fall
                               ;; back to an unfenced callback on a clock with
                               ;; no durable adapter. Raw trusted calls remain
                               ;; a separate runtime capability.
                               (when (memq (.ref (car op) 'operation)
                                           '(policy-transition policy-replacement))
                                 (error "Policy commands require a durable owner"))
                               ((cdr op) resource))))
                         ((await) received)
                         ((pause) (set! paused? #t) #t)
                         ((resume) (set! paused? #f) (drain!) (when fault (raise fault)) #t)
                         ((retry) (when durability (error "Restart durable owner after an aborted transaction"))
                           (agentic-ai-lab-temporal-support-policy-host-drain! policy-host)
                           (set! fault #f) (set! paused? #f) (drain!) (when fault (raise fault)) #t)
                         ((observed) (copy-instant (observe)))
                         ((resources)
                           (let ((waiter-count (length waiters)) (pending-count (length pending))
                                 (scheduled-count (hash-length scheduled)))
                             (.o kind: 'temporal.owner-resources.v1
                                 waiters: waiter-count pending-deliveries: pending-count
                                 scheduled: scheduled-count action-authorized?: #f)))
                         ((audit) (map copy-audit (reverse audit)))
                         ((stop)
                           (thread-send timer 'stop)
                           (unless (eq? (thread-join! timer 2 'timer-stop-timeout) 'clock-timer-stopped)
                             (error "Native timer did not terminate"))
                           (agentic-ai-lab-temporal-support-policy-host-unwatch! policy-host clock-observer)
                           (agentic-ai-lab-temporal-support-policy-host-release-clock! policy-host clock-cap)
                           (let ((closed-value (and durability (.call durability .close! durability)))
                                 (rejected-count (length waiters)))
                             (when (and closed-value
                                        (not (and (.ref closed-value 'journal-closed?)
                                                  (.ref closed-value 'context-disposed?)
                                                  (= (.ref closed-value 'subscriptions) 0))))
                               (error "Durable resource shutdown incomplete"))
                             (for-each (lambda (waiter) (channel-put (clock-request-reply waiter)
                               (list #f 'clock-owner-stopped-before-event))) waiters)
                             ;; Ingress reached closed only after all admitted
                             ;; requests completed. No mailbox flush can discard
                             ;; an accepted command or invent its terminal.
                             (set! pending '()) (set! recovery '()) (set! waiters '()) (set! audit '())
                             (set! scheduled #f) (set! seen #f)
                             (set! resource #f) (set! setup #f) (set! durability #f)
                             (set! policy-host #f) (set! clock-cap #f) (set! clock-observer #f) (set! timer #f)
                             (set! stopped? #t)
                             (.o kind: 'temporal.owner-stop.v1 timer-joined?: #t clock-released?: #t
                                 journal-closed?: (if closed-value (.ref closed-value 'journal-closed?) #f)
                                 context-disposed?: (if closed-value (.ref closed-value 'context-disposed?) #f)
                                 subscriptions: 0 waiters-rejected: rejected-count owner-joined?: #f)))
                         (else (error "Unknown native clock operation"))))
                       (channel-put (clock-request-reply message) (list #t answer))))))))
            (else (error "Unknown private owner message"))))
            (lambda () (ingress-complete! ingress)))
          (if stopped? 'clock-owner-stopped (loop)))))))
