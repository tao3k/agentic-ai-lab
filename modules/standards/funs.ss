;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: pure Standard lookup, dependency closure and validation-closure construction.
;;; Invariant: these functions never load artifact bodies or invoke a Provider.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :std/crypto/digest sha256)
        (only-in :std/list/list filter)
        (only-in :std/encoding/hex hex-encode)
        (only-in :yuanxu/utilities/functional
                 yuanxu-all? yuanxu-map)
        "types.ss"
        "objects.ss"
        "resolution-objects.ss")

(export agentic-ai-lab-standard-digest
        agentic-ai-lab-standard-catalog-find-edition
        agentic-ai-lab-standard-catalog-find-artifact
        agentic-ai-lab-standard-catalog-observe
        agentic-ai-lab-standard-resolve
        agentic-ai-lab-standard-compose-profiles
        agentic-ai-lab-standard-make-validation-closure
        agentic-ai-lab-standard-make-validation-closure-receipt
        agentic-ai-lab-standard-admit-case
        agentic-ai-lab-standard-make-reference-observation
        agentic-ai-lab-standard-compare-reference-observation)

(def (agentic-ai-lab-standard-digest value)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string
       (lambda (port) (write value port))))))))

(def (agentic-ai-lab-standard-catalog-find-edition catalog identity)
  (hash-get (.ref catalog 'edition-index) identity))

(def (agentic-ai-lab-standard-catalog-find-artifact catalog identity)
  (hash-get (.ref catalog 'artifact-index) identity))

(def (agentic-ai-lab-standard-catalog-observe catalog)
  (unless (agentic-ai-lab-standard-catalog? catalog)
    (error "invalid Standard catalog" catalog))
  (agentic-ai-lab-standard-catalog-receipt catalog))

(def (standard-resolution-failure code subject detail path)
  (agentic-ai-lab-standard-failure code subject detail path))

(def (standard-budget-exceeded subject budget-name actual limit path)
  (standard-resolution-failure
   'standard-budget-exceeded subject
   (list (cons 'budget budget-name)
         (cons 'actual actual)
         (cons 'limit limit))
   path))

(def (standard-resolution-bundle-digest editions artifacts terminology-digest)
  (agentic-ai-lab-standard-digest
   (list
    'agentic-ai-lab.standard-bundle.v1
    (yuanxu-map
     (lambda (edition)
       (list (.ref edition 'identity)
             (.ref edition 'canonical-uri)
             (.ref edition 'version)
             (.ref edition 'digest)))
     editions)
    (yuanxu-map
     (lambda (artifact)
       (list (.ref artifact 'identity) (.ref artifact 'digest)))
     artifacts)
    terminology-digest)))

;;; `agentic-ai-lab-standard-catalog` recursively admits every edition and constructs
;;; these immutable indexes. Repeating the full member-shape traversal for each
;;; Case selection is redundant; resolution checks the admitted catalog shell
;;; and then reads only indexed members from it.
(def (standard-resolution-catalog? value)
  (and (object? value)
       (.slot? value 'kind)
       (eq? (.ref value 'kind) +agentic-ai-lab-standard-catalog-kind+)
       (.slot? value 'edition-index)
       (hash-table? (.ref value 'edition-index))
       (.slot? value 'canonical-version-index)
       (hash-table? (.ref value 'canonical-version-index))
       (.slot? value 'artifact-index)
       (hash-table? (.ref value 'artifact-index))
       (.slot? value 'edition-count)
       (integer? (.ref value 'edition-count))
       (>= (.ref value 'edition-count) 0)))

(def (agentic-ai-lab-standard-resolve catalog root-identities budget
                                terminology-snapshot-digest)
  (unless (and (standard-resolution-catalog? catalog)
               (pair? root-identities)
               (yuanxu-all? agentic-ai-lab-standard-text? root-identities)
               (agentic-ai-lab-standard-budget? budget)
               (agentic-ai-lab-standard-digest? terminology-snapshot-digest))
    (error "invalid Standard resolution request"
           catalog root-identities budget terminology-snapshot-digest))
  (let ((edition-index (.ref catalog 'edition-index))
        (canonical-version-index (.ref catalog 'canonical-version-index))
        (artifact-index (.ref catalog 'artifact-index))
        (max-editions (.ref budget 'max-editions))
        (max-artifacts (.ref budget 'max-artifacts))
        (max-depth-limit (.ref budget 'max-depth))
        (max-bytes (.ref budget 'max-bytes))
        (max-operations (.ref budget 'max-operations))
        (edition-states (make-hash-table))
        (artifact-states (make-hash-table))
        (canonical-versions (make-hash-table))
        (editions-rev '())
        (artifacts-rev '())
        (failure #f)
        (edition-count 0)
        (artifact-count 0)
        (byte-count 0)
        (maximum-depth 0)
        (operation-count 0))
    (def (fail! value)
      (unless failure (set! failure value)))
    (def (observe-depth! depth subject path)
      (set! maximum-depth (max maximum-depth depth))
      (when (> depth max-depth-limit)
        (fail! (standard-budget-exceeded
                subject 'max-depth depth max-depth-limit path))))
    (def (consume-operation! subject path)
      (set! operation-count (+ operation-count 1))
      (when (> operation-count max-operations)
        (fail! (standard-budget-exceeded
                subject 'max-operations operation-count
                max-operations path))))
    (def (visit-edition identity path depth)
      (unless failure
        (consume-operation! identity path)
        (observe-depth! depth identity path)
        (let ((state (hash-get edition-states identity)))
          (cond
           ((eq? state 'visited) (void))
           ((eq? state 'visiting)
            (fail! (standard-resolution-failure
                    'standard-dependency-cycle identity path
                    (reverse (cons identity path)))))
           (else
            (let (edition (hash-get edition-index identity))
              (cond
               ((not edition)
                (fail! (standard-resolution-failure
                        'standard-dependency-missing identity
                        "exact Standard edition was absent from the catalog"
                        (reverse (cons identity path)))))
               (else
                (let ((status (.ref edition 'status)))
                  (if (memq status '(withdrawn revoked expired))
                    (fail! (standard-resolution-failure
                            'standard-receipt-revoked identity status
                            (reverse (cons identity path))))
                    (let* ((digest (.ref edition 'digest))
                           (dependencies (.ref edition 'dependencies))
                           (canonical-version
                            (hash-get canonical-version-index identity))
                           (accepted-digest
                            (hash-get canonical-versions canonical-version)))
                      (if (and accepted-digest
                               (not (string=? accepted-digest digest)))
                        (fail! (standard-resolution-failure
                                'standard-identity-conflict identity
                                (list accepted-digest digest)
                                (reverse (cons identity path))))
                        (begin
                          (hash-put! canonical-versions canonical-version digest)
                          (hash-put! edition-states identity 'visiting)
                          (for-each
                           (lambda (dependency)
                             (visit-edition
                              dependency (cons identity path) (+ depth 1)))
                           dependencies)
                          (unless failure
                            (hash-put! edition-states identity 'visited)
                            (set! editions-rev (cons edition editions-rev))
                            (set! edition-count (+ edition-count 1))
                            (when (> edition-count max-editions)
                              (fail! (standard-budget-exceeded
                                      identity 'max-editions edition-count
                                      max-editions
                                      (reverse
                                       (cons identity path)))))))))))))))))))
    (def (visit-artifact identity path depth)
      (unless failure
        (consume-operation! identity path)
        (observe-depth! depth identity path)
        (let ((state (hash-get artifact-states identity)))
          (cond
           ((eq? state 'visited) (void))
           ((eq? state 'visiting)
            (fail! (standard-resolution-failure
                    'standard-dependency-cycle identity
                    "artifact dependency cycle"
                    (reverse (cons identity path)))))
           (else
            (let (artifact (hash-get artifact-index identity))
              (if (not artifact)
                (fail! (standard-resolution-failure
                        'standard-dependency-missing identity
                        "Standard artifact was absent from the selected catalog"
                        (reverse (cons identity path))))
                (let ((dependencies (.ref artifact 'dependencies))
                      (size-bytes (.ref artifact 'size-bytes)))
                  (hash-put! artifact-states identity 'visiting)
                  (for-each
                   (lambda (dependency)
                     (visit-artifact
                      dependency (cons identity path) (+ depth 1)))
                   dependencies)
                  (unless failure
                    (hash-put! artifact-states identity 'visited)
                    (set! artifacts-rev (cons artifact artifacts-rev))
                    (set! artifact-count (+ artifact-count 1))
                    (set! byte-count (+ byte-count size-bytes))
                    (when (> artifact-count max-artifacts)
                      (fail! (standard-budget-exceeded
                              identity 'max-artifacts artifact-count
                              max-artifacts (reverse (cons identity path)))))
                    (when (> byte-count max-bytes)
                      (fail! (standard-budget-exceeded
                              identity 'max-bytes byte-count max-bytes
                              (reverse (cons identity path))))))))))))))
    (for-each (lambda (identity) (visit-edition identity '() 1)) root-identities)
    (unless failure
      (for-each
       (lambda (edition)
         (for-each
          (lambda (artifact-identity)
            (visit-artifact artifact-identity
                            (list (.ref edition 'identity)) 1))
          (.ref edition 'root-artifacts)))
       (reverse editions-rev)))
    (if failure
      (agentic-ai-lab-standard-resolution-receipt
       root-identities #f (list failure))
      (let* ((editions (reverse editions-rev))
             (artifacts (reverse artifacts-rev))
             (closure-digest
              (standard-resolution-bundle-digest
               editions artifacts terminology-snapshot-digest))
             (bundle
              (standard-resolution-admitted-bundle
               catalog root-identities editions edition-count
               artifacts artifact-count terminology-snapshot-digest
               byte-count maximum-depth operation-count closure-digest)))
        (standard-resolution-admitted-receipt root-identities bundle)))))

(def (agentic-ai-lab-standard-compose-profiles
      case-identity profiles catalog budget terminology-snapshot-digest)
  (unless (and (agentic-ai-lab-standard-text? case-identity)
               (pair? profiles)
               (yuanxu-all? agentic-ai-lab-standard-constraint-profile? profiles)
               (agentic-ai-lab-standard-catalog? catalog)
               (agentic-ai-lab-standard-budget? budget)
               (agentic-ai-lab-standard-digest? terminology-snapshot-digest))
    (error "invalid Standard Profile composition request"
           case-identity profiles catalog budget terminology-snapshot-digest))
  (let ((profile-revisions (make-hash-table))
        (selected-profiles-rev '())
        (profile-identities-rev '())
        (base-editions-rev '())
        (constraints-rev '())
        (artifact-dependencies-rev '())
        (terminology-dependencies-rev '())
        (base-editions-seen (make-hash-table))
        (artifact-dependencies-seen (make-hash-table))
        (terminology-dependencies-seen (make-hash-table))
        (profile-failure #f))
    (def (collect-unique! values seen set-reversed!)
      (for-each
       (lambda (value)
         (unless (hash-get seen value)
           (hash-put! seen value #t)
           (set-reversed! value)))
       values))
    (for-each
     (lambda (profile)
       (let* ((identity (.ref profile 'identity))
              (revision (.ref profile 'exact-revision))
              (accepted-revision (hash-get profile-revisions identity)))
         (cond
          ((and accepted-revision
                (not (string=? accepted-revision revision)))
           (unless profile-failure
             (set! profile-failure
                   (agentic-ai-lab-standard-failure
                    'standard-profile-revision-conflict identity
                    (list accepted-revision revision)
                    (list case-identity identity)))))
          ((not accepted-revision)
           (hash-put! profile-revisions identity revision)
           (set! selected-profiles-rev (cons profile selected-profiles-rev))
           (set! profile-identities-rev (cons identity profile-identities-rev))
           (set! constraints-rev
                 (append (reverse (.ref profile 'constraints)) constraints-rev))
           (collect-unique!
            (.ref profile 'base-editions) base-editions-seen
            (lambda (value)
              (set! base-editions-rev (cons value base-editions-rev))))
           (collect-unique!
            (.ref profile 'artifact-dependencies) artifact-dependencies-seen
            (lambda (value)
              (set! artifact-dependencies-rev
                    (cons value artifact-dependencies-rev))))
           (collect-unique!
            (.ref profile 'terminology-dependencies)
            terminology-dependencies-seen
            (lambda (value)
              (set! terminology-dependencies-rev
                    (cons value terminology-dependencies-rev))))))))
     profiles)
    (let* ((selected-profiles (reverse selected-profiles-rev))
           (profile-identities (reverse profile-identities-rev))
           (base-editions (reverse base-editions-rev))
           (constraints (reverse constraints-rev))
           (artifact-dependencies (reverse artifact-dependencies-rev))
           (terminology-dependencies (reverse terminology-dependencies-rev))
           (resolution
            (and (not profile-failure)
                 (agentic-ai-lab-standard-resolve
                  catalog base-editions budget terminology-snapshot-digest)))
           (failures
            (if profile-failure
              (list profile-failure)
              (.ref resolution 'failures)))
           (composition-digest
            (agentic-ai-lab-standard-digest
             (list 'agentic-ai-lab.standard-profile-composition.v1
                   case-identity
                   (map (lambda (profile)
                          (list (.ref profile 'identity)
                                (.ref profile 'exact-revision)))
                        selected-profiles)
                   base-editions
                   (and resolution
                        (.ref resolution 'bundle)
                        (.ref (.ref resolution 'bundle) 'closure-digest))
                   (map (lambda (failure) (.ref failure 'code)) failures)))))
      (agentic-ai-lab-standard-profile-composition-receipt
       case-identity selected-profiles profile-identities base-editions
       constraints artifact-dependencies terminology-dependencies resolution
       failures composition-digest))))

(def (agentic-ai-lab-standard-make-validation-closure
      identity bundle provider-identity subject-kind subject-snapshot-digest
      constraints)
  (unless (and (agentic-ai-lab-standard-bundle? bundle)
               (agentic-ai-lab-standard-text? identity)
               (agentic-ai-lab-standard-text? provider-identity)
               (symbol? subject-kind)
               (agentic-ai-lab-standard-digest? subject-snapshot-digest)
               (list? constraints))
    (error "invalid Standard validation closure input" identity))
  (let (validation-closure-digest
        (agentic-ai-lab-standard-digest
         (list 'agentic-ai-lab.standard-validation-closure.v1
               identity
               (.ref bundle 'closure-digest)
               provider-identity
               subject-kind
               subject-snapshot-digest
               (yuanxu-map
                (lambda (constraint)
                  (if (and (object? constraint) (.slot? constraint 'identity))
                    (.ref constraint 'identity)
                    constraint))
                constraints))))
    (agentic-ai-lab-standard-validation-closure
     identity bundle provider-identity subject-kind subject-snapshot-digest
     constraints validation-closure-digest)))

(def (agentic-ai-lab-standard-make-validation-closure-receipt validation-closure engine-identity engine-version)
  (unless (and (agentic-ai-lab-standard-validation-closure? validation-closure)
               (agentic-ai-lab-standard-text? engine-identity)
               (agentic-ai-lab-standard-text? engine-version))
    (error "invalid Standard validation-closure receipt input" validation-closure))
  (let* ((bundle (.ref validation-closure 'bundle))
         (unsupported-count
          (length
           (filter
            (lambda (constraint)
              (and (object? constraint)
                   (.slot? constraint 'support-state)
                   (eq? (.ref constraint 'support-state) 'unsupported)))
            (.ref validation-closure 'constraints))))
         (generation
          (agentic-ai-lab-standard-digest
           (list 'agentic-ai-lab.standard-validation-closure-generation.v1
                 (.ref bundle 'closure-digest)
                 (.ref bundle 'terminology-snapshot-digest)
                 engine-identity engine-version))))
    (agentic-ai-lab-standard-validation-closure-receipt
     validation-closure (.ref bundle 'closure-digest)
     (.ref bundle 'terminology-snapshot-digest)
     engine-identity engine-version unsupported-count 'compiled generation
     '() #t)))

(def (agentic-ai-lab-standard-admit-case case-identity conformance-receipts
                                   evidence-digests)
  (unless (and (agentic-ai-lab-standard-text? case-identity)
               (yuanxu-all? agentic-ai-lab-standard-conformance-receipt?
                              conformance-receipts)
               (yuanxu-all? agentic-ai-lab-standard-digest? evidence-digests))
    (error "invalid Standard Case admission input" case-identity))
  (let* ((failures
          (apply append
                 (map (lambda (receipt) (.ref receipt 'failures))
                      conformance-receipts)))
         (conformance-digests
          (map (lambda (receipt) (.ref receipt 'conformance-digest))
               conformance-receipts))
         (admission-digest
          (agentic-ai-lab-standard-digest
           (list 'agentic-ai-lab.standard-case-admission.v1 case-identity
                 conformance-digests evidence-digests
                 (map (lambda (failure) (.ref failure 'code)) failures)))))
    (agentic-ai-lab-standard-case-admission-receipt
     case-identity conformance-digests evidence-digests failures
     admission-digest)))

(def (agentic-ai-lab-standard-make-reference-observation
      validator-identity validator-version validator-binary-digest
      fixture-identity subject-snapshot-digest profile-identities outcome issues
      output-digest metadata)
  (unless (and (agentic-ai-lab-standard-text? validator-identity)
               (agentic-ai-lab-standard-text? validator-version)
               (agentic-ai-lab-standard-digest? validator-binary-digest)
               (agentic-ai-lab-standard-text? fixture-identity)
               (agentic-ai-lab-standard-digest? subject-snapshot-digest)
               (yuanxu-all? agentic-ai-lab-standard-text? profile-identities)
               (memq outcome '(valid invalid not-evaluated))
               (yuanxu-all? agentic-ai-lab-standard-text? issues)
               (agentic-ai-lab-standard-digest? output-digest)
               (list? metadata))
    (error "invalid Standard reference observation input" fixture-identity))
  (let (observation-digest
        (agentic-ai-lab-standard-digest
         (list 'agentic-ai-lab.standard-reference-observation.v1
               validator-identity validator-version validator-binary-digest
               fixture-identity subject-snapshot-digest profile-identities
               outcome issues output-digest metadata)))
    (agentic-ai-lab-standard-reference-observation
     validator-identity validator-version validator-binary-digest
     fixture-identity subject-snapshot-digest profile-identities outcome issues
     output-digest observation-digest metadata)))

(def (agentic-ai-lab-standard-compare-reference-observation
      validation-closure conformance-receipt reference-observation)
  (unless (and (agentic-ai-lab-standard-validation-closure? validation-closure)
               (agentic-ai-lab-standard-conformance-receipt? conformance-receipt)
               (agentic-ai-lab-standard-reference-observation?
                reference-observation))
    (error "invalid Standard reference comparison input"))
  (let ((discrepancies-rev '())
        (failures-rev '()))
    (def (disagree! code subject detail)
      (set! discrepancies-rev (cons code discrepancies-rev))
      (set! failures-rev
            (cons (agentic-ai-lab-standard-failure code subject detail '())
                  failures-rev)))
    (unless (string=? (.ref validation-closure 'validation-closure-digest)
                      (.ref conformance-receipt 'validation-closure-digest))
      (disagree! 'standard-comparison-validation-closure-mismatch
                 (.ref validation-closure 'identity)
                 (list (.ref validation-closure 'validation-closure-digest)
                       (.ref conformance-receipt 'validation-closure-digest))))
    (unless (and (string=? (.ref validation-closure 'subject-snapshot-digest)
                           (.ref conformance-receipt
                                 'subject-snapshot-digest))
                 (string=? (.ref validation-closure 'subject-snapshot-digest)
                           (.ref reference-observation
                                 'subject-snapshot-digest)))
      (disagree! 'standard-comparison-subject-mismatch
                 (.ref reference-observation 'fixture-identity)
                 (list (.ref validation-closure 'subject-snapshot-digest)
                       (.ref conformance-receipt 'subject-snapshot-digest)
                       (.ref reference-observation 'subject-snapshot-digest))))
    (unless (equal? (.ref (.ref validation-closure 'bundle) 'root-identities)
                    (.ref reference-observation 'profile-identities))
      (disagree! 'standard-comparison-profile-mismatch
                 (.ref reference-observation 'fixture-identity)
                 (list (.ref (.ref validation-closure 'bundle) 'root-identities)
                       (.ref reference-observation 'profile-identities))))
    (unless (string=? (.ref validation-closure 'provider-identity)
                      (.ref conformance-receipt 'provider-identity))
      (disagree! 'standard-comparison-provider-mismatch
                 (.ref validation-closure 'provider-identity)
                 (.ref conformance-receipt 'provider-identity)))
    (let (reference-outcome (.ref reference-observation 'outcome))
      (cond
       ((eq? reference-outcome 'not-evaluated)
        (disagree! 'standard-reference-validator-not-evaluated
                   (.ref reference-observation 'validator-identity)
                   (.ref reference-observation 'issues)))
       ((not (eq? (.ref conformance-receipt 'valid?)
                  (eq? reference-outcome 'valid)))
        (disagree! 'standard-reference-validator-disagreement
                   (.ref reference-observation 'fixture-identity)
                   (list (cons 'provider-valid?
                               (.ref conformance-receipt 'valid?))
                         (cons 'reference-outcome reference-outcome))))))
    (let* ((discrepancies (reverse discrepancies-rev))
           (failures (reverse failures-rev))
           (comparison-digest
            (agentic-ai-lab-standard-digest
             (list 'agentic-ai-lab.standard-comparison-receipt.v1
                   (.ref conformance-receipt 'conformance-digest)
                   (.ref reference-observation 'observation-digest)
                   discrepancies))))
      (agentic-ai-lab-standard-comparison-receipt
       (null? discrepancies)
       (.ref conformance-receipt 'provider-identity)
       (.ref reference-observation 'validator-identity)
       (.ref reference-observation 'validator-version)
       (.ref validation-closure 'subject-snapshot-digest)
       (.ref reference-observation 'profile-identities)
       (.ref conformance-receipt 'conformance-digest)
       (.ref reference-observation 'observation-digest)
       discrepancies failures comparison-digest))))
