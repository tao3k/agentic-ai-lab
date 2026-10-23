;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Named owner adapter. No general wire reader, proof solver or effect permit.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. validate)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :gerbil-ascent/candidate/datum candidate-copy-pairs reasoning-bounded-data?)
        (only-in :gerbil-ascent/candidate/types
                 reasoning-snapshot-valid? reasoning-snapshot-relations
                 reasoning-candidate-facts reasoning-candidate-rules reasoning-candidate-relations
                 reasoning-candidate-limits)
        (only-in :gerbil-ascent/candidate/program candidate-inspect)
        (only-in :gerbil-ascent/candidate/funs candidate-same-row-set?)
        (only-in :gerbil-ascent/candidate/checked-program
                 reasoning-source-snapshot reasoning-attempt reasoning-receipt?
                 reasoning-snapshot-identity reasoning-snapshot-generation reasoning-snapshot-digest
                 reasoning-receipt-bound? reasoning-receipt-status reasoning-receipt-rows
                 reasoning-receipt-candidate-digest reasoning-receipt-proof)
        (only-in :gerbil-ascent/candidate/provenance
                 candidate-verify-positive-proof positive-proof? positive-proof-status
                 positive-proof-query positive-proof-work-budget positive-proof-roots positive-proof-nodes
                 proof-node-id proof-node-kind proof-node-relation proof-node-row proof-node-label proof-node-inputs))
(export AgenticAILabTemporalPositiveProof
        agentic-ai-lab-temporal-positive-proof-from-ascent
        agentic-ai-lab-temporal-positive-proof-replay)
(def (text? x) (and (string? x) (< 0 (string-length x) 257)))
(def (digest x) (string-append "sha256:" (hex-encode (sha256 (string->utf8
  (call-with-output-string (lambda (p) (write x p))))))))
(def required '(identity evaluator-identity semantic-digest snapshot-identity snapshot-generation
                         snapshot-digest candidate-digest query rows proof-digest node-count
                         proof-admitted? source-authenticated? selection-admitted? action-authorized? durable?))
(define-type (AgenticAILabTemporalPositiveProof @ Type.)
  .element?: (lambda (v)
    (and (object? v) (.slot? v 'kind) (eq? (.ref v 'kind) 'agentic-ai-lab.temporal-causality.positive-proof.v1)
         (andmap (lambda (s) (.slot? v s)) required))))
(def (node-row n)
  (list (proof-node-id n) (proof-node-kind n) (proof-node-relation n)
        (proof-node-row n) (proof-node-label n) (proof-node-inputs n)))
