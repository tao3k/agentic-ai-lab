;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Owner-local prepare/publish/deliver barrier. No wire authority or background clock.
(import (only-in :std/crypto/digest sha256) (only-in :std/encoding/hex hex-encode)
        (only-in :clan/poo/object .o .ref .slot? object? .call))
(export make-change-feed change-feed-open! change-feed-watch! change-feed-unwatch! change-feed-observer-count change-feed-stage!
        change-feed-drain! change-feed-pending? authority-change change-feed-history)
(defstruct feed-state (owner observers pending busy? history))
(def (make-change-feed) (make-feed-state (current-thread) '() #f #f '()))
(def (change-feed-pending? feed) (if (or (feed-state-pending feed) (feed-state-busy? feed)) #t #f))
(def (change-feed-open! feed)
  (unless (eq? (feed-state-owner feed) (current-thread)) (error "Feed requires serialized owner"))
  (when (change-feed-pending? feed) (error "Authority propagation pending")))
(def (change-feed-watch! feed observer)
  (change-feed-open! feed)
  (unless (and (object? observer) (eq? (.ref observer 'kind) 'temporal.source-observer.v1)
               (.slot? observer '.prepare)) (error "Expected native POO observer"))
  (unless (memq observer (feed-state-observers feed))
    (when (>= (length (feed-state-observers feed)) 128) (error "Authority observer capacity"))
    (set! (feed-state-observers feed) (cons observer (feed-state-observers feed)))) observer)
;;; Only detach an exact observer at a quiescent publication boundary. Pending
;;; batches must finish or remain explicit; shutdown cannot discard their work.
(def (change-feed-unwatch! feed observer)
  (change-feed-open! feed)
  (let (present? (if (memq observer (feed-state-observers feed)) #t #f))
    (set! (feed-state-observers feed)
      (filter (lambda (held) (not (eq? held observer))) (feed-state-observers feed)))
    present?))
(def (change-feed-observer-count feed)
  (change-feed-open! feed)
  (length (feed-state-observers feed)))

(def (change-feed-stage! feed event)
  (change-feed-open! feed)
  (let (batches (dynamic-wind
    (lambda () (set! (feed-state-busy? feed) #t))
    (lambda () (map (lambda (observer)
      (let (batch (.call observer .prepare observer event))
        (unless (and (object? batch) (eq? (.ref batch 'kind) 'temporal.source-propagation-batch.v1)
                     (.slot? batch '.publish!)) (error "Invalid authority propagation batch")) batch))
      (feed-state-observers feed)))
    (lambda () (set! (feed-state-busy? feed) #f))))
    (set! (feed-state-pending feed) batches)
    (set! (feed-state-history feed) (cons event (feed-state-history feed)))))
(def (change-feed-drain! feed)
  (unless (eq? (feed-state-owner feed) (current-thread)) (error "Feed requires serialized owner"))
  (when (feed-state-busy? feed) (error "Cannot drain during preparation"))
  (let loop ()
    (let (pending (feed-state-pending feed))
      (cond ((not pending) #t)
            ((null? pending) (set! (feed-state-pending feed) #f) #t)
            (else
              (dynamic-wind (lambda () (set! (feed-state-busy? feed) #t))
                (lambda () (.call (car pending) .publish! (car pending)))
                (lambda () (set! (feed-state-busy? feed) #f)))
              (set! (feed-state-pending feed) (cdr pending)) (loop))))))

(def (fingerprint value) (string-append "sha256:" (hex-encode (sha256 (string->utf8
  (call-with-output-string (lambda (port) (write value port))))))))
(def (authority-change kind-value id-value generation-value old-value new-value old-digest new-digest)
  (let ((event-digest (fingerprint (list kind-value id-value generation-value old-digest new-digest)))
        (source-value (string-append (symbol->string kind-value) ":" id-value)))
    (.o kind: 'temporal.authority-change.v1 authority-kind: kind-value identity: id-value
        previous: old-value revised: new-value semantic-digest: event-digest source: source-value
        generation: generation-value previous-cut: old-digest revised-cut: new-digest
        previous-program: old-digest revised-program: new-digest index-digest: event-digest
        changed-subjects: (list source-value))))

(def (change-feed-history feed) (feed-state-history feed))
