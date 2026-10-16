;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: turns canonical organization bundles into evidence-bearing contracts.
;;; Invariant: contract identity is derived from the normalized semantic bundle.
(export #t)

(import (only-in :clan/poo/object .o .ref object?)
        :poo-flow/modules/query/semantic/organization-bundle)

;; : (-> PooFlowOrganizationBundle PooFlowOrganizationBundleContract)
(def (poo-flow-organization-bundle->contract bundle)
  (let ((canonical-value (poo-flow-organization-bundle-normalize bundle))
        (identity-value (poo-flow-organization-bundle-identity bundle)))
    (.o (kind 'poo-flow.organization-bundle.contract.v1)
        (schema +poo-flow-organization-bundle-schema+)
        (canonical canonical-value)
        (identity identity-value))))

;; : (-> Object Boolean)
(def (poo-flow-organization-bundle-contract? value)
  (and (object? value)
       (with-catch
        (lambda (_failure) #f)
        (lambda ()
          (eq? (.ref value 'kind)
               'poo-flow.organization-bundle.contract.v1)))))

;; : (-> PooFlowOrganizationBundleContract Symbol Object)
(def (poo-flow-organization-bundle-contract-ref contract slot)
  (unless (poo-flow-organization-bundle-contract? contract)
    (error "expected organization Bundle contract" contract))
  (case slot
    ((schema canonical identity) (.ref contract slot))
    (else (error "unknown organization Bundle contract slot" slot))))
