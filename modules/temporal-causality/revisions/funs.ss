;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Bitemporal evidence selection, without mutating history or executing
;;; downstream invalidation/effects. Admission time is separate from validity.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every filter delete-duplicates/hash)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types
                 agentic-ai-lab-temporal-instant?)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/funs
                 agentic-ai-lab-temporal-interval-contains?)
        (only-in :agentic-ai-lab/modules/temporal-causality/revisions/types
                 agentic-ai-lab-temporal-evidence-revision?
                 agentic-ai-lab-temporal-evidence-journal?)
        (only-in :agentic-ai-lab/modules/temporal-causality/revisions/objects
                 agentic-ai-lab-temporal-evidence-journal-value
                 agentic-ai-lab-temporal-evidence-snapshot-value))

(export agentic-ai-lab-temporal-evidence-journal
        agentic-ai-lab-temporal-evidence-as-of)

(def (digest datum)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string (lambda (port) (write datum port))))))))

(def (instant-row instant)
  (list (.ref instant 'identity) (.ref instant 'domain-identity)
        (.ref instant 'coordinate) (.ref instant 'provenance-identity)
        (.ref instant 'modality)))

(def (interval-row interval)
  (and interval
       (list (.ref interval 'identity)
             (instant-row (.ref interval 'start))
             (instant-row (.ref interval 'end))
             (.ref interval 'start-closed?)
             (.ref interval 'end-closed?))))

(def (revision-row revision)
  (list (.ref revision 'identity)
        (.ref revision 'subject-identity)
        (.ref revision 'operation)
        (.ref revision 'predecessor-identity)
        (instant-row (.ref revision 'admission-instant))
        (interval-row (.ref revision 'valid-interval))
        (.ref revision 'content-identity)))

(def (revision<? left right)
  (string<? (.ref left 'identity) (.ref right 'identity)))

;;; The journal is a set of immutable revisions. A predecessor must be in the
;;; same subject and earlier on one observed admission clock. Branches remain
;;; possible and are reported as conflicts at query time.
(def (agentic-ai-lab-temporal-evidence-journal identity-value domain-value revisions)
  (unless (and (string? identity-value) (> (string-length identity-value) 0)
               (string? domain-value) (> (string-length domain-value) 0)
               (list? revisions)
               (every agentic-ai-lab-temporal-evidence-revision? revisions))
    (error "invalid temporal evidence journal inventory"))
  (let ((index (make-hash-table)))
    (for-each
     (lambda (revision)
       (let ((id (.ref revision 'identity))
             (admission (.ref revision 'admission-instant)))
         (when (hash-get index id)
           (error "duplicate temporal evidence revision" id))
         (unless (equal? (.ref admission 'domain-identity) domain-value)
           (error "revision admission clock differs from journal" id))
         (hash-put! index id revision)))
     revisions)
    (for-each
     (lambda (revision)
       (let (predecessor-id (.ref revision 'predecessor-identity))
         (when predecessor-id
           (let (predecessor (hash-get index predecessor-id))
             (unless (and predecessor
                          (equal? (.ref predecessor 'subject-identity)
                                  (.ref revision 'subject-identity))
                          (not (eq? (.ref predecessor 'operation) 'retract))
                          (< (.ref (.ref predecessor 'admission-instant)
                                   'coordinate)
                             (.ref (.ref revision 'admission-instant)
                                   'coordinate)))
               (error "invalid temporal evidence predecessor" predecessor-id))))))
     revisions))
  (let* ((canonical (list-sort revision<? revisions))
         (semantic-digest
          (digest (list 'agentic-ai-lab.temporal-evidence-journal.v1
                        identity-value domain-value
                        (map revision-row canonical)))))
    (agentic-ai-lab-temporal-evidence-journal-value
     identity-value semantic-digest domain-value canonical)))

;;; Project one immutable admission-time cut. A valid-at instant optionally
;;; filters the selected head of each subject. Branching heads are conflicts,
;;; never an arbitrary latest-value winner.
(def (agentic-ai-lab-temporal-evidence-as-of journal as-of valid-at)
  (unless (and (agentic-ai-lab-temporal-evidence-journal? journal)
               (agentic-ai-lab-temporal-instant? as-of)
               (eq? (.ref as-of 'modality) 'observed)
               (equal? (.ref as-of 'domain-identity)
                       (.ref journal 'admission-domain-identity))
               (or (not valid-at) (agentic-ai-lab-temporal-instant? valid-at)))
    (error "invalid temporal evidence as-of query"))
  (let (canonical
        (agentic-ai-lab-temporal-evidence-journal
         (.ref journal 'identity)
         (.ref journal 'admission-domain-identity)
         (.ref journal 'revisions)))
    (unless (equal? (.ref journal 'semantic-digest)
                    (.ref canonical 'semantic-digest))
      (error "temporal evidence journal digest differs from its revisions")))
  (let* ((revisions (.ref journal 'revisions))
         (cut-position (.ref as-of 'coordinate))
         (visible
          (filter (lambda (revision)
                    (<= (.ref (.ref revision 'admission-instant) 'coordinate)
                        cut-position)) revisions))
         (future
          (filter (lambda (revision)
                    (> (.ref (.ref revision 'admission-instant) 'coordinate)
                       cut-position)) revisions))
         (visible-by-subject (make-hash-table))
         (superseded (make-hash-table))
         (subjects '())
         (active '()) (retracted '()) (conflicted '())
         (outside '()) (uncertain '()) (incomparable '()))
    (for-each
     (lambda (revision)
       (let ((subject (.ref revision 'subject-identity))
             (predecessor (.ref revision 'predecessor-identity)))
         (hash-put! visible-by-subject subject
                    (cons revision (or (hash-get visible-by-subject subject)
                                       '())))
         (set! subjects (cons subject subjects))
         (when predecessor (hash-put! superseded predecessor #t))))
     visible)
    (for-each
     (lambda (subject)
       (let (heads
             (filter (lambda (revision)
                       (not (hash-get superseded (.ref revision 'identity))))
                     (hash-get visible-by-subject subject)))
         (cond
          ((not (= (length heads) 1))
           (set! conflicted (cons subject conflicted)))
          ((eq? (.ref (car heads) 'operation) 'retract)
           (set! retracted (cons subject retracted)))
          (else
           (let* ((head (car heads))
                  (membership
                   (if valid-at
                     (agentic-ai-lab-temporal-interval-contains?
                      (.ref head 'valid-interval) valid-at)
                     #t)))
             (cond
              ((eq? membership #t)
               (set! active (cons (.ref head 'identity) active)))
              ((eq? membership #f)
               (set! outside (cons subject outside)))
              ((eq? membership 'incomparable)
               (set! incomparable (cons subject incomparable)))
              (else (set! uncertain (cons subject uncertain)))))))))
     (list-sort string<? (delete-duplicates/hash subjects)))
    (let* ((cut-digest
            (digest (list 'agentic-ai-lab.temporal-evidence-cut.v1
                          (.ref journal 'identity) (instant-row as-of)
                          (map revision-row visible))))
           (valid-at-digest (and valid-at (digest (instant-row valid-at))))
           (active (list-sort string<? active))
           (retracted (list-sort string<? retracted))
           (conflicted (list-sort string<? conflicted))
           (outside (list-sort string<? outside))
           (uncertain (list-sort string<? uncertain))
           (incomparable (list-sort string<? incomparable))
           (projection-digest
            (digest (list 'agentic-ai-lab.temporal-evidence-projection.v1
                          cut-digest valid-at-digest
                          active retracted conflicted outside
                          uncertain incomparable))))
      (agentic-ai-lab-temporal-evidence-snapshot-value
       (.ref journal 'semantic-digest) cut-digest projection-digest
       (.ref as-of 'identity)
       (and valid-at (.ref valid-at 'identity)) valid-at-digest
       active retracted conflicted outside uncertain incomparable
       (map (lambda (revision) (.ref revision 'identity)) visible)
       (map (lambda (revision) (.ref revision 'identity)) future)))))
