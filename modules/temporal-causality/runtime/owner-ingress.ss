;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Explicit local runtime adapter for the pure scheduling contract. Payloads
;;; never enter the owner's unbounded mailbox. A capacity-one wake coalesces.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/sync/channel make-channel channel-get channel-try-put)
        "scheduling.ss" "private/scheduling-kernel.ss")
(export context-owner-ingress ingress-offer! ingress-next! ingress-complete!
        ingress-drain! ingress-resources)

;; Positional queues and locks are private runtime state, not the public API.
(defstruct ingress (state data-front data-back control-front control-back lock wake stop))
(def (context-owner-ingress contract)
  (unless (eq? (.ref contract 'kind) 'context.scheduling-contract.v1)
    (error "Expected Context scheduling contract"))
  (let (value (make-ingress
                (make-scheduling-frame (.ref contract 'data-capacity)
                  (.ref contract 'control-capacity) (.ref contract 'control-burst)
                  0 0 'idle 0 'open) '() '() '() '()
                           (make-mutex 'context-ingress) (make-channel 1) #f))
    (.o kind: 'context.owner-ingress.v1 private-ingress: value)))
(def (locked client operation)
  (mutex-lock! (ingress-lock client))
  (dynamic-wind void operation (lambda () (mutex-unlock! (ingress-lock client)))))
(def (transition! client operation)
  ;; The same pure algorithm backs the public POO facade. Runtime selection
  ;; needs only private frame scalars; do not allocate a public event/decision
  ;; on every enqueue, dispatch, completion and empty-queue wake.
  (let-values (((next accepted selection)
                (scheduling-transition (ingress-state client) operation)))
    (set! (ingress-state client) next)
    (values accepted selection)))

(def (ingress-offer! host class-value payload)
  (unless (memq class-value '(data control)) (error "Unknown ingress class"))
  (let (client (.ref host 'private-ingress))
    (locked client (lambda ()
      (let-values (((accepted selection) (transition! client
                              (if (eq? class-value 'data) 'offer-data 'offer-control))))
        (when accepted
          (if (eq? class-value 'data)
            (set! (ingress-data-back client) (cons payload (ingress-data-back client)))
            (set! (ingress-control-back client) (cons payload (ingress-control-back client))))
          (channel-try-put (ingress-wake client) 'wake))
        accepted)))))

(def (pop! client class-value)
  (if (eq? class-value 'data)
    (begin
      (when (null? (ingress-data-front client))
        (set! (ingress-data-front client) (reverse (ingress-data-back client)))
        (set! (ingress-data-back client) '()))
      (begin0 (car (ingress-data-front client))
        (set! (ingress-data-front client) (cdr (ingress-data-front client)))))
    (begin
      (when (null? (ingress-control-front client))
        (set! (ingress-control-front client) (reverse (ingress-control-back client)))
        (set! (ingress-control-back client) '()))
      (begin0 (car (ingress-control-front client))
        (set! (ingress-control-front client) (cdr (ingress-control-front client)))))))

(def (ingress-next! host)
  (let (client (.ref host 'private-ingress))
    (let loop ()
      (let (answer
             (locked client (lambda ()
               (let-values (((accepted selection) (transition! client 'dispatch)))
                 (if accepted (cons #t (pop! client selection))
                   (let-values (((closed ignored) (transition! client 'close)))
                     (and closed
                       (cons #t (begin0 (ingress-stop client)
                                  (set! (ingress-stop client) #f))))))))))
        (if answer (cdr answer)
          (begin (channel-get (ingress-wake client)) (loop)))))))

(def (ingress-complete! host)
  (let (client (.ref host 'private-ingress))
    (locked client (lambda ()
      (let-values (((accepted selection) (transition! client 'complete))) accepted)))))

(def (ingress-drain! host stop-value)
  (let (client (.ref host 'private-ingress))
    (locked client (lambda ()
      (let-values (((accepted selection) (transition! client 'drain)))
        (unless accepted (error "Ingress already draining")))
      ;; One lifecycle handoff is outside the work queues. It cannot be
      ;; excluded by saturated control credits and cannot bypass accepted work.
      (set! (ingress-stop client) stop-value)
      (channel-try-put (ingress-wake client) 'wake)
      #t))))

(def (ingress-resources host)
  (let (client (.ref host 'private-ingress))
    (locked client (lambda ()
      (let* ((current (ingress-state client))
             (data-value (scheduling-frame-data current))
             (control-value (scheduling-frame-controls current))
             (active-value (scheduling-frame-active current))
             (phase-value (scheduling-frame-phase current)))
        (.o kind: 'context.ingress-resources.v1 queued-data: data-value
            queued-controls: control-value active: active-value phase: phase-value))))))