(def (agentic-ai-lab-temporal-positive-proof-from-ascent id-value snapshot candidate receipt work-steps max-nodes)
  (unless (and (text? id-value) (reasoning-snapshot-valid? snapshot)
               (reasoning-receipt? receipt)
               (exact-integer? work-steps) (<= 1 work-steps 4096)
               (exact-integer? max-nodes) (<= 1 max-nodes 128)
               (reasoning-bounded-data? candidate 16384 128))
    (error "invalid evaluator proof adapter input"))
  (unless (and (reasoning-receipt-bound? receipt snapshot candidate)
               (eq? (reasoning-receipt-status receipt) 'complete))
    (error "stale or incomplete evaluator receipt"))
  (let* ((source (reasoning-source-snapshot (reasoning-snapshot-identity snapshot)
                   (reasoning-snapshot-generation snapshot) (reasoning-snapshot-relations snapshot)))
         (owned-candidate (candidate-copy-pairs candidate))
         (spec (candidate-inspect source owned-candidate))
         (proof (reasoning-receipt-proof receipt)))
    (unless (and (<= (length (reasoning-snapshot-relations source)) 32)
                 (<= (apply + (map (lambda (r) (length (caddr r))) (reasoning-snapshot-relations source))) 128)
                 (<= (length (reasoning-candidate-relations spec)) 32)
                 (<= (length (reasoning-candidate-rules spec)) 32)
                 (null? (reasoning-candidate-facts spec))
                 (andmap (lambda (n) (<= n 128)) (reasoning-candidate-limits spec))
                 (positive-proof? proof) (eq? (positive-proof-status proof) 'complete)
                 (pair? (positive-proof-roots proof))
                 (<= (length (positive-proof-nodes proof)) max-nodes)
                 (andmap (lambda (n) (not (eq? (proof-node-kind n) 'candidate))) (positive-proof-nodes proof)))
      (error "proof profile requires bounded source-only positive evidence"))
    ;; Recompute the native query once; never trust caller-supplied completion/rows.
    (let* ((fresh (reasoning-attempt source owned-candidate work-steps))
           (rows-value (reasoning-receipt-rows fresh))
           (candidate-digest-value (reasoning-receipt-candidate-digest fresh)))
      (unless (and (eq? (reasoning-receipt-status fresh) 'complete)
                   (positive-proof? (reasoning-receipt-proof fresh))
                   (eq? (positive-proof-status (reasoning-receipt-proof fresh)) 'complete)
                   (candidate-same-row-set? rows-value (reasoning-receipt-rows receipt))
                   (candidate-verify-positive-proof source spec candidate-digest-value
                     (reasoning-receipt-status fresh) rows-value proof max-nodes))
        (error "native query or original evaluator proof replay rejected"))
      (let* ((query-value (candidate-copy-pairs (positive-proof-query proof)))
             (proof-data (candidate-copy-pairs
               (list (positive-proof-work-budget proof) (map node-row (positive-proof-nodes proof))
                     (positive-proof-roots proof))))
             (proof-digest-value (digest (list 'ascent-positive-proof.v1 proof-data)))
             (snapshot-id-value (reasoning-snapshot-identity source))
             (snapshot-generation-value (reasoning-snapshot-generation source))
             (snapshot-digest-value (reasoning-snapshot-digest source))
             (owned-rows (list-sort
               (lambda (a b) (string<? (call-with-output-string (lambda (p) (write a p)))
                                       (call-with-output-string (lambda (p) (write b p)))))
               (candidate-copy-pairs rows-value)))
             (fingerprint (digest (list 'agentic-ai-lab.temporal-positive-proof.v1 id-value
               snapshot-id-value snapshot-generation-value snapshot-digest-value candidate-digest-value
               query-value owned-rows proof-digest-value work-steps max-nodes))))
        (validate AgenticAILabTemporalPositiveProof
          (.o kind: 'agentic-ai-lab.temporal-causality.positive-proof.v1 identity: id-value
              evaluator-identity: 'ascent-positive-v1 semantic-digest: fingerprint
              snapshot-identity: snapshot-id-value snapshot-generation: snapshot-generation-value
              snapshot-digest: snapshot-digest-value candidate-digest: candidate-digest-value
              query: query-value rows: owned-rows proof-digest: proof-digest-value
              node-count: (length (positive-proof-nodes proof))
              proof-admitted?: #t source-authenticated?: #f selection-admitted?: #f
              action-authorized?: #f durable?: #f))))))
(def (agentic-ai-lab-temporal-positive-proof-replay admission snapshot candidate receipt work-steps max-nodes)
  (unless (and (object? admission) (.slot? admission 'kind)
               (eq? (.ref admission 'kind) 'agentic-ai-lab.temporal-causality.positive-proof.v1)
               (.ref admission 'proof-admitted?) (not (.ref admission 'source-authenticated?))
               (not (.ref admission 'selection-admitted?)) (not (.ref admission 'action-authorized?))
               (not (.ref admission 'durable?)))
    (error "invalid positive proof admission"))
  (let (canonical (agentic-ai-lab-temporal-positive-proof-from-ascent (.ref admission 'identity)
                    snapshot candidate receipt work-steps max-nodes))
    (unless (andmap (lambda (s) (equal? (.ref canonical s) (.ref admission s))) required)
      (error "positive proof admission replay mismatch")) canonical))
