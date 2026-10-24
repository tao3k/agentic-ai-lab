;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure, declared evidence relations. An assessment is a separate attestation
;;; bound to one exact use; this module does not prove its semantic verdict.
(import (only-in :clan/poo/object .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every delete-duplicates/hash)
        (only-in :agentic-ai-lab/modules/temporal-causality/evidence/types
                 agentic-ai-lab-evidence-retrieval? agentic-ai-lab-evidence-use?
                 agentic-ai-lab-evidence-assessment?
                 agentic-ai-lab-evidence-dependency? agentic-ai-lab-evidence-lineage?)
        (only-in :agentic-ai-lab/modules/temporal-causality/evidence/objects
                 agentic-ai-lab-evidence-retrieval-value agentic-ai-lab-evidence-use-value
                 agentic-ai-lab-evidence-assessment-value
                 agentic-ai-lab-evidence-dependency-value agentic-ai-lab-evidence-lineage-value
                 agentic-ai-lab-evidence-use-audit-value
                 agentic-ai-lab-evidence-impact-frontier-value))
(export agentic-ai-lab-evidence-retrieval agentic-ai-lab-evidence-use
        agentic-ai-lab-evidence-assessment
        agentic-ai-lab-evidence-dependency agentic-ai-lab-evidence-lineage
        agentic-ai-lab-evidence-use-audit agentic-ai-lab-evidence-impact-frontier)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (texts? value) (and (list? value) (every text? value)))
(def (unique? values)
  (= (length values) (length (delete-duplicates/hash values))))
(def (sorted values) (list-sort string<? values))
(def (digest datum)
  (string-append "sha256:"
   (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (port) (write datum port))))))))
