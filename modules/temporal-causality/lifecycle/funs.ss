;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Pure proof-bound revisions; no durable append, current-pointer CAS or effect.
(import (only-in :clan/poo/object .ref)
        (only-in :std/list/list every)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :agentic-ai-lab/modules/temporal-causality/admission/interface
                 agentic-ai-lab-temporal-family-admission-replay)
        (only-in :agentic-ai-lab/modules/temporal-causality/conclusions/funs
                 agentic-ai-lab-temporal-conclusion-change agentic-ai-lab-temporal-conclusion-journal
                 agentic-ai-lab-temporal-conclusion-journal-replay)
        (only-in :agentic-ai-lab/modules/temporal-causality/lifecycle/types
                 agentic-ai-lab-temporal-family-revision? agentic-ai-lab-temporal-family-archive?)
        (only-in :agentic-ai-lab/modules/temporal-causality/lifecycle/objects
                 agentic-ai-lab-temporal-family-revision-value agentic-ai-lab-temporal-family-archive-value))
(export agentic-ai-lab-temporal-family-revision-root agentic-ai-lab-temporal-family-revision-change
        agentic-ai-lab-temporal-family-revision-replay agentic-ai-lab-temporal-family-revision-journal
        agentic-ai-lab-temporal-family-archive agentic-ai-lab-temporal-family-archive-replay)
(def revision-slots
  '(identity subject-identity scope-identity cut-digest projection-digest policy-identity
    generation-identity operation predecessor-identity result-identity proof-identity
    invalidation-index-digest))
(def frontier-slots
  '(index-identity index-digest previous-cut-digest revised-cut-digest
    previous-projection-digest revised-projection-digest changed-subject-identities
    affected-conclusion-identities status inventory-complete? trigger))
(def (row value slots) (map (lambda (slot) (.ref value slot)) slots))
(def (digest value)
  (string-append "sha256:" (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (port) (write value port))))))))
