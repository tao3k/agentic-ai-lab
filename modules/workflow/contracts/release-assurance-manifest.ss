;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: owns canonical release-assurance manifests and their content identity.
;;; Invariant: validation and digest construction use the same normalized manifest fields.
(export #t)

(import (only-in :clan/poo/object .o .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        :yuanxu/object-family/role-syntax
        :yuanxu/object-family/syntax
        :agentic-ai-lab/modules/workflow/qualification/capability-prototypes)

(def +agentic-ai-lab-release-assurance-manifest-schema+
  'agentic-ai-lab.release-assurance-manifest.v1)

(def +agentic-ai-lab-assurance-claim-kind+ 'agentic-ai-lab.assurance-claim.v1)
(def +agentic-ai-lab-assurance-tcb-kind+ 'agentic-ai-lab.assurance-tcb.v1)
(def +agentic-ai-lab-assurance-evidence-reference-kind+
  'agentic-ai-lab.assurance-evidence-reference.v1)
(def +agentic-ai-lab-assurance-gate-result-kind+ 'agentic-ai-lab.assurance-gate-result.v1)
(def +agentic-ai-lab-assurance-abi-decision-kind+ 'agentic-ai-lab.assurance-abi-decision.v1)

(defpoo-object-family +agentic-ai-lab-assurance-claim-kind+
  agentic-ai-lab-assurance-claim?
  (accessors
   (agentic-ai-lab-assurance-claim-id claim-id)
   (agentic-ai-lab-assurance-claim-level level)
   (agentic-ai-lab-assurance-claim-owner owner)
   (agentic-ai-lab-assurance-claim-tcb tcb)
   (agentic-ai-lab-assurance-claim-evidence evidence)
   (agentic-ai-lab-assurance-claim-exclusions exclusions)
   (agentic-ai-lab-assurance-claim-failure-state failure-state))
  (projections))

(defpoo-object-family +agentic-ai-lab-assurance-tcb-kind+
  agentic-ai-lab-assurance-tcb?
  (accessors
   (agentic-ai-lab-assurance-tcb-id tcb-id)
   (agentic-ai-lab-assurance-tcb-family family)
   (agentic-ai-lab-assurance-tcb-components components))
  (projections))

(defpoo-object-family +agentic-ai-lab-assurance-evidence-reference-kind+
  agentic-ai-lab-assurance-evidence-reference?
  (accessors
   (agentic-ai-lab-assurance-evidence-reference-id evidence-id)
   (agentic-ai-lab-assurance-evidence-reference-owner owner)
   (agentic-ai-lab-assurance-evidence-reference-artifact artifact)
   (agentic-ai-lab-assurance-evidence-reference-digest digest))
  (projections))

(defpoo-object-family +agentic-ai-lab-assurance-gate-result-kind+
  agentic-ai-lab-assurance-gate-result?
  (accessors
   (agentic-ai-lab-assurance-gate-result-id gate-id)
   (agentic-ai-lab-assurance-gate-result-owner owner)
   (agentic-ai-lab-assurance-gate-result-status status)
   (agentic-ai-lab-assurance-gate-result-evidence evidence))
  (projections))

(defpoo-object-family +agentic-ai-lab-assurance-abi-decision-kind+
  agentic-ai-lab-assurance-abi-decision?
  (accessors
   (agentic-ai-lab-assurance-abi-decision-version version)
   (agentic-ai-lab-assurance-abi-decision-frozen? frozen?)
   (agentic-ai-lab-assurance-abi-decision-review review))
  (projections))

(defpoo-object-family +agentic-ai-lab-release-assurance-manifest-schema+
  agentic-ai-lab-release-assurance-manifest?
  (accessors
   (release-assurance-manifest-release release)
   (release-assurance-manifest-environment environment)
   (release-assurance-manifest-assurance assurance)
   (agentic-ai-lab-release-assurance-manifest-abi-decision abi-decision))
  (projections))

(def (agentic-ai-lab-release-assurance-manifest-release-id manifest)
  (.ref (release-assurance-manifest-release manifest) 'release-id))
(def (agentic-ai-lab-release-assurance-manifest-source-revision manifest)
  (.ref (release-assurance-manifest-release manifest) 'source-revision))
(def (agentic-ai-lab-release-assurance-manifest-host manifest)
  (.ref (release-assurance-manifest-environment manifest) 'host))
(def (agentic-ai-lab-release-assurance-manifest-toolchains manifest)
  (.ref (release-assurance-manifest-environment manifest) 'toolchains))
(def (agentic-ai-lab-release-assurance-manifest-identities manifest)
  (.ref (release-assurance-manifest-assurance manifest) 'identities))
(def (agentic-ai-lab-release-assurance-manifest-tcbs manifest)
  (.ref (release-assurance-manifest-assurance manifest) 'tcbs))
(def (agentic-ai-lab-release-assurance-manifest-claims manifest)
  (.ref (release-assurance-manifest-assurance manifest) 'claims))
(def (agentic-ai-lab-release-assurance-manifest-gates manifest)
  (.ref (release-assurance-manifest-assurance manifest) 'gates))

(def (agentic-ai-lab-assurance-tcb tcb-id-value family-value components-value)
  (.o (kind +agentic-ai-lab-assurance-tcb-kind+)
      (tcb-id tcb-id-value)
      (family family-value)
      (components components-value)))

(def (agentic-ai-lab-assurance-evidence-reference evidence-id-value owner-value
                                             artifact-value digest-value)
  (.o (kind +agentic-ai-lab-assurance-evidence-reference-kind+)
      (evidence-id evidence-id-value)
      (owner owner-value)
      (artifact artifact-value)
      (digest digest-value)))

(def (agentic-ai-lab-assurance-claim claim-id-value level-value owner-value tcb-value
                               evidence-value exclusions-value
                               failure-state-value)
  (.o (kind +agentic-ai-lab-assurance-claim-kind+)
      (claim-id claim-id-value)
      (level level-value)
      (owner owner-value)
      (tcb tcb-value)
      (evidence evidence-value)
      (exclusions exclusions-value)
      (failure-state failure-state-value)))

(def (agentic-ai-lab-assurance-gate-result gate-id-value owner-value status-value
                                     evidence-value)
  (.o (kind +agentic-ai-lab-assurance-gate-result-kind+)
      (gate-id gate-id-value)
      (owner owner-value)
      (status status-value)
      (evidence evidence-value)))

(def (agentic-ai-lab-assurance-abi-decision version-value frozen-value? review-value)
  (.o (kind +agentic-ai-lab-assurance-abi-decision-kind+)
      (version version-value)
      (frozen? frozen-value?)
      (review review-value)))

(def (agentic-ai-lab-release-assurance-manifest release-id-value revision-value
                                           host-value toolchains-value
                                           identities-value tcbs-value
                                           claims-value gates-value
                                           abi-decision-value)
  (agentic-ai-lab-qualification-capability-composition-assert!
   (list (cons 'versioned +agentic-ai-lab-versioned-capability-slots+)
         (cons 'revision-bound +agentic-ai-lab-revision-bound-capability-slots+)))
  (let ((release-value
         (.o (kind 'agentic-ai-lab.release-assurance-release.v1)
             (release-id release-id-value)
             (source-revision revision-value)))
        (environment-value
         (.o (kind 'agentic-ai-lab.release-assurance-environment.v1)
             (host host-value)
             (toolchains toolchains-value)))
        (assurance-value
         (.o (kind 'agentic-ai-lab.release-assurance-evidence.v1)
             (identities identities-value)
             (tcbs tcbs-value)
             (claims claims-value)
             (gates gates-value))))
    (poo-core-role-object
     (slots ((kind +agentic-ai-lab-release-assurance-manifest-schema+)
             (schema +agentic-ai-lab-release-assurance-manifest-schema+)
             (release release-value)
             (environment environment-value)
             (assurance assurance-value)
             (abi-decision abi-decision-value)))
     (supers
      (agentic-ai-lab-versioned-capability
       +agentic-ai-lab-release-assurance-manifest-schema+ 1)
      (agentic-ai-lab-revision-bound-capability revision-value)))))

(def (assurance-id->string value)
  (cond
   ((symbol? value) (symbol->string value))
   ((string? value) value)
   (else (call-with-output-string (lambda (port) (write value port))))))

(def (assurance-sort values id-of)
  (list-sort (lambda (left right)
               (string<? (assurance-id->string (id-of left))
                         (assurance-id->string (id-of right))))
             (append values '())))

(def (assurance-sort-values values)
  (list-sort (lambda (left right)
               (string<? (assurance-id->string left)
                         (assurance-id->string right)))
             (append values '())))

(def (assurance-pair-sort values)
  (list-sort (lambda (left right)
               (string<? (assurance-id->string (car left))
                         (assurance-id->string (car right))))
             (append values '())))

(def (tcb->canonical value)
  (list 'tcb
        (agentic-ai-lab-assurance-tcb-id value)
        (agentic-ai-lab-assurance-tcb-family value)
        (cons 'components
              (assurance-sort-values
               (agentic-ai-lab-assurance-tcb-components value)))))

(def (evidence->canonical value)
  (list 'evidence
        (agentic-ai-lab-assurance-evidence-reference-id value)
        (list 'owner (agentic-ai-lab-assurance-evidence-reference-owner value))
        (list 'artifact (agentic-ai-lab-assurance-evidence-reference-artifact value))
        (list 'digest (agentic-ai-lab-assurance-evidence-reference-digest value))))

(def (claim->canonical value)
  (list 'claim
        (agentic-ai-lab-assurance-claim-id value)
        (list 'level (agentic-ai-lab-assurance-claim-level value))
        (list 'owner (agentic-ai-lab-assurance-claim-owner value))
        (list 'tcb (agentic-ai-lab-assurance-tcb-id
                    (agentic-ai-lab-assurance-claim-tcb value)))
        (cons 'evidence
              (map evidence->canonical
                   (assurance-sort
                    (agentic-ai-lab-assurance-claim-evidence value)
                    agentic-ai-lab-assurance-evidence-reference-id)))
        (cons 'exclusions
              (assurance-sort-values
               (agentic-ai-lab-assurance-claim-exclusions value)))
        (list 'failure-state
              (agentic-ai-lab-assurance-claim-failure-state value))))

(def (gate->canonical value)
  (list 'gate
        (agentic-ai-lab-assurance-gate-result-id value)
        (list 'owner (agentic-ai-lab-assurance-gate-result-owner value))
        (list 'status (agentic-ai-lab-assurance-gate-result-status value))
        (list 'evidence
              (evidence->canonical
               (agentic-ai-lab-assurance-gate-result-evidence value)))))

(def (abi-decision->canonical value)
  (list 'abi-decision
        (list 'version (agentic-ai-lab-assurance-abi-decision-version value))
        (list 'frozen? (agentic-ai-lab-assurance-abi-decision-frozen? value))
        (list 'review (agentic-ai-lab-assurance-abi-decision-review value))))

(def (agentic-ai-lab-release-assurance-manifest-normalize manifest)
  (list +agentic-ai-lab-release-assurance-manifest-schema+
        (list 'release-id
              (agentic-ai-lab-release-assurance-manifest-release-id manifest))
        (list 'source-revision
              (agentic-ai-lab-release-assurance-manifest-source-revision manifest))
        (list 'host (agentic-ai-lab-release-assurance-manifest-host manifest))
        (cons 'toolchains
              (assurance-pair-sort
               (agentic-ai-lab-release-assurance-manifest-toolchains manifest)))
        (cons 'identities
              (assurance-pair-sort
               (agentic-ai-lab-release-assurance-manifest-identities manifest)))
        (cons 'tcbs
              (map tcb->canonical
                   (assurance-sort
                    (agentic-ai-lab-release-assurance-manifest-tcbs manifest)
                    agentic-ai-lab-assurance-tcb-id)))
        (cons 'claims
              (map claim->canonical
                   (assurance-sort
                    (agentic-ai-lab-release-assurance-manifest-claims manifest)
                    agentic-ai-lab-assurance-claim-id)))
        (cons 'gates
              (map gate->canonical
                   (assurance-sort
                    (agentic-ai-lab-release-assurance-manifest-gates manifest)
                    agentic-ai-lab-assurance-gate-result-id)))
        (abi-decision->canonical
         (agentic-ai-lab-release-assurance-manifest-abi-decision manifest))))

(def (duplicate-ids values id-of)
  (let (sorted (assurance-sort values id-of))
    (if (or (null? sorted) (null? (cdr sorted)))
      '()
      (filter-map
       (lambda (adjacent)
         (let ((previous-id (id-of (car adjacent)))
               (current-id (id-of (cdr adjacent))))
           (and (equal? previous-id current-id) current-id)))
       (map cons sorted (cdr sorted))))))

(def (nonempty-id? value)
  (or (symbol? value)
      (and (string? value) (> (string-length value) 0))))

(def (diagnostic code path observed)
  (list (cons 'code code) (cons 'path path) (cons 'observed observed)))

;;; Validation boundary: accumulate all manifest diagnostics before returning a decision.
(def (agentic-ai-lab-release-assurance-manifest-validate manifest)
  (let (diagnostics '())
    (def (reject! code path observed)
      (set! diagnostics (cons (diagnostic code path observed) diagnostics)))
    (unless (agentic-ai-lab-release-assurance-manifest? manifest)
      (reject! 'invalid-manifest '(kind) manifest))
    (when (agentic-ai-lab-release-assurance-manifest? manifest)
      (let (capabilities-valid?
            (agentic-ai-lab-qualification-capabilities-valid?
             manifest
             (list agentic-ai-lab-versioned-capability-valid?
                   agentic-ai-lab-revision-bound-capability-valid?)))
        (unless capabilities-valid?
          (reject! 'invalid-capability-composition '(capabilities) #f))
        (when capabilities-valid?
          (unless (and (equal? (.ref manifest 'schema-id)
                               +agentic-ai-lab-release-assurance-manifest-schema+)
                       (= (.ref manifest 'schema-version) 1))
            (reject! 'capability-schema-mismatch
                     '(capabilities versioned)
                     (list (.ref manifest 'schema-id)
                           (.ref manifest 'schema-version))))
          (unless (equal?
                   (.ref manifest 'source-revision)
                   (agentic-ai-lab-release-assurance-manifest-source-revision
                    manifest))
            (reject! 'capability-revision-mismatch
                     '(capabilities revision-bound source-revision)
                     (.ref manifest 'source-revision)))))
      (unless (nonempty-id?
               (agentic-ai-lab-release-assurance-manifest-release-id manifest))
        (reject! 'missing-release-id '(release-id) #f))
      (unless (nonempty-id?
               (agentic-ai-lab-release-assurance-manifest-source-revision manifest))
        (reject! 'missing-source-revision '(source-revision) #f))
      (unless (pair? (agentic-ai-lab-release-assurance-manifest-identities manifest))
        (reject! 'missing-identities '(identities) '()))
      (let ((tcbs (agentic-ai-lab-release-assurance-manifest-tcbs manifest))
            (claims (agentic-ai-lab-release-assurance-manifest-claims manifest))
            (gates (agentic-ai-lab-release-assurance-manifest-gates manifest))
            (abi (agentic-ai-lab-release-assurance-manifest-abi-decision manifest)))
        (unless (and (pair? tcbs) (andmap agentic-ai-lab-assurance-tcb? tcbs))
          (reject! 'invalid-tcbs '(tcbs) tcbs))
        (unless (and (pair? claims) (andmap agentic-ai-lab-assurance-claim? claims))
          (reject! 'invalid-claims '(claims) claims))
        (unless (and (pair? gates) (andmap agentic-ai-lab-assurance-gate-result? gates))
          (reject! 'invalid-gates '(gates) gates))
        (when (andmap agentic-ai-lab-assurance-tcb? tcbs)
          (let (duplicates (duplicate-ids tcbs agentic-ai-lab-assurance-tcb-id))
            (when (pair? duplicates)
              (reject! 'duplicate-tcb-id '(tcbs) duplicates))))
        (when (andmap agentic-ai-lab-assurance-claim? claims)
          (let (duplicates (duplicate-ids claims agentic-ai-lab-assurance-claim-id))
            (when (pair? duplicates)
              (reject! 'duplicate-claim-id '(claims) duplicates)))
          (for-each
           (lambda (claim)
             (unless (and (nonempty-id? (agentic-ai-lab-assurance-claim-owner claim))
                          (agentic-ai-lab-assurance-tcb?
                           (agentic-ai-lab-assurance-claim-tcb claim))
                          (pair? (agentic-ai-lab-assurance-claim-evidence claim))
                          (andmap agentic-ai-lab-assurance-evidence-reference?
                                  (agentic-ai-lab-assurance-claim-evidence claim))
                          (nonempty-id?
                           (agentic-ai-lab-assurance-claim-failure-state claim)))
               (reject! 'incomplete-claim
                        (list 'claims (agentic-ai-lab-assurance-claim-id claim))
                        claim)))
           claims))
        (when (andmap agentic-ai-lab-assurance-gate-result? gates)
          (let (duplicates
                (duplicate-ids gates agentic-ai-lab-assurance-gate-result-id))
            (when (pair? duplicates)
              (reject! 'duplicate-gate-id '(gates) duplicates)))
          (for-each
           (lambda (gate)
             (unless (and (memq (agentic-ai-lab-assurance-gate-result-status gate)
                                '(passed failed unsupported))
                          (agentic-ai-lab-assurance-evidence-reference?
                           (agentic-ai-lab-assurance-gate-result-evidence gate)))
               (reject! 'invalid-gate-result
                        (list 'gates
                              (agentic-ai-lab-assurance-gate-result-id gate))
                        gate)))
           gates))
        (unless (and (agentic-ai-lab-assurance-abi-decision? abi)
                     (boolean?
                      (agentic-ai-lab-assurance-abi-decision-frozen? abi))
                     (nonempty-id?
                      (agentic-ai-lab-assurance-abi-decision-review abi)))
          (reject! 'invalid-abi-decision '(abi-decision) abi))))
    (let (diagnostic-values (reverse diagnostics))
      (.o (kind 'agentic-ai-lab.release-assurance-validation-receipt.v1)
          (accepted? (null? diagnostic-values))
          (code (if (null? diagnostic-values) 'accepted 'rejected))
          (diagnostics diagnostic-values)))))

(def (agentic-ai-lab-release-assurance-manifest-identity manifest)
  (let (validation (agentic-ai-lab-release-assurance-manifest-validate manifest))
    (unless (.ref validation 'accepted?)
      (error "cannot identify invalid release assurance manifest"
             (.ref validation 'diagnostics)))
    (let* ((canonical (agentic-ai-lab-release-assurance-manifest-normalize manifest))
           (digest-value
            (hex-encode
             (sha256
              (string->utf8
               (call-with-output-string
                (lambda (port) (write canonical port))))))))
      (.o (kind 'agentic-ai-lab.release-assurance-manifest.identity.v1)
          (algorithm 'sha256)
          (digest digest-value)
          (release-id
           (agentic-ai-lab-release-assurance-manifest-release-id manifest))
          (source-revision
           (agentic-ai-lab-release-assurance-manifest-source-revision manifest))))))
