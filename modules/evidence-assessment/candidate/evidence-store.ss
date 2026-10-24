;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Read-through storage of computational evidence. Source authority stays with
;;; the caller. Private receipts never escape; all published pair trees detach.
(import (only-in :clan/poo/object .o .ref object? .slot?)
        (only-in :clan/poo/mop define-type validate)
        (only-in :yuanxu/object-types/contracts YuanxuObjectContract. yuanxu-predicate-contract)
        (only-in :std/error exception->string)
        (only-in :gerbil-ascent/candidate/datum reasoning-bounded-data?)
        (only-in :gerbil-ascent/candidate/types reasoning-snapshot-valid? reasoning-snapshot-relations)
        (only-in :gerbil-ascent/candidate/program candidate-inspect scalar?)
        (only-in :gerbil-ascent/candidate/funs candidate-bind-atom)
        (only-in :gerbil-ascent/candidate/checked-program
                 candidate-content-digest reasoning-source-snapshot reasoning-attempt
                 reasoning-receipt-bound? reasoning-verify-finite-receipt
                 reasoning-snapshot-identity reasoning-snapshot-generation reasoning-snapshot-digest
                 reasoning-receipt-status reasoning-receipt-rows reasoning-receipt-query
                 reasoning-receipt-candidate-digest reasoning-receipt-proof
                 reasoning-receipt-stratified reasoning-stratified-evidence-finite)
        (only-in :gerbil-ascent/candidate/provenance candidate-verify-positive-proof positive-proof? positive-proof-status positive-proof-nodes positive-proof-roots
                 proof-node-id proof-node-kind proof-node-relation proof-node-row proof-node-label proof-node-inputs)
        (only-in :gerbil-ascent/candidate/finite-evidence finite-evidence-closure))
(export reasoning-open-evidence-store reasoning-resolve-evidence reasoning-evidence-claim
        reasoning-evidence-fact reasoning-evidence-fragment
        reasoning-evidence-certificate reasoning-evidence-store-stats reasoning-evidence-store-clear!
        reasoning-evidence-partition AgenticAILabComputationalEvidenceStoreContract)

