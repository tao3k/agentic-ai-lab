;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native policy-catalog validation receipts.

(import (only-in :clan/poo/object .o .ref object?)
        :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy
        :agentic-ai-lab/modules/tool-core/objects-catalog
        :agentic-ai-lab/modules/tool-core/objects-policy-refs
        :agentic-ai-lab/modules/tool-core/objects-support
        :agentic-ai-lab/modules/tool-core/objects-validation)

(export +agentic-ai-lab-tool-core-policy-validation-receipt-kind+
        agentic-ai-lab-tool-policy-catalog-validation-receipt
        agentic-ai-lab-tool-policy-catalog-validation-receipt?
        agentic-ai-lab-tool-policy-catalog-validation-receipt-valid?
        agentic-ai-lab-tool-policy-catalog-validation-receipt-diagnostics
        agentic-ai-lab-tool-policy-catalog-validation-receipt->alist)

(def +agentic-ai-lab-tool-core-policy-validation-receipt-kind+
  'agentic-ai-lab.tool-core.policy-catalog-validation-receipt)

;; : (-> Symbol PooToolCatalog PooSessionPolicy PooSessionPolicy [Alist] PooToolPolicyCatalogValidationReceipt)
(def (agentic-ai-lab-tool-policy-catalog-validation-receipt validation-id catalog
                                                      agent-policy hook-policy
                                                      . maybe-metadata)
  (agentic-ai-lab-session-require "tool validation id must be a symbol"
                            (symbol? validation-id) validation-id)
  (agentic-ai-lab-session-require "tool validation requires a catalog"
                            (agentic-ai-lab-tool-catalog? catalog) catalog)
  (agentic-ai-lab-session-require "tool validation requires agent tool policy"
                            (agentic-ai-lab-session-policy? agent-policy) agent-policy)
  (agentic-ai-lab-session-require "tool validation requires hook tool policy"
                            (agentic-ai-lab-session-policy? hook-policy) hook-policy)
  (let* ((policy-refs
          (agentic-ai-lab-tool-merge-policy-tool-refs
           (agentic-ai-lab-tool-policy-tool-refs agent-policy)
           (agentic-ai-lab-tool-policy-tool-refs hook-policy)))
         (summary (agentic-ai-lab-tool-policy-catalog-validation-summary catalog policy-refs))
         (action-bundle
          (agentic-ai-lab-tool-action-mismatch-bundle
           catalog (agentic-ai-lab-tool-policy-grants agent-policy)
           (agentic-ai-lab-tool-policy-grants hook-policy)))
         (action-diagnostics
          (agentic-ai-lab-session-alist-ref action-bundle 'diagnostics '()))
         (diagnostics
          (append (agentic-ai-lab-session-alist-ref summary 'diagnostics '())
                  action-diagnostics))
         ;; Keep lexical inputs distinct from `.o` fixed-point slot bindings.
         (validation-id-value validation-id)
         (diagnostic-values diagnostics)
         (metadata-value
          (if (null? maybe-metadata) '() (car maybe-metadata))))
    (.o (kind +agentic-ai-lab-tool-core-policy-validation-receipt-kind+)
        (schema 'agentic-ai-lab.modules.tool-core.policy-catalog-validation.v1)
        (validation-id validation-id-value)
        (catalog-ref (agentic-ai-lab-tool-catalog-ref catalog))
        (catalog-tool-count (agentic-ai-lab-tool-catalog-tool-count catalog))
        (catalog-tool-refs (agentic-ai-lab-tool-catalog-tool-refs catalog))
        (agent-tool-policy-ref (agentic-ai-lab-session-policy-name agent-policy))
        (hook-tool-policy-ref (agentic-ai-lab-session-policy-name hook-policy))
        (policy-tool-refs policy-refs)
        (resolved-tool-refs
         (agentic-ai-lab-session-alist-ref summary 'resolved-tool-refs '()))
        (unresolved-tool-refs
         (agentic-ai-lab-session-alist-ref summary 'unresolved-tool-refs '()))
        (sandbox-required-tool-refs
         (agentic-ai-lab-session-alist-ref summary 'sandbox-required-tool-refs '()))
        (action-mismatch-grants
         (agentic-ai-lab-session-alist-ref action-bundle 'rows '()))
        (valid? (null? diagnostic-values))
        (diagnostic-count (length diagnostic-values))
        (diagnostics diagnostic-values)
        (runtime-owner "marlin-agent-core")
        (runtime-executed #f)
        (metadata metadata-value))))

;; : (-> Object Boolean)
(def (agentic-ai-lab-tool-policy-catalog-validation-receipt? value)
  (and (object? value)
       (eq? (agentic-ai-lab-tool-slot value 'kind #f)
            +agentic-ai-lab-tool-core-policy-validation-receipt-kind+)))

;; : (-> PooToolPolicyCatalogValidationReceipt Boolean)
(def (agentic-ai-lab-tool-policy-catalog-validation-receipt-valid? receipt)
  (.ref receipt 'valid?))

;; : (-> PooToolPolicyCatalogValidationReceipt [Alist])
(def (agentic-ai-lab-tool-policy-catalog-validation-receipt-diagnostics receipt)
  (.ref receipt 'diagnostics))

(defpoo-final-projection
  agentic-ai-lab-tool-policy-catalog-validation-receipt->alist (receipt)
  (bindings ((checked-receipt
              (agentic-ai-lab-session-require
               "tool validation projection requires a receipt"
               (agentic-ai-lab-tool-policy-catalog-validation-receipt? receipt)
               receipt))))
  (fields ((kind (.ref checked-receipt 'kind))
           (schema (.ref checked-receipt 'schema))
           (validation-id (.ref checked-receipt 'validation-id))
           (catalog-ref (.ref checked-receipt 'catalog-ref))
           (catalog-tool-count (.ref checked-receipt 'catalog-tool-count))
           (catalog-tool-refs (.ref checked-receipt 'catalog-tool-refs))
           (agent-tool-policy-ref (.ref checked-receipt 'agent-tool-policy-ref))
           (hook-tool-policy-ref (.ref checked-receipt 'hook-tool-policy-ref))
           (policy-tool-refs (.ref checked-receipt 'policy-tool-refs))
           (resolved-tool-refs (.ref checked-receipt 'resolved-tool-refs))
           (unresolved-tool-refs (.ref checked-receipt 'unresolved-tool-refs))
           (sandbox-required-tool-refs
            (.ref checked-receipt 'sandbox-required-tool-refs))
           (action-mismatch-grants (.ref checked-receipt 'action-mismatch-grants))
           (valid? (.ref checked-receipt 'valid?))
           (diagnostic-count (.ref checked-receipt 'diagnostic-count))
           (diagnostics (.ref checked-receipt 'diagnostics))
           (runtime-owner (.ref checked-receipt 'runtime-owner))
           (runtime-executed (.ref checked-receipt 'runtime-executed))
           (metadata (.ref checked-receipt 'metadata)))))
