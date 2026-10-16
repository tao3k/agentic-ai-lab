;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: applies canonical organization bundles to the semantic kernel state.
;;; Invariant: transitions retain bundle identity and emit explicit acceptance receipts.
(export #t)

(import (only-in :clan/poo/object .o .ref)
        :poo-flow/modules/query/semantic/organization-bundle)

(def +poo-flow-organization-bundle-kernel-state-schema+
  'poo-flow.organization-bundle-kernel-state.v1)
(def +poo-flow-organization-bundle-kernel-receipt-schema+
  'poo-flow.organization-bundle-kernel-receipt.v1)

(def (kernel-diagnostic code-value expected-value observed-value)
  (.o (kind 'poo-flow.organization-bundle-kernel-diagnostic.v1)
      (code code-value) (expected expected-value) (observed observed-value)))

(def (kernel-receipt operation-value accepted-value? code-value
                     before-identity-value after-identity-value
                     before-epoch-value after-epoch-value
                     validation-receipt-value diagnostics-value)
  (.o (kind 'poo-flow.organization-bundle-kernel-receipt)
      (schema +poo-flow-organization-bundle-kernel-receipt-schema+)
      (operation operation-value) (accepted? accepted-value?) (code code-value)
      (before-identity before-identity-value)
      (after-identity after-identity-value)
      (before-epoch before-epoch-value) (after-epoch after-epoch-value)
      (validation-receipt validation-receipt-value)
      (diagnostics diagnostics-value)))

(def (kernel-state phase-value bundle-value canonical-value identity-value
                   epoch-value previous-identity-value operation-value
                   validation-receipt-value)
  (.o (kind 'poo-flow.organization-bundle-kernel-state)
      (schema +poo-flow-organization-bundle-kernel-state-schema+)
      (phase phase-value) (bundle bundle-value)
      (canonical-payload canonical-value) (identity identity-value)
      (epoch epoch-value) (previous-identity previous-identity-value)
      (operation operation-value)
      (validation-receipt validation-receipt-value)))

(def (kernel-identity=? left right)
  (and left right
       (equal? (poo-flow-organization-bundle-identity->alist left)
               (poo-flow-organization-bundle-identity->alist right))))

(def (poo-flow-organization-bundle-kernel-open bundle)
  (with-catch
   (lambda (_failure)
     (values #f (kernel-receipt 'open #f 'kernel-canonicalization-failed
                                #f #f #f #f #f
                                (list (kernel-diagnostic
                                       'kernel-canonicalization-failed
                                       'canonical-bundle 'invalid)))))
   (lambda ()
     (let* ((canonical (poo-flow-organization-bundle-normalize bundle))
            (identity (poo-flow-organization-bundle-identity bundle))
            (state (kernel-state 'candidate bundle canonical identity 0 #f
                                 'open #f)))
       (values state (kernel-receipt 'open #t 'kernel-opened #f identity
                                     #f 0 #f '()))))))

(def (kernel-phase-allowed? state phases)
  (memq (.ref state 'phase) phases))

(def (poo-flow-organization-bundle-kernel-validate state)
  (if (not (kernel-phase-allowed? state '(candidate validated)))
    (values #f (kernel-receipt 'validate #f 'kernel-invalid-phase
                               (.ref state 'identity) #f (.ref state 'epoch) #f
                               #f (list (kernel-diagnostic
                                         'kernel-invalid-phase
                                         '(candidate validated)
                                         (.ref state 'phase)))))
    (let* ((bundle (.ref state 'bundle))
           (validation (poo-flow-organization-bundle-validate
                        bundle (.ref state 'identity))))
      (if (poo-flow-organization-validation-accepted? validation)
        (let (next (kernel-state 'validated bundle
                                 (.ref state 'canonical-payload)
                                 (.ref state 'identity) (.ref state 'epoch)
                                 (.ref state 'previous-identity) 'validate
                                 validation))
          (values next (kernel-receipt 'validate #t 'kernel-validated
                                       (.ref state 'identity) (.ref state 'identity)
                                       (.ref state 'epoch) (.ref state 'epoch)
                                       validation '())))
        (values #f (kernel-receipt 'validate #f 'kernel-bundle-rejected
                                   (.ref state 'identity) #f (.ref state 'epoch) #f
                                   validation '()))))))

(def (kernel-reject-advance state code expected observed)
  (values #f (kernel-receipt 'advance #f code (.ref state 'identity) #f
                             (.ref state 'epoch) #f #f
                             (list (kernel-diagnostic code expected observed)))))

;; : (-> PooBundleKernelState MaybeState PooBundleKernelReceipt (values MaybeState PooBundleKernelReceipt))
(def (kernel-finish-validated-advance state validated validation-receipt)
  (if (not validated)
    (values #f (kernel-receipt 'advance #f 'kernel-next-bundle-rejected
                               (.ref state 'identity) #f
                               (.ref state 'epoch) #f
                               (.ref validation-receipt 'validation-receipt)
                               '()))
    (let* ((next-epoch (+ (.ref state 'epoch) 1))
           (next (kernel-state 'advanced (.ref validated 'bundle)
                               (.ref validated 'canonical-payload)
                               (.ref validated 'identity) next-epoch
                               (.ref state 'identity) 'advance
                               (.ref validated 'validation-receipt))))
      (values next (kernel-receipt 'advance #t 'kernel-advanced
                                   (.ref state 'identity)
                                   (.ref next 'identity)
                                   (.ref state 'epoch) next-epoch
                                   (.ref next 'validation-receipt) '())))))

;; : (-> PooBundleKernelState PooBundleKernelState (values MaybeState PooBundleKernelReceipt))
(def (kernel-finish-opened-advance state opened)
  (if (equal? (.ref opened 'canonical-payload)
              (.ref state 'canonical-payload))
    (values state (kernel-receipt 'advance #t 'kernel-noop
                                  (.ref state 'identity) (.ref state 'identity)
                                  (.ref state 'epoch) (.ref state 'epoch)
                                  #f '()))
    (let-values (((validated validation-receipt)
                  (poo-flow-organization-bundle-kernel-validate opened)))
      (kernel-finish-validated-advance state validated validation-receipt))))

;; : (-> PooBundleKernelState PooOrganizationBundle (values MaybeState PooBundleKernelReceipt))
(def (kernel-advance-next-bundle state next-bundle)
  (let-values (((opened open-receipt)
                (poo-flow-organization-bundle-kernel-open next-bundle)))
    (if opened
      (kernel-finish-opened-advance state opened)
      (values #f open-receipt))))

(def (poo-flow-organization-bundle-kernel-advance state expected-identity
                                                  expected-epoch next-bundle)
  (cond
   ((not (kernel-phase-allowed? state '(validated advanced)))
    (kernel-reject-advance state 'kernel-invalid-phase
                           '(validated advanced) (.ref state 'phase)))
   ((not (kernel-identity=? expected-identity (.ref state 'identity)))
    (kernel-reject-advance state 'kernel-identity-conflict
                           (poo-flow-organization-bundle-identity->alist
                            (.ref state 'identity))
                           (and expected-identity
                                (poo-flow-organization-bundle-identity->alist
                                 expected-identity))))
   ((not (equal? expected-epoch (.ref state 'epoch)))
    (kernel-reject-advance state 'kernel-stale-epoch
                           (.ref state 'epoch) expected-epoch))
   (else
    (kernel-advance-next-bundle state next-bundle))))
