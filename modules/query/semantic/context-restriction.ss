;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; RFC 91's bounded reader/destination restriction profile, before Host admission.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. validate)
        (only-in :std/list/list every delete-duplicates/hash)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode))
(export PooFlowContextRestriction PooFlowContextFlowDecision
        poo-flow-context-restriction poo-flow-context-restriction-compose
        poo-flow-context-restriction-refinement poo-flow-context-flow-decision
        poo-flow-context-flow-decision-replay)
(def (text? x) (and (string? x) (< 0 (string-length x) 257)))
(def (names xs nonempty?)
  (unless (and (list? xs) (<= (length xs) 128) (every text? xs)
               (or (not nonempty?) (pair? xs))
               (= (length xs) (length (delete-duplicates/hash xs))))
    (error "invalid bounded Context identities"))
  (list-sort string<? (map string-copy xs)))
(def (digest x)
  (string-append "sha256:" (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (p) (write x p))))))))
(def (digest? x)
  (and (string? x) (= (string-length x) 71)
       (equal? (substring x 0 7) "sha256:")
       (every (lambda (c) (or (char<=? #\0 c #\9) (char<=? #\a c #\f)))
              (string->list (substring x 7 71)))))
(def (shape? x k slots)
  (and (object? x) (.slot? x 'kind) (eq? (.ref x 'kind) k)
       (every (lambda (s) (.slot? x s)) slots)))
(define-type (PooFlowContextRestriction @ Type.)
  .element?: (lambda (x) (shape? x 'poo-flow.context-restriction.v1
    '(domain readers destinations provenance lease-start lease-end semantic-digest))))
(define-type (PooFlowContextFlowDecision @ Type.)
  .element?: (lambda (x) (shape? x 'poo-flow.context-flow-decision.v1
    '(restriction source-digest content-digest principal destination effective-at status
      semantic-digest source-authenticated? flow-admitted? action-authorized? durable?))))
;;; Empty readers/destinations represent no permitted disclosure, never public.
;;; Provenance identities and lease coordinates are declared inputs, not credentials.
(def (poo-flow-context-restriction domain-value readers-value destinations-value
                                   provenance-value start-value end-value)
  (unless (and (text? domain-value) (exact-integer? start-value) (exact-integer? end-value)
               (< start-value end-value)) (error "invalid Context domain or lease"))
  (let* ((r (names readers-value #f)) (d (names destinations-value #f))
         (p (names provenance-value #t))
         (fingerprint (digest (list 'poo-flow.context-restriction.v1 domain-value r d p start-value end-value))))
    (validate PooFlowContextRestriction
      (.o kind: 'poo-flow.context-restriction.v1 domain: (string-copy domain-value)
          readers: r destinations: d provenance: p lease-start: start-value lease-end: end-value
          semantic-digest: fingerprint))))
(def (canonical x)
  (validate PooFlowContextRestriction x)
  (let (value (poo-flow-context-restriction (.ref x 'domain) (.ref x 'readers)
               (.ref x 'destinations) (.ref x 'provenance) (.ref x 'lease-start) (.ref x 'lease-end)))
    (unless (equal? (.ref value 'semantic-digest) (.ref x 'semantic-digest))
      (error "Context restriction digest mismatch")) value))
(def (subset? a b) (every (lambda (x) (member x b)) a))
(def (same-domain a b)
  (unless (equal? (.ref a 'domain) (.ref b 'domain)) (error "incomparable Context domains")))
;;; Reject widening or provenance removal. Declassification needs a separate
;;; Authority/Evidence operation; it cannot be expressed as refinement here.
(def (poo-flow-context-restriction-refinement parent child)
  (let ((a (canonical parent)) (b (canonical child)))
    (same-domain a b)
    (unless (and (subset? (.ref b 'readers) (.ref a 'readers))
                 (subset? (.ref b 'destinations) (.ref a 'destinations))
                 (subset? (.ref a 'provenance) (.ref b 'provenance))
                 (<= (.ref a 'lease-start) (.ref b 'lease-start))
                 (<= (.ref b 'lease-end) (.ref a 'lease-end)))
      (error "Context refinement widens constraints or loses provenance")) b))
(def (intersection a b) (filter (lambda (x) (member x b)) a))
(def (compose-two a b)
  (same-domain a b)
  (poo-flow-context-restriction (.ref a 'domain)
    (intersection (.ref a 'readers) (.ref b 'readers))
    (intersection (.ref a 'destinations) (.ref b 'destinations))
    (delete-duplicates/hash (append (.ref a 'provenance) (.ref b 'provenance)))
    (max (.ref a 'lease-start) (.ref b 'lease-start))
    (min (.ref a 'lease-end) (.ref b 'lease-end))))
(def (poo-flow-context-restriction-compose restrictions)
  (unless (and (list? restrictions) (<= 1 (length restrictions) 32))
    (error "invalid Context composition bound"))
  (let (owned (map canonical restrictions)) (foldl compose-two (car owned) (cdr owned))))
;;; Eligibility relative to declared material. Host source/grant admission and
;;; Data's commit-time fencing must precede any actual disclosure or publication.
(def (poo-flow-context-flow-decision restriction-value source-value content-value
                                   principal-value destination-value now-value)
  (unless (and (digest? source-value) (digest? content-value) (text? principal-value)
               (text? destination-value) (exact-integer? now-value))
    (error "invalid Context flow binding"))
  (let* ((owned (canonical restriction-value))
         (status-value (cond ((< now-value (.ref owned 'lease-start)) 'not-yet-effective)
                             ((>= now-value (.ref owned 'lease-end)) 'expired-lease)
                             ((not (member principal-value (.ref owned 'readers))) 'reader-denied)
                             ((not (member destination-value (.ref owned 'destinations))) 'destination-denied)
                             (else 'eligible)))
         (fingerprint (digest (list 'poo-flow.context-flow-decision.v1 (.ref owned 'semantic-digest)
                                   source-value content-value principal-value destination-value now-value status-value))))
    (validate PooFlowContextFlowDecision
      (.o kind: 'poo-flow.context-flow-decision.v1 restriction: owned
          source-digest: (string-copy source-value) content-digest: (string-copy content-value)
          principal: (string-copy principal-value) destination: (string-copy destination-value)
          effective-at: now-value status: status-value semantic-digest: fingerprint
          source-authenticated?: #f flow-admitted?: #f action-authorized?: #f durable?: #f))))

(def (poo-flow-context-flow-decision-replay receipt)
  (validate PooFlowContextFlowDecision receipt)
  (unless (every (lambda (flag) (eq? (.ref receipt flag) #f))
            '(source-authenticated? flow-admitted? action-authorized? durable?))
    (error "Context eligibility cannot claim admitted IO authority"))
  (let (value (poo-flow-context-flow-decision (.ref receipt 'restriction)
               (.ref receipt 'source-digest) (.ref receipt 'content-digest)
               (.ref receipt 'principal) (.ref receipt 'destination) (.ref receipt 'effective-at)))
    (unless (and (equal? (.ref value 'semantic-digest) (.ref receipt 'semantic-digest))
                 (eq? (.ref value 'status) (.ref receipt 'status)))
      (error "Context flow decision replay mismatch")) value))