(def (ids items) (map (lambda (item) (.ref item 'identity)) items))
(def (order items)
  (list-sort (lambda (a b) (string<? (.ref a 'identity) (.ref b 'identity)))
             items))

(def (agentic-ai-lab-evidence-retrieval id query evidence source)
  (unless (every text? (list id query evidence source))
    (error "invalid evidence retrieval"))
  (agentic-ai-lab-evidence-retrieval-value
   id (digest (list 'poo-flow.evidence-retrieval.v1 id query evidence source))
   query evidence source))

(def (agentic-ai-lab-evidence-use id evidence claim source claim-digest)
  (unless (every text? (list id evidence claim source claim-digest))
    (error "invalid evidence use"))
  (agentic-ai-lab-evidence-use-value
   id (digest (list 'poo-flow.evidence-use.v1 id evidence claim source
                    claim-digest))
   evidence claim source claim-digest))

(def (agentic-ai-lab-evidence-assessment id use assessor method verdict basis)
  (unless (and (text? id) (agentic-ai-lab-evidence-use? use)
               (every text? (list assessor method basis))
               (memq verdict '(supports refutes uncertain)))
    (error "invalid evidence assessment"))
  (let (replayed (agentic-ai-lab-evidence-use
                 (.ref use 'identity) (.ref use 'evidence-identity)
                 (.ref use 'claim-identity) (.ref use 'source-digest)
                 (.ref use 'claim-digest)))
    (unless (equal? (.ref use 'semantic-digest)
                    (.ref replayed 'semantic-digest))
      (error "evidence assessment use digest mismatch"))
    (agentic-ai-lab-evidence-assessment-value
     id (digest (list 'poo-flow.evidence-assessment.v1 id
                      (.ref use 'identity) (.ref use 'semantic-digest)
                      assessor method verdict basis))
     (.ref use 'identity) (.ref use 'semantic-digest)
     assessor method verdict basis)))

(def (agentic-ai-lab-evidence-dependency id source dependent)
  (unless (and (every text? (list id source dependent))
               (not (equal? source dependent)))
    (error "invalid evidence dependency"))
  (agentic-ai-lab-evidence-dependency-value
   id (digest (list 'poo-flow.evidence-dependency.v1 id source dependent))
   source dependent))

(def (replay-retrieval item)
  (unless (agentic-ai-lab-evidence-retrieval? item)
    (error "invalid evidence retrieval object"))
  (let (replayed
        (agentic-ai-lab-evidence-retrieval
         (.ref item 'identity) (.ref item 'query-identity)
         (.ref item 'evidence-identity) (.ref item 'source-digest)))
    (unless (equal? (.ref item 'semantic-digest)
                    (.ref replayed 'semantic-digest))
      (error "evidence retrieval digest mismatch"))
    replayed))
(def (replay-use item)
  (unless (agentic-ai-lab-evidence-use? item)
    (error "invalid evidence use object"))
  (let (replayed
        (agentic-ai-lab-evidence-use
         (.ref item 'identity) (.ref item 'evidence-identity)
         (.ref item 'claim-identity) (.ref item 'source-digest)
         (.ref item 'claim-digest)))
    (unless (equal? (.ref item 'semantic-digest)
                    (.ref replayed 'semantic-digest))
      (error "evidence use digest mismatch"))
    replayed))
(def (replay-assessment item use-by-id)
  (unless (agentic-ai-lab-evidence-assessment? item)
    (error "invalid evidence assessment object"))
  (let (use (hash-get use-by-id (.ref item 'use-identity)))
    (unless (and use
                 (equal? (.ref use 'semantic-digest)
                         (.ref item 'use-digest)))
      (error "evidence assessment names an absent or revised use"))
    (let (replayed
          (agentic-ai-lab-evidence-assessment
           (.ref item 'identity) use (.ref item 'assessor-identity)
           (.ref item 'method-identity) (.ref item 'verdict)
           (.ref item 'basis-digest)))
      (unless (equal? (.ref item 'semantic-digest)
                      (.ref replayed 'semantic-digest))
        (error "evidence assessment digest mismatch"))
      replayed)))
(def (replay-dependency item)
  (unless (agentic-ai-lab-evidence-dependency? item)
    (error "invalid evidence dependency object"))
  (let (replayed
        (agentic-ai-lab-evidence-dependency
         (.ref item 'identity) (.ref item 'source-claim-identity)
         (.ref item 'dependent-claim-identity)))
    (unless (equal? (.ref item 'semantic-digest)
                    (.ref replayed 'semantic-digest))
      (error "evidence dependency digest mismatch"))
    replayed))

(def (agentic-ai-lab-evidence-lineage id retrievals uses assessments dependencies)
  (unless (and (text? id) (list? retrievals) (list? uses)
               (list? assessments) (list? dependencies))
    (error "invalid evidence lineage input"))
  (let* ((retrievals (order (map replay-retrieval retrievals)))
         (uses (order (map replay-use uses)))
         (dependencies (order (map replay-dependency dependencies)))
         (use-by-id (make-hash-table))
         (source-by-evidence (make-hash-table))
         (claim-by-id (make-hash-table)))
    (unless (unique? (ids uses))
      (error "duplicate evidence use identity"))
    (for-each (lambda (use) (hash-put! use-by-id (.ref use 'identity) use))
              uses)
    (let* ((assessments
            (order (map (lambda (item) (replay-assessment item use-by-id))
                        assessments)))
           (all-ids (append (ids retrievals) (ids uses)
                            (ids assessments) (ids dependencies))))
      (unless (unique? all-ids)
        (error "duplicate evidence relation identity"))
      (for-each
       (lambda (relation)
         (let* ((evidence (.ref relation 'evidence-identity))
                (source (.ref relation 'source-digest))
                (previous (hash-get source-by-evidence evidence)))
           (when (and previous (not (equal? previous source)))
             (error "one evidence identity has conflicting source digests"))
           (hash-put! source-by-evidence evidence source)))
       (append retrievals uses))
      (for-each
       (lambda (use)
         (let* ((claim (.ref use 'claim-identity))
                (claim-digest (.ref use 'claim-digest))
                (previous (hash-get claim-by-id claim)))
           (when (and previous (not (equal? previous claim-digest)))
             (error "one claim identity has conflicting claim digests"))
           (hash-put! claim-by-id claim claim-digest)))
       uses)
      (agentic-ai-lab-evidence-lineage-value
       id (digest (list 'poo-flow.evidence-lineage.v2 id
                        (map (lambda (item) (.ref item 'semantic-digest)) retrievals)
                        (map (lambda (item) (.ref item 'semantic-digest)) uses)
                        (map (lambda (item) (.ref item 'semantic-digest))
                             assessments)
                        (map (lambda (item) (.ref item 'semantic-digest))
                             dependencies)))
       retrievals uses assessments dependencies))))

(def (replay-lineage lineage)
  (unless (agentic-ai-lab-evidence-lineage? lineage)
    (error "invalid evidence lineage object"))
  (let (replayed
        (agentic-ai-lab-evidence-lineage
         (.ref lineage 'identity) (.ref lineage 'retrievals)
         (.ref lineage 'uses) (.ref lineage 'assessments)
         (.ref lineage 'dependencies)))
    (unless (equal? (.ref lineage 'semantic-digest)
                    (.ref replayed 'semantic-digest))
      (error "evidence lineage digest mismatch"))
    replayed))

(def (assessment-class verdicts)
  (cond ((null? verdicts) 'unreviewed)
        ((and (member 'supports verdicts) (member 'refutes verdicts))
         'contested)
        ((member 'uncertain verdicts) 'uncertain)
        ((member 'refutes verdicts) 'refuted)
        (else 'supported)))

(def (agentic-ai-lab-evidence-use-audit id lineage)
  (unless (text? id) (error "invalid evidence use audit identity"))
  (let* ((lineage (replay-lineage lineage))
         (retrieved (delete-duplicates/hash
                     (map (lambda (item) (.ref item 'evidence-identity))
                          (.ref lineage 'retrievals))))
         (used (delete-duplicates/hash
                (map (lambda (item) (.ref item 'evidence-identity))
                     (.ref lineage 'uses))))
         (unused (sorted (filter (lambda (name) (not (member name used)))
                                 retrieved)))
         (unretrieved (sorted (filter (lambda (name)
                                       (not (member name retrieved))) used)))
         (verdicts (make-hash-table))
         (_ (for-each
             (lambda (item)
               (let (use-id (.ref item 'use-identity))
                 (hash-put! verdicts use-id
                            (cons (.ref item 'verdict)
                                  (or (hash-get verdicts use-id) '())))))
             (.ref lineage 'assessments)))
         (classified
          (map (lambda (use)
                 (cons (.ref use 'identity)
                       (assessment-class
                        (or (hash-get verdicts (.ref use 'identity)) '()))))
               (.ref lineage 'uses)))
         (by-class
          (lambda (class)
            (map car (filter (lambda (row) (eq? (cdr row) class))
                             classified))))
         (unreviewed (by-class 'unreviewed))
         (supported (by-class 'supported))
         (refuted (by-class 'refuted))
         (uncertain (by-class 'uncertain))
         (contested (by-class 'contested))
         (status (if (or (pair? unretrieved)
                         (pair? unreviewed) (pair? refuted)
                         (pair? uncertain) (pair? contested))
                   'needs-review 'declared-reviewed))
         (semantic
          (digest (list 'poo-flow.evidence-use-audit.v2 id
                        (.ref lineage 'semantic-digest)
                        unused unretrieved unreviewed supported refuted
                        uncertain contested status))))
    (agentic-ai-lab-evidence-use-audit-value
     id semantic (.ref lineage 'semantic-digest)
     unused unretrieved unreviewed supported refuted uncertain contested
     status)))

(def (agentic-ai-lab-evidence-impact-frontier id lineage seed-evidence)
  (unless (and (text? id) (texts? seed-evidence) (pair? seed-evidence)
               (unique? seed-evidence))
    (error "invalid evidence impact seed"))
  (let* ((lineage (replay-lineage lineage))
         (seeds (sorted seed-evidence))
         (known (append
                 (map (lambda (item) (.ref item 'evidence-identity))
                      (.ref lineage 'retrievals))
                 (map (lambda (item) (.ref item 'evidence-identity))
                      (.ref lineage 'uses))))
         (direct
          (map (lambda (item) (.ref item 'claim-identity))
               (filter (lambda (item)
                         (member (.ref item 'evidence-identity) seeds))
                       (.ref lineage 'uses))))
         (reverse (make-hash-table))
         (visited (make-hash-table)))
    (unless (every (lambda (seed) (member seed known)) seeds)
      (error "unknown evidence impact seed"))
    (for-each
     (lambda (edge)
       (let (source (.ref edge 'source-claim-identity))
         (hash-put! reverse source
                    (cons (.ref edge 'dependent-claim-identity)
                          (or (hash-get reverse source) '())))))
     (.ref lineage 'dependencies))
    (let loop ((pending direct))
      (unless (null? pending)
        (let (current (car pending))
          (if (hash-get visited current)
            (loop (cdr pending))
            (begin
              (hash-put! visited current #t)
              (loop (append (cdr pending)
                            (or (hash-get reverse current) '()))))))))
    (let* ((claims
            (sorted (delete-duplicates/hash
                     (filter (lambda (claim) (hash-get visited claim))
                             (append direct
                                     (map (lambda (edge)
                                            (.ref edge 'dependent-claim-identity))
                                          (.ref lineage 'dependencies)))))))
           (semantic
            (digest (list 'poo-flow.evidence-impact-frontier.v1 id
                          (.ref lineage 'semantic-digest) seeds claims))))
      (agentic-ai-lab-evidence-impact-frontier-value
       id semantic (.ref lineage 'semantic-digest) seeds claims))))
