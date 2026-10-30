;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: bind qualified version owners without freezing ABI v1.

(export #t)

(import (only-in :clan/poo/object .ref object<-alist)
        :yuanxu/object-family/role-syntax
        :yuanxu/object-family/syntax
        :agentic-ai-lab/modules/workflow/qualification/capability-prototypes
        (only-in :agentic-ai-lab/modules/query/semantic/organization-bundle
                 +agentic-ai-lab-organization-bundle-schema+)
        (only-in :agentic-ai-lab/modules/workflow/contracts/runtime-v0-abi-schema
                 +agentic-ai-lab-runtime-v0-abi-schema+)
        (only-in :agentic-ai-lab/modules/workflow/contracts/release-assurance-manifest
                 +agentic-ai-lab-release-assurance-manifest-schema+))

(def +agentic-ai-lab-release-version-matrix-kind+
  'agentic-ai-lab.release-version-matrix.v1)
(def +agentic-ai-lab-release-version-matrix-receipt-kind+
  'agentic-ai-lab.release-version-matrix-receipt.v1)

;; AC-10-qualified snapshot.  The generated Scheme/TOML pair remains the owner;
;; proof freshness and four-way differential gates verify these bound values.
(def +agentic-ai-lab-ac11-qualified-proof-vector-version+ 1)
(def +agentic-ai-lab-ac11-qualified-proof-schema-fingerprint+
  "1627b834b99c2b23e4ee0019d38c672dfb86d6bfc44d55afaf18ad501160853a")
(def +agentic-ai-lab-ac11-qualified-proof-vector-domain+
  "agentic-ai-lab.proof-case-vector.v1")
(def +agentic-ai-lab-ac11-qualified-proof-theorem-set-domain+
  "agentic-ai-lab.authorized-effect-theorem-set.v1")

(defpoo-object-family +agentic-ai-lab-release-version-matrix-kind+
  agentic-ai-lab-release-version-matrix?
  (accessors
   (agentic-ai-lab-release-version-matrix-bundle-schema bundle-schema)
   (agentic-ai-lab-release-version-matrix-runtime-abi runtime-abi)
   (agentic-ai-lab-release-version-matrix-proof-vector proof-vector)
   (agentic-ai-lab-release-version-matrix-assurance-schema assurance-schema)
   (agentic-ai-lab-release-version-matrix-owner-artifacts owner-artifacts)
   (agentic-ai-lab-release-version-matrix-abi-v1-frozen? abi-v1-frozen?))
  (projections))

;; : (-> Symbol AgenticAILabRuntimeAbiVersion AgenticAILabProofVectorVersion Symbol [Path] Boolean AgenticAILabReleaseVersionMatrix)
(def (agentic-ai-lab-release-version-matrix bundle-schema-value runtime-abi-value
                                      proof-vector-value assurance-schema-value
                                      owner-artifacts-value frozen-value?)
  (agentic-ai-lab-qualification-capability-composition-assert!
   (map cons
        '(versioned owner-bound decision-state)
        (list +agentic-ai-lab-versioned-capability-slots+
              +agentic-ai-lab-owner-bound-capability-slots+
              +agentic-ai-lab-decision-state-capability-slots+)))
  (poo-core-role-object
   (slots ((kind +agentic-ai-lab-release-version-matrix-kind+)
           (bundle-schema bundle-schema-value)
           (runtime-abi runtime-abi-value)
           (proof-vector proof-vector-value)
           (assurance-schema assurance-schema-value)))
   (supers
    (agentic-ai-lab-versioned-capability
     +agentic-ai-lab-release-version-matrix-kind+ 1)
    (agentic-ai-lab-owner-bound-capability owner-artifacts-value)
    (agentic-ai-lab-decision-state-capability #t frozen-value? #f #f))))

(def (agentic-ai-lab-ac11-current-release-version-matrix)
  (agentic-ai-lab-release-version-matrix
   +agentic-ai-lab-organization-bundle-schema+
   (object<-alist
    (list (cons 'kind 'agentic-ai-lab.runtime-abi-version.v1)
          (cons 'major (.ref +agentic-ai-lab-runtime-v0-abi-schema+ 'abi-major))
          (cons 'minor (.ref +agentic-ai-lab-runtime-v0-abi-schema+ 'abi-minor))))
   (object<-alist
    (list (cons 'kind 'agentic-ai-lab.proof-vector-version.v1)
          (cons 'version +agentic-ai-lab-ac11-qualified-proof-vector-version+)
          (cons 'schema-fingerprint
                +agentic-ai-lab-ac11-qualified-proof-schema-fingerprint+)
          (cons 'vector-domain
                +agentic-ai-lab-ac11-qualified-proof-vector-domain+)
          (cons 'theorem-set-domain
                +agentic-ai-lab-ac11-qualified-proof-theorem-set-domain+)))
   +agentic-ai-lab-release-assurance-manifest-schema+
   '(src/semantic/organization-bundle.ss
     src/contract/runtime-v0-abi-schema.ss
     src/proof/generated/proof-case-vector-v1.ss
     packages/proofs/proof-case-vector-v1.toml
     src/contract/release-assurance-manifest.ss)
   #f))

;; : (-> AgenticAILabRuntimeAbiVersion AgenticAILabRuntimeAbiVersion Boolean)
(def (release-runtime-abi=? left right)
  (andmap identity
          (list (= (.ref left 'major) (.ref right 'major))
                (= (.ref left 'minor) (.ref right 'minor)))))

;; : (-> AgenticAILabProofVectorVersion AgenticAILabProofVectorVersion Boolean)
(def (release-proof-vector=? left right)
  (andmap identity
          (list (= (.ref left 'version) (.ref right 'version))
                (equal? (.ref left 'schema-fingerprint)
                        (.ref right 'schema-fingerprint))
                (equal? (.ref left 'vector-domain) (.ref right 'vector-domain))
                (equal? (.ref left 'theorem-set-domain)
                        (.ref right 'theorem-set-domain)))))

;; : (-> AgenticAILabReleaseVersionMatrix AgenticAILabReleaseVersionMatrixReceipt)
(def (agentic-ai-lab-ac11-release-version-matrix-verify matrix)
  (let* ((expected (agentic-ai-lab-ac11-current-release-version-matrix))
         (accepted?
         (and (agentic-ai-lab-release-version-matrix? matrix)
               (agentic-ai-lab-qualification-capabilities-valid?
                matrix
                (list agentic-ai-lab-versioned-capability-valid?
                      agentic-ai-lab-owner-bound-capability-valid?
                      agentic-ai-lab-decision-state-capability-valid?))
               (equal? (agentic-ai-lab-release-version-matrix-bundle-schema matrix)
                       (agentic-ai-lab-release-version-matrix-bundle-schema expected))
               (release-runtime-abi=?
                (agentic-ai-lab-release-version-matrix-runtime-abi matrix)
                (agentic-ai-lab-release-version-matrix-runtime-abi expected))
               (release-proof-vector=?
                (agentic-ai-lab-release-version-matrix-proof-vector matrix)
                (agentic-ai-lab-release-version-matrix-proof-vector expected))
               (equal? (agentic-ai-lab-release-version-matrix-assurance-schema matrix)
                       (agentic-ai-lab-release-version-matrix-assurance-schema expected))
               (equal? (agentic-ai-lab-release-version-matrix-owner-artifacts matrix)
                       (agentic-ai-lab-release-version-matrix-owner-artifacts expected))
               (not (agentic-ai-lab-release-version-matrix-abi-v1-frozen? matrix)))))
    (object<-alist
     (list (cons 'kind +agentic-ai-lab-release-version-matrix-receipt-kind+)
           (cons 'accepted? accepted?)
           (cons 'matrix matrix)
           (cons 'abi-v1-frozen? #f)
           (cons 'decision-required? #t)
           (cons 'diagnostics
                 (if accepted? '() '(release-version-owner-drift)))))))
