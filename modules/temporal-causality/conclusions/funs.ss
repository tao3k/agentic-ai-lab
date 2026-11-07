;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Historical conclusions are values. Selection is only a CAS proposal;
;;; no proof, authorization, pointer update or effect is executed here.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every find)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/types
                 agentic-ai-lab-temporal-invalidation-plan?)
        (only-in :agentic-ai-lab/modules/temporal-causality/conclusions/types
                 agentic-ai-lab-temporal-conclusion-revision?
                 agentic-ai-lab-temporal-conclusion-journal?
                 agentic-ai-lab-temporal-selection-observation?
                 agentic-ai-lab-temporal-selection-plan?)
        (only-in :agentic-ai-lab/modules/temporal-causality/conclusions/objects
                 agentic-ai-lab-temporal-conclusion-revision-value
                 agentic-ai-lab-temporal-conclusion-journal-value
                 agentic-ai-lab-temporal-selection-plan-value))

(export agentic-ai-lab-temporal-conclusion-root
        agentic-ai-lab-temporal-conclusion-change
        agentic-ai-lab-temporal-conclusion-journal
        agentic-ai-lab-temporal-conclusion-journal-replay
        agentic-ai-lab-temporal-conclusion-journal-extend
        agentic-ai-lab-temporal-selection-prepare
        agentic-ai-lab-temporal-selection-plan-replay)

(def (text? value)
  (and (string? value) (> (string-length value) 0)))
(def (natural? value)
  (and (integer? value) (exact? value) (>= value 0)))
(def (digest datum)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string (lambda (port) (write datum port))))))))

