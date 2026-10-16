;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: AC-11 preflight verifies supplied cutover evidence.
;;; Invariant: readiness checks cannot authorize or execute cutover.

(export #t)

(import (only-in :clan/poo/object .ref object<-alist)
        :core/object-family/role-syntax
        :core/object-family/syntax
        :poo-flow/modules/workflow/qualification/capability-prototypes)

(def +poo-flow-cutover-readiness-input-kind+
  'poo-flow.cutover-readiness-input.v1)
(def +poo-flow-cutover-readiness-receipt-kind+
  'poo-flow.cutover-readiness.v1)

(defpoo-object-family +poo-flow-cutover-readiness-input-kind+
  poo-flow-cutover-readiness-input?
  (accessors
   (poo-flow-cutover-readiness-source-revision source-revision)
   (poo-flow-cutover-readiness-ac10-source-revision ac10-source-revision)
   (poo-flow-cutover-readiness-ac10-manifest-digest ac10-manifest-digest)
   (poo-flow-cutover-readiness-symbol-source-revision symbol-source-revision)
   (poo-flow-cutover-readiness-symbol-receipt symbol-receipt)
   (poo-flow-cutover-readiness-version-source-revision version-source-revision)
   (poo-flow-cutover-readiness-version-receipt version-receipt)
   (poo-flow-cutover-readiness-legacy-guards legacy-guards)
   (poo-flow-cutover-readiness-external-blocker external-blocker)
   (poo-flow-cutover-readiness-decision-required? decision-required?)
   (poo-flow-cutover-readiness-abi-v1-frozen? abi-v1-frozen?)
   (poo-flow-cutover-readiness-deletion-authorized? deletion-authorized?))
  (projections))

(def (poo-flow-cutover-legacy-guard guard-id accepted-value? artifact-value)
  (object<-alist
   (list (cons 'kind 'poo-flow.cutover-legacy-guard.v1)
         (cons 'guard-id guard-id)
         (cons 'accepted? accepted-value?)
         (cons 'artifact artifact-value))))

(def (poo-flow-cutover-external-blocker owner-value code-value
                                        product-blocker-value?)
  (object<-alist
   (list (cons 'kind 'poo-flow.cutover-external-blocker.v1)
         (cons 'owner owner-value)
         (cons 'code code-value)
         (cons 'product-blocker? product-blocker-value?))))

(def (poo-flow-cutover-readiness-input source-revision-value
                                       ac10-source-revision-value
                                       ac10-manifest-digest-value
                                       symbol-source-revision-value
                                       symbol-receipt-value
                                       version-source-revision-value
                                       version-receipt-value
                                       legacy-guards-value
                                       external-blocker-value
                                       decision-required-value?
                                       abi-v1-frozen-value?
                                       deletion-authorized-value?)
  (poo-flow-qualification-capability-composition-assert!
   (list (cons 'versioned +poo-flow-versioned-capability-slots+)
         (cons 'revision-bound +poo-flow-revision-bound-capability-slots+)
         (cons 'evidence-bound +poo-flow-evidence-bound-capability-slots+)
         (cons 'decision-state +poo-flow-decision-state-capability-slots+)))
  (poo-core-role-object
   (slots ((kind +poo-flow-cutover-readiness-input-kind+)
           (ac10-source-revision ac10-source-revision-value)
           (ac10-manifest-digest ac10-manifest-digest-value)
           (symbol-source-revision symbol-source-revision-value)
           (version-source-revision version-source-revision-value)))
   (supers
    (poo-flow-versioned-capability
     +poo-flow-cutover-readiness-input-kind+ 1)
    (poo-flow-revision-bound-capability source-revision-value)
    (poo-flow-evidence-bound-capability
     symbol-receipt-value version-receipt-value legacy-guards-value
     external-blocker-value)
    (poo-flow-decision-state-capability
     decision-required-value? abi-v1-frozen-value?
     deletion-authorized-value? #f))))

(def +poo-flow-cutover-required-legacy-guards+
  '(python-no-ctypes agent-sandbox-zero-consumer))

(def (cutover-present-string? value)
  (and (string? value) (> (string-length value) 0)))

(def (cutover-find-guard guards guard-id)
  (find (lambda (guard) (eq? (.ref guard 'guard-id) guard-id)) guards))

(def (cutover-legacy-guards-valid? guards)
  (and (list? guards)
       (andmap
        (lambda (guard-id)
          (let (guard (cutover-find-guard guards guard-id))
            (and guard (.ref guard 'accepted?)
                 (cutover-present-string? (.ref guard 'artifact)))))
        +poo-flow-cutover-required-legacy-guards+)))

(def (cutover-external-blocker-valid? blocker)
  (and blocker
       (eq? (.ref blocker 'owner) 'asp-provider)
       (memq (.ref blocker 'code)
             '(missing-asp-source-index-token-owner-v1
               missing-semantic-kind))
       (not (.ref blocker 'product-blocker?))))

(def (poo-flow-cutover-readiness-verify input)
  (let ((diagnostics '())
        (revision (poo-flow-cutover-readiness-source-revision input)))
    (def (reject! code) (set! diagnostics (cons code diagnostics)))
    (unless (poo-flow-qualification-capabilities-valid?
             input
             (list poo-flow-versioned-capability-valid?
                   poo-flow-revision-bound-capability-valid?
                   poo-flow-evidence-bound-capability-valid?
                   poo-flow-decision-state-capability-valid?))
      (reject! 'invalid-capability-composition))
    (unless (and (cutover-present-string? revision)
                 (cutover-present-string?
                  (poo-flow-cutover-readiness-ac10-source-revision input))
                 (cutover-present-string?
                  (poo-flow-cutover-readiness-ac10-manifest-digest input)))
      (reject! 'missing-ac10-binding))
    (unless (equal? revision
                    (poo-flow-cutover-readiness-symbol-source-revision input))
      (reject! 'symbol-revision-mismatch))
    (unless (equal? revision
                    (poo-flow-cutover-readiness-version-source-revision input))
      (reject! 'version-revision-mismatch))
    (unless (.ref (poo-flow-cutover-readiness-symbol-receipt input) 'accepted?)
      (reject! 'runtime-symbol-surface-rejected))
    (unless (.ref (poo-flow-cutover-readiness-version-receipt input) 'accepted?)
      (reject! 'release-version-matrix-rejected))
    (unless (cutover-legacy-guards-valid?
             (poo-flow-cutover-readiness-legacy-guards input))
      (reject! 'legacy-guard-rejected))
    (unless (cutover-external-blocker-valid?
             (poo-flow-cutover-readiness-external-blocker input))
      (reject! 'external-blocker-unclassified))
    (unless (poo-flow-cutover-readiness-decision-required? input)
      (reject! 'release-decision-bypassed))
    (when (poo-flow-cutover-readiness-abi-v1-frozen? input)
      (reject! 'implicit-abi-v1-freeze))
    (when (poo-flow-cutover-readiness-deletion-authorized? input)
      (reject! 'deletion-without-release-decision))
    (let (accepted? (null? diagnostics))
      (object<-alist
       (list
        (cons 'kind +poo-flow-cutover-readiness-receipt-kind+)
        (cons 'schema "poo-flow.cutover-readiness.v1")
        (cons 'schema-version 1)
        (cons 'source-revision revision)
        (cons 'ac10-source-revision
              (poo-flow-cutover-readiness-ac10-source-revision input))
        (cons 'ac10-manifest-digest
              (poo-flow-cutover-readiness-ac10-manifest-digest input))
        (cons 'ready? accepted?)
        (cons 'decision-required? #t)
        (cons 'abi-v1-frozen? #f)
        (cons 'deletion-authorized? #f)
        (cons 'diagnostics (reverse diagnostics)))))))
