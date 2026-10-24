;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: turns canonical organization bundles into evidence-bearing contracts.
;;; Invariant: contract identity is derived from the normalized semantic bundle.
(export #t)

(import (only-in :clan/poo/object .o .ref object?)
        :agentic-ai-lab/modules/query/semantic/organization-bundle)

;; : (-> AgenticAILabOrganizationBundle AgenticAILabOrganizationBundleContract)
(def (agentic-ai-lab-organization-bundle->contract bundle)
  (let ((canonical-value (agentic-ai-lab-organization-bundle-normalize bundle))
        (identity-value (agentic-ai-lab-organization-bundle-identity bundle)))
    (.o (kind 'agentic-ai-lab.organization-bundle.contract.v1)
        (schema +agentic-ai-lab-organization-bundle-schema+)
        (canonical canonical-value)
        (identity identity-value))))

;; : (-> Object Boolean)
(def (agentic-ai-lab-organization-bundle-contract? value)
  (and (object? value)
       (with-catch
        (lambda (_failure) #f)
        (lambda ()
          (eq? (.ref value 'kind)
               'agentic-ai-lab.organization-bundle.contract.v1)))))

;; : (-> AgenticAILabOrganizationBundleContract Symbol Object)
(def (agentic-ai-lab-organization-bundle-contract-ref contract slot)
  (unless (agentic-ai-lab-organization-bundle-contract? contract)
    (error "expected organization Bundle contract" contract))
  (case slot
    ((schema canonical identity) (.ref contract slot))
    (else (error "unknown organization Bundle contract slot" slot))))