;;; A root conclusion carries an evaluator-owned proof identity. This type
;;; validates the envelope, not the theorem or domain result it names.
(def (agentic-ai-lab-temporal-conclusion-root
      identity subject scope cut projection policy generation result proof)
  (agentic-ai-lab-temporal-conclusion-revision-value
   identity subject scope cut projection policy generation
   'assert #f result proof #f))

;;; The invalidation plan establishes only the reevaluation frontier. The
;;; caller supplies a separate proof identity for the corrected/retracted
;;; result; the actual proof admission remains with its evaluator.
(def (agentic-ai-lab-temporal-conclusion-change
      identity previous plan operation result proof policy generation)
  (unless (and (agentic-ai-lab-temporal-conclusion-revision? previous)
               (agentic-ai-lab-temporal-invalidation-plan? plan)
               (text? identity) (text? proof) (text? policy)
               (text? generation)
               (not (equal? identity (.ref previous 'identity)))
               (memq operation '(correct retract))
               (not (eq? (.ref previous 'operation) 'retract))
               (eq? (.ref plan 'status) 'scoped-complete)
               (member (.ref previous 'identity)
                       (.ref plan 'affected-conclusion-identities))
               (equal? (.ref previous 'cut-digest)
                       (.ref plan 'previous-cut-digest))
               (equal? (.ref previous 'projection-digest)
                       (.ref plan 'previous-projection-digest))
               (or (not (equal? (.ref previous 'cut-digest)
                                (.ref plan 'revised-cut-digest)))
                   (not (equal? (.ref previous 'projection-digest)
                                (.ref plan 'revised-projection-digest))))
               (if (eq? operation 'correct) (text? result) (not result)))
    (error "conclusion change lacks a complete affected frontier or proof binding"))
  (agentic-ai-lab-temporal-conclusion-revision-value
   identity (.ref previous 'subject-identity) (.ref previous 'scope-identity)
   (.ref plan 'revised-cut-digest) (.ref plan 'revised-projection-digest)
   policy generation operation
   (.ref previous 'identity) result proof (.ref plan 'index-digest)))

(def (revision-row revision)
  (map (lambda (slot) (.ref revision slot))
       '(identity subject-identity scope-identity cut-digest projection-digest
         policy-identity
         generation-identity operation predecessor-identity result-identity
         proof-identity invalidation-index-digest)))

;;; A journal is a finite immutable graph. Correction branches are retained;
;;; they are not resolved by identity order or a latest-value rule.
(def (agentic-ai-lab-temporal-conclusion-journal identity revisions)
  (unless (and (text? identity) (list? revisions)
               (every agentic-ai-lab-temporal-conclusion-revision? revisions))
    (error "invalid temporal conclusion journal"))
  (let ((index (make-hash-table))
        (color (make-hash-table)))
    (for-each
     (lambda (revision)
       (let (id (.ref revision 'identity))
         (when (hash-get index id)
           (error "duplicate temporal conclusion revision" id))
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
                          (equal? (.ref predecessor 'scope-identity)
                                  (.ref revision 'scope-identity))
                          (not (eq? (.ref predecessor 'operation) 'retract))
                          (or (not (equal? (.ref predecessor 'cut-digest)
                                           (.ref revision 'cut-digest)))
                              (not (equal? (.ref predecessor 'projection-digest)
                                           (.ref revision 'projection-digest)))))
               (error "invalid temporal conclusion supersession" predecessor-id))))))
     revisions)
    (def (visit! revision)
      (let (id (.ref revision 'identity))
        (case (hash-get color id)
          ((done) (void))
          ((visiting) (error "cyclic temporal conclusion supersession" id))
          (else
           (hash-put! color id 'visiting)
           (let (predecessor-id (.ref revision 'predecessor-identity))
             (when predecessor-id (visit! (hash-get index predecessor-id))))
           (hash-put! color id 'done)))))
    (for-each visit! revisions)
    (let (canonical
          (list-sort (lambda (a b)
                       (string<? (.ref a 'identity) (.ref b 'identity)))
                     revisions))
      (agentic-ai-lab-temporal-conclusion-journal-value
       identity
       (digest (list 'agentic-ai-lab.temporal-conclusion-journal.v1
                     identity (map revision-row canonical)))
       canonical))))

;;; Check the complete graph and digest again at the point of use. A POO
;;; journal value can be copied across a boundary or reconstructed by a caller;
;;; its type shape alone does not bind its digest to its rows.
(def (agentic-ai-lab-temporal-conclusion-journal-replay journal)
  (unless (agentic-ai-lab-temporal-conclusion-journal? journal)
    (error "invalid temporal conclusion journal"))
  (let (canonical
        (agentic-ai-lab-temporal-conclusion-journal
         (.ref journal 'identity) (.ref journal 'revisions)))
    (unless (equal? (.ref canonical 'semantic-digest)
                    (.ref journal 'semantic-digest))
      (error "temporal conclusion journal digest mismatch"))
    canonical))

;;; Preserve every old row when admitting a new set of revision envelopes.
(def (agentic-ai-lab-temporal-conclusion-journal-extend journal additions)
  (unless (and (agentic-ai-lab-temporal-conclusion-journal? journal)
               (list? additions) (pair? additions)
               (every agentic-ai-lab-temporal-conclusion-revision? additions))
    (error "invalid temporal conclusion journal extension"))
  (agentic-ai-lab-temporal-conclusion-journal-replay journal)
  (agentic-ai-lab-temporal-conclusion-journal
   (.ref journal 'identity)
   (append (.ref journal 'revisions) additions)))

;;; Prepare an external compare-and-swap over a versioned active pointer.
;;; A ready plan can still lose a race before the runtime commits it.
(def (agentic-ai-lab-temporal-selection-prepare
      journal proposed observation expected-version)
  (unless (and (agentic-ai-lab-temporal-conclusion-journal? journal)
               (agentic-ai-lab-temporal-conclusion-revision? proposed)
               (agentic-ai-lab-temporal-selection-observation? observation)
               (natural? expected-version)
               (memq (.ref proposed 'operation) '(correct retract))
               (equal? (.ref proposed 'subject-identity)
                       (.ref observation 'subject-identity))
               (equal? (.ref proposed 'scope-identity)
                       (.ref observation 'scope-identity)))
    (error "invalid temporal active-selection request"))
  (agentic-ai-lab-temporal-conclusion-journal-replay journal)
  (let (stored
        (find (lambda (entry)
                (equal? (.ref entry 'identity) (.ref proposed 'identity)))
              (.ref journal 'revisions)))
    (unless (and stored (equal? (revision-row stored) (revision-row proposed)))
      (error "selected revision differs from journal evidence")))
  (let* ((expected-id (.ref proposed 'predecessor-identity))
         (ready? (and (= expected-version (.ref observation 'version))
                      (equal? expected-id
                              (.ref observation 'selected-revision-identity)))))
    (agentic-ai-lab-temporal-selection-plan-value
     (.ref journal 'semantic-digest) (.ref observation 'identity)
     (.ref proposed 'subject-identity) (.ref proposed 'scope-identity)
     expected-version expected-id
     (and ready? (+ expected-version 1))
     (.ref observation 'version)
     (.ref observation 'selected-revision-identity)
     (.ref proposed 'identity) (.ref proposed 'proof-identity)
     (if ready? 'cas-ready 'conflict))))

;;; A runtime consumer can replay the whole proposal against fresh, explicit
;;; inputs before attempting its own authorized atomic compare-and-swap.
;;; Replay does not establish authority or commit the pointer.
(def (selection-plan-row plan)
  (map (lambda (slot) (.ref plan slot))
       '(journal-digest observation-identity subject-identity scope-identity
         expected-version expected-revision-identity proposed-version
         observed-version observed-revision-identity
         proposed-revision-identity change-proof-identity status
         requires-atomic-cas? runtime-executed?)))

(def (agentic-ai-lab-temporal-selection-plan-replay
      plan journal proposed observation)
  (unless (agentic-ai-lab-temporal-selection-plan? plan)
    (error "invalid temporal selection plan"))
  (let (canonical
        (agentic-ai-lab-temporal-selection-prepare
         journal proposed observation (.ref plan 'expected-version)))
    (unless (equal? (selection-plan-row canonical)
                    (selection-plan-row plan))
      (error "temporal selection plan differs from its inputs"))
    canonical))