;;; The entry is private. The POO owner is the public procedure protocol.
(defstruct evidence-entry (snapshot candidate receipt handle) final: #t)
(def (evidence-operations? owner)
  (and (object? owner)
       (andmap (lambda (slot) (and (.slot? owner slot) (procedure? (.ref owner slot))))
               '(.resolve .claim .fact .fragment .certificate .partition .stats .clear))))
(define-type (AgenticAILabComputationalEvidenceStoreContract @ YuanxuObjectContract.)
  identity: 'agentic-ai-lab/computational-evidence-store
  proto: (.o)
  responsibilities:
  (.o .operations: (yuanxu-predicate-contract 'ascent/evidence-operations
                    evidence-operations? (lambda (_v _c) []))))

(def (detached value)
  (cond ((pair? value) (cons (detached (car value)) (detached (cdr value))))
        ((string? value) (string-copy value))
        (else value)))
(def (scope-key snapshot candidate)
  (and (reasoning-snapshot-valid? snapshot)
       (let (digest (candidate-content-digest candidate))
         (and digest (list (reasoning-snapshot-identity snapshot)
                           (reasoning-snapshot-generation snapshot)
                           (reasoning-snapshot-digest snapshot) digest)))))
(def (scope-description entry)
  (let ((snapshot (evidence-entry-snapshot entry)) (receipt (evidence-entry-receipt entry)))
    (list (list 'source-identity (reasoning-snapshot-identity snapshot))
          (list 'generation (reasoning-snapshot-generation snapshot))
          (list 'source-digest (reasoning-snapshot-digest snapshot))
          (list 'candidate-digest (reasoning-receipt-candidate-digest receipt))
          (list 'query (reasoning-receipt-query receipt)))))
(def (describe-entry entry reused?)
  (detached (list (list 'status 'verified) (list 'finite-complete #t)
                 (list 'handle (evidence-entry-handle entry)) (list 'reused reused?)
                 (list 'scope (scope-description entry))
                 (list 'rows (reasoning-receipt-rows (evidence-entry-receipt entry))))))
(def (unknown reason)
  (list (list 'status 'unknown) (list 'reason reason)))

;;; One bounded serialized owner. Budgets are part of its contract, not hints
;;; to a model. Failed/bounded attempts are not cached as negative evidence.
(def (reasoning-open-evidence-store (max-entries 64) (proof-steps 100000) (work-steps 100000))
  (unless (andmap (lambda (v) (and (exact-integer? v) (> v 0)))
                  (list max-entries proof-steps work-steps))
    (error "evidence store requires positive bounds"))
  (let ((entries (make-hash-table)) (handles (make-hash-table)) (order [])
        (serial 0) (builds 0) (hits 0) (attempts 0) (evictions 0)
        (gate (make-mutex 'ascent-evidence-owner)))
    (def (serialized call)
      (when (eq? (mutex-state gate) (current-thread)) (error "reentrant evidence owner call"))
      (with-dynamic-lock gate call))
    (def (bound-entry snapshot candidate handle)
      (let (entry (and (exact-integer? handle) (hash-get handles handle)))
        (and entry (reasoning-receipt-bound? (evidence-entry-receipt entry) snapshot candidate) entry)))
    (def (resolve snapshot candidate)
      (let* ((key (scope-key snapshot candidate)) (entry (and key (hash-get entries key))))
        (cond
         ((not key) (unknown 'invalid-scope))
         ((and entry (reasoning-receipt-bound? (evidence-entry-receipt entry) snapshot candidate))
          (set! hits (+ hits 1)) (describe-entry entry #t))
         (else
          (set! attempts (+ attempts 1))
          (try
            (let* ((owned-source (reasoning-source-snapshot
                                  (detached (reasoning-snapshot-identity snapshot))
                                  (reasoning-snapshot-generation snapshot)
                                  (reasoning-snapshot-relations snapshot)))
                   (owned-candidate (detached candidate))
                   (receipt (reasoning-attempt owned-source owned-candidate proof-steps work-steps))
                   (rows (reasoning-receipt-rows receipt)))
              (if (and (reasoning-receipt-bound? receipt snapshot candidate)
                       (eq? (reasoning-receipt-status receipt) 'complete)
                       (positive-proof? (reasoning-receipt-proof receipt))
                       (or (null? rows)
                           (candidate-verify-positive-proof owned-source
                             (candidate-inspect owned-source owned-candidate)
                             (reasoning-receipt-candidate-digest receipt) 'complete rows
                             (reasoning-receipt-proof receipt) proof-steps))
                       (eq? (reasoning-verify-finite-receipt receipt owned-source owned-candidate work-steps) 'valid))
                (begin
                  (when (>= (hash-length entries) max-entries)
                    (let (old (hash-ref entries (car order)))
                      (hash-remove! handles (evidence-entry-handle old))
                      (hash-remove! entries (car order)))
                    (set! order (cdr order)) (set! evictions (+ evictions 1)))
                  (set! serial (+ serial 1)) (set! builds (+ builds 1))
                  (let (admitted (make-evidence-entry owned-source owned-candidate receipt serial))
                    (hash-put! entries (detached key) admitted) (hash-put! handles serial admitted)
                    (set! order (append order (list (detached key))))
                    (describe-entry admitted #f)))
                (unknown 'unverified-receipt)))
            (catch (e) (unknown (exception->string e))))))))
    (def (claim snapshot candidate handle row)
      (let (entry (bound-entry snapshot candidate handle))
        (cond
         ((not entry) (unknown 'stale-or-unknown-handle))
         ((not (and (reasoning-bounded-data? row 16384 128) (list? row)
                    (= (length row) (length (cdr (reasoning-receipt-query (evidence-entry-receipt entry)))))
                    (andmap scalar? row)
                    (candidate-bind-atom (reasoning-receipt-query (evidence-entry-receipt entry)) row [])))
          (unknown 'invalid-query-row))
         (else
          (let (present (and (member row (reasoning-receipt-rows (evidence-entry-receipt entry))) #t))
            (detached (list (list 'status (if present 'verified 'finite-absent))
                            (list 'present present) (list 'row row) (list 'handle handle)
                            (list 'scope (scope-description entry)))))))))
    (def (certificate snapshot candidate handle)
      (let (entry (bound-entry snapshot candidate handle))
        (if (not entry) (unknown 'stale-or-unknown-handle)
          (let* ((receipt (evidence-entry-receipt entry)) (proof (reasoning-receipt-proof receipt)))
            (detached
             (list (list 'status 'verified) (list 'handle handle) (list 'scope (scope-description entry))
                   (list 'finite-closure (finite-evidence-closure
                                          (reasoning-stratified-evidence-finite (reasoning-receipt-stratified receipt))))
                   (list 'positive-proof-status (positive-proof-status proof))
                   (list 'roots (positive-proof-roots proof))
                   (list 'nodes (map (lambda (n)
                                      (list (proof-node-id n) (proof-node-kind n) (proof-node-relation n)
                                            (proof-node-row n) (proof-node-label n) (proof-node-inputs n)))
                                    (positive-proof-nodes proof)))))))))
    (def (fact snapshot candidate handle atom)
      (let (entry (bound-entry snapshot candidate handle))
        (cond
         ((not entry) (unknown 'stale-or-unknown-handle))
         ((not (and (reasoning-bounded-data? atom 16384 128) (list? atom) (pair? atom)
                    (symbol? (car atom)) (andmap scalar? (cdr atom)))) (unknown 'invalid-atom))
         (else
          (let* ((receipt (evidence-entry-receipt entry))
                 (closure (finite-evidence-closure (reasoning-stratified-evidence-finite
                                                    (reasoning-receipt-stratified receipt))))
                 (relation (assq (car atom) closure)))
            (if (not (and relation (= (length (cdr atom)) (cadr relation))))
              (unknown 'unknown-relation-or-arity)
              (let* ((present (and (member (cdr atom) (caddr relation)) #t))
                     (support (filter (lambda (node)
                                        (and (eq? (proof-node-relation node) (car atom))
                                             (equal? (proof-node-row node) (cdr atom))))
                                      (positive-proof-nodes (reasoning-receipt-proof receipt)))))
                (detached (list (list 'status (if present 'verified 'finite-absent))
                                (list 'present present) (list 'atom atom) (list 'handle handle)
                                (list 'basis 'verified-finite-closure)
                                (list 'support-nodes (map proof-node-id support))
                                (list 'scope (scope-description entry)))))))))))
    ;; Publish only the ancestor-closed computational support of one Fact.
    ;; Identity and generation admission is identical to .fact; the private
    ;; receipt and checker do not escape, and no workflow decision is made.
    (def (fragment snapshot candidate handle atom)
      (let (answer (fact snapshot candidate handle atom))
        (if (not (eq? (cadr (assq 'status answer)) 'verified)) answer
          (let* ((proof (certificate snapshot candidate handle))
                 (nodes (cadr (assq 'nodes proof)))
                 (roots (cadr (assq 'support-nodes answer)))
                 (seen []) (selected []))
            (def (visit id)
              (unless (member id seen)
                (let (node (assoc id nodes))
                  (unless node (error "verified proof has missing support" id))
                  (set! seen (cons id seen))
                  (for-each visit (list-ref node 5))
                  (set! selected (cons node selected)))))
            (for-each visit roots)
            (detached (list (list 'status 'verified) (list 'fact answer)
                            (list 'roots roots) (list 'nodes (reverse selected))))))))
    (validate AgenticAILabComputationalEvidenceStoreContract
      (.o (:: @ (.ref AgenticAILabComputationalEvidenceStoreContract 'proto))
          .operations:
          (.o .resolve: (lambda (snapshot candidate) (serialized (lambda () (resolve snapshot candidate))))
          .claim: (lambda (snapshot candidate handle row) (serialized (lambda () (claim snapshot candidate handle row))))
          .fact: (lambda (snapshot candidate handle atom) (serialized (lambda () (fact snapshot candidate handle atom))))
          .fragment: (lambda (snapshot candidate handle atom) (serialized (lambda () (fragment snapshot candidate handle atom))))
          .certificate: (lambda (snapshot candidate handle) (serialized (lambda () (certificate snapshot candidate handle))))
          .partition: (lambda (snapshot candidate handle alternatives)
                        (serialized (lambda () (partition-obligations
                          (lambda (atom) (fact snapshot candidate handle atom)) alternatives))))
          .stats: (lambda () (serialized (lambda ()
                    (list (list 'entries (hash-length entries)) (list 'attempts attempts)
                          (list 'proof-builds builds) (list 'hits hits) (list 'evictions evictions)))))
          .clear: (lambda () (serialized (lambda ()
                    (set! entries (make-hash-table)) (set! handles (make-hash-table))
                    (set! order []) #t))))))))

(def (operation store name) (.ref (.ref store '.operations) name))
(def (reasoning-resolve-evidence store snapshot candidate) ((operation store '.resolve) snapshot candidate))
(def (reasoning-evidence-claim store snapshot candidate handle row) ((operation store '.claim) snapshot candidate handle row))
(def (reasoning-evidence-fact store snapshot candidate handle atom) ((operation store '.fact) snapshot candidate handle atom))
(def (reasoning-evidence-fragment store snapshot candidate handle atom) ((operation store '.fragment) snapshot candidate handle atom))
(def (reasoning-evidence-certificate store snapshot candidate handle) ((operation store '.certificate) snapshot candidate handle))
(def (reasoning-evidence-store-stats store) ((operation store '.stats)))
(def (reasoning-evidence-store-clear! store) ((operation store '.clear)))
(def (reasoning-evidence-partition store snapshot candidate handle alternatives)
  ((operation store '.partition) snapshot candidate handle alternatives))

;;; An alternative is (caller-id required-ground-atoms). Only verified finite
;;; absence prunes. Unknown, stale and out-of-query obligations remain open.
;;; This does not rank alternatives, evaluate their value, or expose an optimum.
(def (partition-obligations fact alternatives)
  (unless (and (reasoning-bounded-data? alternatives 16384 128) (list? alternatives)
               (andmap (lambda (a) (and (list? a) (= (length a) 2) (scalar? (car a)) (list? (cadr a)))) alternatives))
    (error "invalid branch obligations"))
  (let ((seen []) (eligible []) (pruned []) (unresolved []) (allowed []) (claims []))
    (for-each
     (lambda (alternative)
       (let* ((id (car alternative))
              (answers (map fact (cadr alternative)))
              (statuses (map (lambda (answer) (cadr (assq 'status answer))) answers)))
         (when (member id seen) (error "duplicate branch ID" id))
         (set! seen (cons id seen)) (set! claims (cons (list id answers) claims))
         (cond
          ((memq 'finite-absent statuses) (set! pruned (cons id pruned)))
          ((memq 'unknown statuses)
           (set! unresolved (cons id unresolved)) (set! allowed (cons id allowed)))
          (else (set! eligible (cons id eligible)) (set! allowed (cons id allowed)))))) alternatives)
    (list (list 'eligible (reverse eligible)) (list 'pruned (reverse pruned))
          (list 'unresolved (reverse unresolved)) (list 'allowed (reverse allowed))
          (list 'claims (reverse claims)))))
