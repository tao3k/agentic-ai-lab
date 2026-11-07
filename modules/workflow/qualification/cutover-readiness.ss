;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: AC-11 preflight verifies supplied cutover evidence.
;;; Invariant: readiness checks cannot authorize or execute cutover.

(export #t)

(import (only-in :clan/poo/object .ref object<-alist)
        :yuanxu/object-family/role-syntax
        :yuanxu/object-family/syntax
        :agentic-ai-lab/modules/workflow/qualification/capability-prototypes)

(def +agentic-ai-lab-cutover-readiness-input-kind+
  'agentic-ai-lab.cutover-readiness-input.v1)
(def +agentic-ai-lab-cutover-readiness-receipt-kind+
  'agentic-ai-lab.cutover-readiness.v1)

(defpoo-object-family +agentic-ai-lab-cutover-readiness-input-kind+
  agentic-ai-lab-cutover-readiness-input?
  (accessors
   (agentic-ai-lab-cutover-readiness-source-revision source-revision)
   (agentic-ai-lab-cutover-readiness-ac10-source-revision ac10-source-revision)
   (agentic-ai-lab-cutover-readiness-ac10-manifest-digest ac10-manifest-digest)
   (agentic-ai-lab-cutover-readiness-symbol-source-revision symbol-source-revision)
   (agentic-ai-lab-cutover-readiness-symbol-receipt symbol-receipt)
   (agentic-ai-lab-cutover-readiness-version-source-revision version-source-revision)
   (agentic-ai-lab-cutover-readiness-version-receipt version-receipt)
   (agentic-ai-lab-cutover-readiness-legacy-guards legacy-guards)
   (agentic-ai-lab-cutover-readiness-external-blocker external-blocker)
   (agentic-ai-lab-cutover-readiness-decision-required? decision-required?)
   (agentic-ai-lab-cutover-readiness-abi-v1-frozen? abi-v1-frozen?)
   (agentic-ai-lab-cutover-readiness-deletion-authorized? deletion-authorized?))
  (projections))

(def (agentic-ai-lab-cutover-legacy-guard guard-id accepted-value? artifact-value)
  (object<-alist
   (list (cons 'kind 'agentic-ai-lab.cutover-legacy-guard.v1)
         (cons 'guard-id guard-id)
         (cons 'accepted? accepted-value?)
         (cons 'artifact artifact-value))))

(def (agentic-ai-lab-cutover-external-blocker owner-value code-value
                                        product-blocker-value?)
  (object<-alist
   (list (cons 'kind 'agentic-ai-lab.cutover-external-blocker.v1)
         (cons 'owner owner-value)
         (cons 'code code-value)
         (cons 'product-blocker? product-blocker-value?))))

(def (agentic-ai-lab-cutover-readiness-input source-revision-value
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
  (agentic-ai-lab-qualification-capability-composition-assert!
   (list (cons 'versioned +agentic-ai-lab-versioned-capability-slots+)
         (cons 'revision-bound +agentic-ai-lab-revision-bound-capability-slots+)
         (cons 'evidence-bound +agentic-ai-lab-evidence-bound-capability-slots+)
         (cons 'decision-state +agentic-ai-lab-decision-state-capability-slots+)))
  (poo-core-role-object
   (slots ((kind +agentic-ai-lab-cutover-readiness-input-kind+)
           (ac10-source-revision ac10-source-revision-value)
           (ac10-manifest-digest ac10-manifest-digest-value)
           (symbol-source-revision symbol-source-revision-value)
           (version-source-revision version-source-revision-value)))
   (supers
    (agentic-ai-lab-versioned-capability
     +agentic-ai-lab-cutover-readiness-input-kind+ 1)
    (agentic-ai-lab-revision-bound-capability source-revision-value)
    (agentic-ai-lab-evidence-bound-capability
     symbol-receipt-value version-receipt-value legacy-guards-value
     external-blocker-value)
    (agentic-ai-lab-decision-state-capability
     decision-required-value? abi-v1-frozen-value?
     deletion-authorized-value? #f))))

(def +agentic-ai-lab-cutover-required-legacy-guards+
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
        +agentic-ai-lab-cutover-required-legacy-guards+)))

(def (cutover-external-blocker-valid? blocker)
  (and blocker
       (eq? (.ref blocker 'owner) 'asp-provider)
       (memq (.ref blocker 'code)
             '(missing-asp-source-index-token-owner-v1
               missing-semantic-kind))
       (not (.ref blocker 'product-blocker?))))

(def (agentic-ai-lab-cutover-readiness-verify input)
  (let ((diagnostics '())
        (revision (agentic-ai-lab-cutover-readiness-source-revision input)))
    (def (reject! code) (set! diagnostics (cons code diagnostics)))
    (unless (agentic-ai-lab-qualification-capabilities-valid?
             input
             (list agentic-ai-lab-versioned-capability-valid?
                   agentic-ai-lab-revision-bound-capability-valid?
                   agentic-ai-lab-evidence-bound-capability-valid?
                   agentic-ai-lab-decision-state-capability-valid?))
      (reject! 'invalid-capability-composition))
    (unless (and (cutover-present-string? revision)
                 (cutover-present-string?
                  (agentic-ai-lab-cutover-readiness-ac10-source-revision input))
                 (cutover-present-string?
                  (agentic-ai-lab-cutover-readiness-ac10-manifest-digest input)))
      (reject! 'missing-ac10-binding))
    (unless (equal? revision
                    (agentic-ai-lab-cutover-readiness-symbol-source-revision input))
      (reject! 'symbol-revision-mismatch))
    (unless (equal? revision
                    (agentic-ai-lab-cutover-readiness-version-source-revision input))
      (reject! 'version-revision-mismatch))
    (unless (.ref (agentic-ai-lab-cutover-readiness-symbol-receipt input) 'accepted?)
      (reject! 'runtime-symbol-surface-rejected))
    (unless (.ref (agentic-ai-lab-cutover-readiness-version-receipt input) 'accepted?)
      (reject! 'release-version-matrix-rejected))
    (unless (cutover-legacy-guards-valid?
             (agentic-ai-lab-cutover-readiness-legacy-guards input))
      (reject! 'legacy-guard-rejected))
    (unless (cutover-external-blocker-valid?
             (agentic-ai-lab-cutover-readiness-external-blocker input))
      (reject! 'external-blocker-unclassified))
    (unless (agentic-ai-lab-cutover-readiness-decision-required? input)
      (reject! 'release-decision-bypassed))
    (when (agentic-ai-lab-cutover-readiness-abi-v1-frozen? input)
      (reject! 'implicit-abi-v1-freeze))
    (when (agentic-ai-lab-cutover-readiness-deletion-authorized? input)
      (reject! 'deletion-without-release-decision))
    (let (accepted? (null? diagnostics))
      (object<-alist
       (list
        (cons 'kind +agentic-ai-lab-cutover-readiness-receipt-kind+)
        (cons 'schema "agentic-ai-lab.cutover-readiness.v1")
        (cons 'schema-version 1)
        (cons 'source-revision revision)
        (cons 'ac10-source-revision
              (agentic-ai-lab-cutover-readiness-ac10-source-revision input))
        (cons 'ac10-manifest-digest
              (agentic-ai-lab-cutover-readiness-ac10-manifest-digest input))
        (cons 'ready? accepted?)
        (cons 'decision-required? #t)
        (cons 'abi-v1-frozen? #f)
        (cons 'deletion-authorized? #f)
        (cons 'diagnostics (reverse diagnostics)))))))
