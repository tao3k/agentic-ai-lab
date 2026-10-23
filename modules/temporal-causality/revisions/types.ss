;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Immutable evidence history; active selection is a pure as-of projection.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types
                 agentic-ai-lab-temporal-instant? agentic-ai-lab-temporal-interval?))

(export agentic-ai-lab-temporal-evidence-revision-kind
        agentic-ai-lab-temporal-evidence-journal-kind
        agentic-ai-lab-temporal-evidence-snapshot-kind
        AgenticAILabTemporalEvidenceRevision AgenticAILabTemporalEvidenceJournal
        AgenticAILabTemporalEvidenceSnapshot
        agentic-ai-lab-temporal-evidence-revision?
        agentic-ai-lab-temporal-evidence-journal?
        agentic-ai-lab-temporal-evidence-snapshot?)

(def agentic-ai-lab-temporal-evidence-revision-kind
  'agentic-ai-lab.temporal-causality.evidence-revision)
(def agentic-ai-lab-temporal-evidence-journal-kind
  'agentic-ai-lab.temporal-causality.evidence-journal)
(def agentic-ai-lab-temporal-evidence-snapshot-kind
  'agentic-ai-lab.temporal-causality.evidence-snapshot)

(def (text? value)
  (and (string? value) (> (string-length value) 0)))
(def (slots? value names)
  (and (object? value) (every (lambda (name) (.slot? value name)) names)))
(def (text-list? value)
  (and (list? value) (every text? value)))

(def (revision-shape? value)
  (and (slots? value '(kind identity subject-identity operation
                             predecessor-identity admission-instant
                             valid-interval content-identity))
       (eq? (.ref value 'kind) agentic-ai-lab-temporal-evidence-revision-kind)
       (text? (.ref value 'identity))
       (text? (.ref value 'subject-identity))
       (agentic-ai-lab-temporal-instant? (.ref value 'admission-instant))
       (eq? (.ref (.ref value 'admission-instant) 'modality) 'observed)
       (case (.ref value 'operation)
         ((assert)
          (and (not (.ref value 'predecessor-identity))
               (agentic-ai-lab-temporal-interval? (.ref value 'valid-interval))
               (text? (.ref value 'content-identity))))
         ((correct)
          (and (text? (.ref value 'predecessor-identity))
               (agentic-ai-lab-temporal-interval? (.ref value 'valid-interval))
               (text? (.ref value 'content-identity))))
         ((retract)
          (and (text? (.ref value 'predecessor-identity))
               (not (.ref value 'valid-interval))
               (not (.ref value 'content-identity))))
         (else #f))))

(define-type (AgenticAILabTemporalEvidenceRevision @ Type.)
  .element?: revision-shape?)
(def (agentic-ai-lab-temporal-evidence-revision? value)
  (element? AgenticAILabTemporalEvidenceRevision value))

(def (journal-shape? value)
  (and (slots? value '(kind identity semantic-digest admission-domain-identity
                             revisions))
       (eq? (.ref value 'kind) agentic-ai-lab-temporal-evidence-journal-kind)
       (every text? (list (.ref value 'identity)
                          (.ref value 'semantic-digest)
                          (.ref value 'admission-domain-identity)))
       (list? (.ref value 'revisions))
       (every agentic-ai-lab-temporal-evidence-revision?
              (.ref value 'revisions))))

(define-type (AgenticAILabTemporalEvidenceJournal @ Type.)
  .element?: journal-shape?)
(def (agentic-ai-lab-temporal-evidence-journal? value)
  (element? AgenticAILabTemporalEvidenceJournal value))

(def (snapshot-shape? value)
  (and (slots? value
               '(kind journal-digest cut-digest projection-digest
                      as-of-instant-identity valid-at-instant-identity
                      valid-at-instant-digest active-revision-identities
                      retracted-subject-identities conflicted-subject-identities
                      outside-valid-subject-identities uncertain-subject-identities
                      incomparable-subject-identities
                      visible-revision-identities future-revision-identities
                      runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-temporal-evidence-snapshot-kind)
       (every text? (list (.ref value 'journal-digest)
                          (.ref value 'cut-digest)
                          (.ref value 'projection-digest)
                          (.ref value 'as-of-instant-identity)))
       (or (not (.ref value 'valid-at-instant-identity))
           (text? (.ref value 'valid-at-instant-identity)))
       (or (and (not (.ref value 'valid-at-instant-identity))
                (not (.ref value 'valid-at-instant-digest)))
           (and (text? (.ref value 'valid-at-instant-identity))
                (text? (.ref value 'valid-at-instant-digest))))
       (every (lambda (slot) (text-list? (.ref value slot)))
              '(active-revision-identities retracted-subject-identities
                conflicted-subject-identities outside-valid-subject-identities
                uncertain-subject-identities incomparable-subject-identities
                visible-revision-identities
                future-revision-identities))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabTemporalEvidenceSnapshot @ Type.)
  .element?: snapshot-shape?)
(def (agentic-ai-lab-temporal-evidence-snapshot? value)
  (element? AgenticAILabTemporalEvidenceSnapshot value))
