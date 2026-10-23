;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; The index schedules reevaluation; it never retracts a historical proof or
;;; selects a new active conclusion. Completeness is a caller-owned assertion.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every delete-duplicates/hash)
        (only-in :agentic-ai-lab/modules/temporal-causality/revisions/types
                 agentic-ai-lab-temporal-evidence-journal?)
        (only-in :agentic-ai-lab/modules/temporal-causality/revisions/funs
                 agentic-ai-lab-temporal-evidence-as-of)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/types
                 agentic-ai-lab-temporal-derivation?
                 agentic-ai-lab-temporal-dependency-index?)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/objects
                 agentic-ai-lab-temporal-dependency-index-value
                 agentic-ai-lab-temporal-invalidation-plan-value))

(export agentic-ai-lab-temporal-dependency-index
        agentic-ai-lab-temporal-reverse-dependency-plan
        agentic-ai-lab-temporal-reverse-dependency-plan-from-cuts
        agentic-ai-lab-temporal-reverse-dependency-plan-from-projections)

(def (unique? values)
  (= (length values) (length (delete-duplicates/hash values))))
(def (text? value)
  (and (string? value) (> (string-length value) 0)))
(def (digest datum)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string (lambda (port) (write datum port))))))))

(def (agentic-ai-lab-temporal-dependency-index
      identity cut-digest projection-digest complete? derivations)
  (unless (and (text? identity) (text? cut-digest)
               (text? projection-digest) (boolean? complete?)
               (list? derivations) (every agentic-ai-lab-temporal-derivation? derivations))
    (error "invalid temporal dependency inventory"))
  (let ((known (make-hash-table)))
    (for-each
     (lambda (entry)
       (let (id (.ref entry 'identity))
         (when (hash-get known id)
           (error "duplicate temporal derivation" id))
         (unless (and (equal? (.ref entry 'cut-digest) cut-digest)
                      (equal? (.ref entry 'projection-digest)
                              projection-digest)
                      (unique? (.ref entry 'subject-premises))
                      (unique? (.ref entry 'conclusion-premises)))
           (error "invalid temporal derivation premises" id))
         (hash-put! known id #t)))
     derivations)
    (for-each
     (lambda (entry)
       (for-each
        (lambda (parent)
          (unless (hash-get known parent)
            (error "unknown temporal conclusion premise" parent)))
        (.ref entry 'conclusion-premises)))
     derivations)
    (let* ((canonical
            (list-sort (lambda (a b) (string<? (.ref a 'identity) (.ref b 'identity)))
                       derivations))
           (rows
            (map (lambda (entry)
                   (list (.ref entry 'identity) (.ref entry 'policy-identity)
                         (list-sort string<? (.ref entry 'subject-premises))
                         (list-sort string<? (.ref entry 'conclusion-premises))))
                 canonical)))
      (agentic-ai-lab-temporal-dependency-index-value
       identity
       (digest (list 'agentic-ai-lab.temporal-dependency-index.v1
                     cut-digest projection-digest complete? rows))
       cut-digest projection-digest complete? canonical))))

;;; Subject-to-conclusion and conclusion-to-conclusion edges form one reverse
;;; graph. Each node is enqueued once, including in cyclic dependency graphs.
(def (agentic-ai-lab-temporal-reverse-dependency-plan
      index revised-cut-digest revised-projection-digest
      changed-subject-identities)
  (unless (and (agentic-ai-lab-temporal-dependency-index? index)
               (text? revised-cut-digest)
               (text? revised-projection-digest)
               (list? changed-subject-identities)
               (every text? changed-subject-identities)
               (unique? changed-subject-identities))
    (error "invalid temporal invalidation input"))
  (let ((old-cut (.ref index 'cut-digest))
        (old-projection (.ref index 'projection-digest)))
    (when (and (pair? changed-subject-identities)
               (equal? old-cut revised-cut-digest)
               (equal? old-projection revised-projection-digest))
      (error "changed premises require a revised cut or projection"))
    (let ((subject-children (make-hash-table))
          (conclusion-children (make-hash-table))
          (seen (make-hash-table))
          (affected '()))
      (for-each
       (lambda (entry)
         (let (id (.ref entry 'identity))
           (for-each
            (lambda (subject)
              (hash-put! subject-children subject
                         (cons id (or (hash-get subject-children subject) '()))))
            (.ref entry 'subject-premises))
           (for-each
            (lambda (parent)
              (hash-put! conclusion-children parent
                         (cons id (or (hash-get conclusion-children parent) '()))))
            (.ref entry 'conclusion-premises))))
       (.ref index 'derivations))
      (let ((initial
             (apply append
                    (map (lambda (subject)
                           (or (hash-get subject-children subject) '()))
                         changed-subject-identities))))
        (let loop ((front initial) (back '()))
          (cond
           ((pair? front)
            (let ((id (car front)))
              (if (hash-get seen id)
                (loop (cdr front) back)
                (begin
                  (hash-put! seen id #t)
                  (set! affected (cons id affected))
                  (loop (cdr front)
                        (append (or (hash-get conclusion-children id) '())
                                back))))))
           ((pair? back) (loop (reverse back) '()))
           (else
            (agentic-ai-lab-temporal-invalidation-plan-value
             (.ref index 'identity) (.ref index 'semantic-digest)
             old-cut revised-cut-digest
             old-projection revised-projection-digest
             (list-sort string<? changed-subject-identities)
             (list-sort string<? affected)
             (.ref index 'inventory-complete?) 'premise-delta))))))))

;;; Compare visible immutable revision identities for each subject. This
;;; conservatively marks a subject even when its selected head stays the same
;;; but a conflicting branch or historical revision becomes visible.
(def (agentic-ai-lab-temporal-reverse-dependency-plan-from-cuts
      index journal previous-as-of revised-as-of valid-at)
  (unless (and (agentic-ai-lab-temporal-dependency-index? index)
               (agentic-ai-lab-temporal-evidence-journal? journal))
    (error "invalid temporal evidence journal or index"))
  (let* ((previous (agentic-ai-lab-temporal-evidence-as-of
                    journal previous-as-of valid-at))
         (revised (agentic-ai-lab-temporal-evidence-as-of
                   journal revised-as-of valid-at)))
    (unless (and (equal? (.ref index 'cut-digest)
                         (.ref previous 'cut-digest))
                 (equal? (.ref index 'projection-digest)
                         (.ref previous 'projection-digest)))
      (error "temporal dependency index differs from the replayed prior query"))
    (let ((revision-subject (make-hash-table))
        (before (make-hash-table))
        (after (make-hash-table))
        (subjects '()))
    (for-each
     (lambda (revision)
       (hash-put! revision-subject (.ref revision 'identity)
                  (.ref revision 'subject-identity)))
     (.ref journal 'revisions))
    (def (record! snapshot table)
      (let (ids (.ref snapshot 'visible-revision-identities))
        (unless (unique? ids)
          (error "duplicate visible revision in temporal cut"))
        (for-each
         (lambda (id)
           (let (subject (hash-get revision-subject id))
             (unless subject
               (error "temporal cut references an unknown revision" id))
             (hash-put! table subject
                        (cons id (or (hash-get table subject) '())))
             (set! subjects (cons subject subjects))))
         ids)))
    (record! previous before)
    (record! revised after)
    (agentic-ai-lab-temporal-reverse-dependency-plan
     index (.ref revised 'cut-digest) (.ref revised 'projection-digest)
     (filter
      (lambda (subject)
        (not (equal? (list-sort string<? (or (hash-get before subject) '()))
                     (list-sort string<? (or (hash-get after subject) '())))))
      (delete-duplicates/hash subjects))))))

;;; A new valid-time query changes the proof context for every derivation.
;;; Without an explicit parameter-independence contract, no old derivation
;;; can be carried across that scope change, even if selected buckets match.
(def (agentic-ai-lab-temporal-reverse-dependency-plan-from-projections
      index journal as-of previous-valid-at revised-valid-at)
  (unless (and (agentic-ai-lab-temporal-dependency-index? index)
               (agentic-ai-lab-temporal-evidence-journal? journal))
    (error "invalid temporal evidence journal or index"))
  (let* ((previous (agentic-ai-lab-temporal-evidence-as-of
                    journal as-of previous-valid-at))
         (revised (agentic-ai-lab-temporal-evidence-as-of
                   journal as-of revised-valid-at)))
    (unless (and (equal? (.ref index 'cut-digest)
                         (.ref previous 'cut-digest))
                 (equal? (.ref index 'projection-digest)
                         (.ref previous 'projection-digest))
                 (not (equal? (.ref previous 'valid-at-instant-digest)
                              (.ref revised 'valid-at-instant-digest))))
      (error "invalid temporal valid-time reprojection input"))
    (agentic-ai-lab-temporal-invalidation-plan-value
     (.ref index 'identity) (.ref index 'semantic-digest)
     (.ref previous 'cut-digest) (.ref revised 'cut-digest)
     (.ref previous 'projection-digest) (.ref revised 'projection-digest)
     '()
     (map (lambda (entry) (.ref entry 'identity)) (.ref index 'derivations))
     (.ref index 'inventory-complete?) 'valid-time-reprojection)))
