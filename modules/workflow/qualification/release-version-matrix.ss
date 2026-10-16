;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: bind qualified version owners without freezing ABI v1.

(export #t)

(import (only-in :clan/poo/object .ref object<-alist)
        :core/object-family/role-syntax
        :core/object-family/syntax
        :poo-flow/modules/workflow/qualification/capability-prototypes
        (only-in :poo-flow/modules/query/semantic/organization-bundle
                 +poo-flow-organization-bundle-schema+)
        (only-in :poo-flow/modules/workflow/contracts/runtime-v0-abi-schema
                 +poo-flow-runtime-v0-abi-schema+)
        (only-in :poo-flow/modules/workflow/contracts/release-assurance-manifest
                 +poo-flow-release-assurance-manifest-schema+))

(def +poo-flow-release-version-matrix-kind+
  'poo-flow.release-version-matrix.v1)
(def +poo-flow-release-version-matrix-receipt-kind+
  'poo-flow.release-version-matrix-receipt.v1)

;; AC-10-qualified snapshot.  The generated Scheme/TOML pair remains the owner;
;; proof freshness and four-way differential gates verify these bound values.
(def +poo-flow-ac11-qualified-proof-vector-version+ 1)
(def +poo-flow-ac11-qualified-proof-schema-fingerprint+
  "bad9c5d0781d0a99e2f8d58cb94abae9dfc2eda4c71a01009897f7fc5419e0e7")
(def +poo-flow-ac11-qualified-proof-vector-domain+
  "poo-flow.proof-case-vector.v1")
(def +poo-flow-ac11-qualified-proof-theorem-set-domain+
  "poo-flow.authorized-effect-theorem-set.v1")

(defpoo-object-family +poo-flow-release-version-matrix-kind+
  poo-flow-release-version-matrix?
  (accessors
   (poo-flow-release-version-matrix-bundle-schema bundle-schema)
   (poo-flow-release-version-matrix-runtime-abi runtime-abi)
   (poo-flow-release-version-matrix-proof-vector proof-vector)
   (poo-flow-release-version-matrix-assurance-schema assurance-schema)
   (poo-flow-release-version-matrix-owner-artifacts owner-artifacts)
   (poo-flow-release-version-matrix-abi-v1-frozen? abi-v1-frozen?))
  (projections))

;; : (-> Symbol PooFlowRuntimeAbiVersion PooFlowProofVectorVersion Symbol [Path] Boolean PooFlowReleaseVersionMatrix)
(def (poo-flow-release-version-matrix bundle-schema-value runtime-abi-value
                                      proof-vector-value assurance-schema-value
                                      owner-artifacts-value frozen-value?)
  (poo-flow-qualification-capability-composition-assert!
   (map cons
        '(versioned owner-bound decision-state)
        (list +poo-flow-versioned-capability-slots+
              +poo-flow-owner-bound-capability-slots+
              +poo-flow-decision-state-capability-slots+)))
  (poo-core-role-object
   (slots ((kind +poo-flow-release-version-matrix-kind+)
           (bundle-schema bundle-schema-value)
           (runtime-abi runtime-abi-value)
           (proof-vector proof-vector-value)
           (assurance-schema assurance-schema-value)))
   (supers
    (poo-flow-versioned-capability
     +poo-flow-release-version-matrix-kind+ 1)
    (poo-flow-owner-bound-capability owner-artifacts-value)
    (poo-flow-decision-state-capability #t frozen-value? #f #f))))

(def (poo-flow-ac11-current-release-version-matrix)
  (poo-flow-release-version-matrix
   +poo-flow-organization-bundle-schema+
   (object<-alist
    (list (cons 'kind 'poo-flow.runtime-abi-version.v1)
          (cons 'major (.ref +poo-flow-runtime-v0-abi-schema+ 'abi-major))
          (cons 'minor (.ref +poo-flow-runtime-v0-abi-schema+ 'abi-minor))))
   (object<-alist
    (list (cons 'kind 'poo-flow.proof-vector-version.v1)
          (cons 'version +poo-flow-ac11-qualified-proof-vector-version+)
          (cons 'schema-fingerprint
                +poo-flow-ac11-qualified-proof-schema-fingerprint+)
          (cons 'vector-domain
                +poo-flow-ac11-qualified-proof-vector-domain+)
          (cons 'theorem-set-domain
                +poo-flow-ac11-qualified-proof-theorem-set-domain+)))
   +poo-flow-release-assurance-manifest-schema+
   '(src/semantic/organization-bundle.ss
     src/contract/runtime-v0-abi-schema.ss
     src/proof/generated/proof-case-vector-v1.ss
     packages/proofs/proof-case-vector-v1.toml
     src/contract/release-assurance-manifest.ss)
   #f))

;; : (-> PooFlowRuntimeAbiVersion PooFlowRuntimeAbiVersion Boolean)
(def (release-runtime-abi=? left right)
  (andmap identity
          (list (= (.ref left 'major) (.ref right 'major))
                (= (.ref left 'minor) (.ref right 'minor)))))

;; : (-> PooFlowProofVectorVersion PooFlowProofVectorVersion Boolean)
(def (release-proof-vector=? left right)
  (andmap identity
          (list (= (.ref left 'version) (.ref right 'version))
                (equal? (.ref left 'schema-fingerprint)
                        (.ref right 'schema-fingerprint))
                (equal? (.ref left 'vector-domain) (.ref right 'vector-domain))
                (equal? (.ref left 'theorem-set-domain)
                        (.ref right 'theorem-set-domain)))))

;; : (-> PooFlowReleaseVersionMatrix PooFlowReleaseVersionMatrixReceipt)
(def (poo-flow-ac11-release-version-matrix-verify matrix)
  (let* ((expected (poo-flow-ac11-current-release-version-matrix))
         (accepted?
         (and (poo-flow-release-version-matrix? matrix)
               (poo-flow-qualification-capabilities-valid?
                matrix
                (list poo-flow-versioned-capability-valid?
                      poo-flow-owner-bound-capability-valid?
                      poo-flow-decision-state-capability-valid?))
               (equal? (poo-flow-release-version-matrix-bundle-schema matrix)
                       (poo-flow-release-version-matrix-bundle-schema expected))
               (release-runtime-abi=?
                (poo-flow-release-version-matrix-runtime-abi matrix)
                (poo-flow-release-version-matrix-runtime-abi expected))
               (release-proof-vector=?
                (poo-flow-release-version-matrix-proof-vector matrix)
                (poo-flow-release-version-matrix-proof-vector expected))
               (equal? (poo-flow-release-version-matrix-assurance-schema matrix)
                       (poo-flow-release-version-matrix-assurance-schema expected))
               (equal? (poo-flow-release-version-matrix-owner-artifacts matrix)
                       (poo-flow-release-version-matrix-owner-artifacts expected))
               (not (poo-flow-release-version-matrix-abi-v1-frozen? matrix)))))
    (object<-alist
     (list (cons 'kind +poo-flow-release-version-matrix-receipt-kind+)
           (cons 'accepted? accepted?)
           (cons 'matrix matrix)
           (cons 'abi-v1-frozen? #f)
           (cons 'decision-required? #t)
           (cons 'diagnostics
                 (if accepted? '() '(release-version-owner-drift)))))))