(def (make-revision admission revision predecessor frontier)
  (agentic-ai-lab-temporal-family-revision-value
   (digest (list 'agentic-ai-lab.temporal-family-revision.v1
                 (.ref admission 'semantic-digest) (row revision revision-slots)
                 (and predecessor (.ref predecessor 'semantic-digest))
                 (and frontier (row frontier frontier-slots))))
   admission revision predecessor frontier))
(def (agentic-ai-lab-temporal-family-revision-root admission)
  (let (canonical (agentic-ai-lab-temporal-family-admission-replay admission))
    (make-revision canonical (.ref canonical 'conclusion) #f #f)))
(def (change previous admission frontier operation)
  (let* ((old (.ref previous 'admission))
         (prior-source (.ref old 'source)) (source (.ref admission 'source))
         (revision (.ref previous 'revision))
         (proof (.ref (.ref admission 'conclusion) 'proof-identity)))
    (unless (and (memq operation '(correct retract))
                 (every (lambda (slot) (equal? (.ref prior-source slot) (.ref source slot)))
                        '(identity authority-identity subject-identity scope-identity))
                 (equal? (.ref old 'conclusion-identity) (.ref admission 'conclusion-identity))
                 (equal? (.ref (.ref old 'model) 'identity) (.ref (.ref admission 'model) 'identity))
                 (equal? (row (.ref old 'query) '(identity hypothesis-identity exploration-limit))
                         (row (.ref admission 'query) '(identity hypothesis-identity exploration-limit)))
                 (> (.ref source 'generation) (.ref prior-source 'generation))
                 (eq? (.ref frontier 'inventory-complete?) #t)
                 (equal? (.ref source 'cut-digest) (.ref frontier 'revised-cut-digest))
                 (equal? (.ref source 'projection-digest) (.ref frontier 'revised-projection-digest))
                 ;; Refutation is scoped to this replayed family query. A frontier alone
                 ;; does not authorize withdrawal or prove support stabilization.
                 (or (eq? operation 'correct)
                     (and (memq (.ref old 'classification) '(possible necessary))
                          (eq? (.ref admission 'classification) 'refuted))))
      (error "family revision scope, generation, cut or retraction proof differs"))
    (let (proposed
          (agentic-ai-lab-temporal-conclusion-change
           (digest (list 'agentic-ai-lab.temporal-family-change.v1 (.ref revision 'identity)
                         (.ref admission 'semantic-digest) operation (row frontier frontier-slots)))
           revision frontier operation (and (eq? operation 'correct) proof) proof
           (.ref source 'policy-identity) (number->string (.ref source 'generation))))
      (make-revision admission proposed previous frontier))))
(def (agentic-ai-lab-temporal-family-revision-change previous admission frontier operation)
  (change (agentic-ai-lab-temporal-family-revision-replay previous)
          (agentic-ai-lab-temporal-family-admission-replay admission) frontier operation))
(def (agentic-ai-lab-temporal-family-revision-replay value)
  (def (walk value ancestors)
    (unless (agentic-ai-lab-temporal-family-revision? value) (error "invalid family revision"))
    (let (id (.ref (.ref value 'revision) 'identity))
      (when (member id ancestors) (error "cyclic family revision predecessor"))
      (let* ((admission (agentic-ai-lab-temporal-family-admission-replay (.ref value 'admission)))
             (canonical
              (if (.ref value 'predecessor)
                (change (walk (.ref value 'predecessor) (cons id ancestors))
                        admission (.ref value 'frontier) (.ref (.ref value 'revision) 'operation))
                (agentic-ai-lab-temporal-family-revision-root admission))))
        (unless (and (equal? (.ref canonical 'semantic-digest) (.ref value 'semantic-digest))
                     (equal? (row (.ref canonical 'revision) revision-slots)
                             (row (.ref value 'revision) revision-slots)))
          (error "family revision proof or journal binding mismatch"))
        canonical)))
  (walk value '()))
(def (agentic-ai-lab-temporal-family-revision-journal identity values)
  (agentic-ai-lab-temporal-conclusion-journal
   identity (map (lambda (value)
                   (.ref (agentic-ai-lab-temporal-family-revision-replay value) 'revision)) values)))

;;; A pure POO archive owns complete Family proof premises and a canonical graph.
;;; Projection onto persistent bytes belongs to the explicit ABI boundary.
(def (agentic-ai-lab-temporal-family-archive identity values)
  (unless (and (string? identity) (< 0 (string-length identity) 129)
               (list? values) (<= 1 (length values) 128))
    (error "family archive identity or inventory bound"))
  (let* ((canonical (list-sort
                    (lambda (a b) (string<? (.ref a 'semantic-digest) (.ref b 'semantic-digest)))
                    (map agentic-ai-lab-temporal-family-revision-replay values)))
         (journal (agentic-ai-lab-temporal-family-revision-journal identity canonical)))
    (agentic-ai-lab-temporal-family-archive-value identity
     (digest (list 'agentic-ai-lab.temporal-family-archive.v1 identity
                   (.ref journal 'semantic-digest)
                   (map (lambda (v) (.ref v 'semantic-digest)) canonical))) canonical journal)))
(def (agentic-ai-lab-temporal-family-archive-replay value)
  (unless (agentic-ai-lab-temporal-family-archive? value) (error "invalid family archive"))
  (agentic-ai-lab-temporal-conclusion-journal-replay (.ref value 'journal))
  (let (canonical (agentic-ai-lab-temporal-family-archive
                   (.ref value 'identity) (.ref value 'family-revisions)))
    (unless (and (equal? (.ref canonical 'semantic-digest) (.ref value 'semantic-digest))
                 (equal? (.ref (.ref canonical 'journal) 'semantic-digest)
                         (.ref (.ref value 'journal) 'semantic-digest)))
      (error "family archive binding mismatch"))
    canonical))
