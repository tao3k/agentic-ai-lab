;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native policy-catalog validation receipts.

(import (only-in :clan/poo/object .o .ref object?)
        :core/utilities/final-projection-syntax
        :poo-flow/modules/session/objects
        :poo-flow/modules/session/policy
        :poo-flow/modules/tool-core/objects-catalog
        :poo-flow/modules/tool-core/objects-policy-refs
        :poo-flow/modules/tool-core/objects-support
        :poo-flow/modules/tool-core/objects-validation)

(export +poo-flow-tool-core-policy-validation-receipt-kind+
        poo-flow-tool-policy-catalog-validation-receipt
        poo-flow-tool-policy-catalog-validation-receipt?
        poo-flow-tool-policy-catalog-validation-receipt-valid?
        poo-flow-tool-policy-catalog-validation-receipt-diagnostics
        poo-flow-tool-policy-catalog-validation-receipt->alist)

(def +poo-flow-tool-core-policy-validation-receipt-kind+
  'poo-flow.tool-core.policy-catalog-validation-receipt)

;; : (-> Symbol PooToolCatalog PooSessionPolicy PooSessionPolicy [Alist] PooToolPolicyCatalogValidationReceipt)
(def (poo-flow-tool-policy-catalog-validation-receipt validation-id catalog
                                                      agent-policy hook-policy
                                                      . maybe-metadata)
  (poo-flow-session-require "tool validation id must be a symbol"
                            (symbol? validation-id) validation-id)
  (poo-flow-session-require "tool validation requires a catalog"
                            (poo-flow-tool-catalog? catalog) catalog)
  (poo-flow-session-require "tool validation requires agent tool policy"
                            (poo-flow-session-policy? agent-policy) agent-policy)
  (poo-flow-session-require "tool validation requires hook tool policy"
                            (poo-flow-session-policy? hook-policy) hook-policy)
  (let* ((policy-refs
          (poo-flow-tool-merge-policy-tool-refs
           (poo-flow-tool-policy-tool-refs agent-policy)
           (poo-flow-tool-policy-tool-refs hook-policy)))
         (summary (poo-flow-tool-policy-catalog-validation-summary catalog policy-refs))
         (action-bundle
          (poo-flow-tool-action-mismatch-bundle
           catalog (poo-flow-tool-policy-grants agent-policy)
           (poo-flow-tool-policy-grants hook-policy)))
         (action-diagnostics
          (poo-flow-session-alist-ref action-bundle 'diagnostics '()))
         (diagnostics
          (append (poo-flow-session-alist-ref summary 'diagnostics '())
                  action-diagnostics))
         ;; Keep lexical inputs distinct from `.o` fixed-point slot bindings.
         (validation-id-value validation-id)
         (diagnostic-values diagnostics)
         (metadata-value
          (if (null? maybe-metadata) '() (car maybe-metadata))))
    (.o (kind +poo-flow-tool-core-policy-validation-receipt-kind+)
        (schema 'poo-flow.modules.tool-core.policy-catalog-validation.v1)
        (validation-id validation-id-value)
        (catalog-ref (poo-flow-tool-catalog-ref catalog))
        (catalog-tool-count (poo-flow-tool-catalog-tool-count catalog))
        (catalog-tool-refs (poo-flow-tool-catalog-tool-refs catalog))
        (agent-tool-policy-ref (poo-flow-session-policy-name agent-policy))
        (hook-tool-policy-ref (poo-flow-session-policy-name hook-policy))
        (policy-tool-refs policy-refs)
        (resolved-tool-refs
         (poo-flow-session-alist-ref summary 'resolved-tool-refs '()))
        (unresolved-tool-refs
         (poo-flow-session-alist-ref summary 'unresolved-tool-refs '()))
        (sandbox-required-tool-refs
         (poo-flow-session-alist-ref summary 'sandbox-required-tool-refs '()))
        (action-mismatch-grants
         (poo-flow-session-alist-ref action-bundle 'rows '()))
        (valid? (null? diagnostic-values))
        (diagnostic-count (length diagnostic-values))
        (diagnostics diagnostic-values)
        (runtime-owner "marlin-agent-core")
        (runtime-executed #f)
        (metadata metadata-value))))

;; : (-> Object Boolean)
(def (poo-flow-tool-policy-catalog-validation-receipt? value)
  (and (object? value)
       (eq? (poo-flow-tool-slot value 'kind #f)
            +poo-flow-tool-core-policy-validation-receipt-kind+)))

;; : (-> PooToolPolicyCatalogValidationReceipt Boolean)
(def (poo-flow-tool-policy-catalog-validation-receipt-valid? receipt)
  (.ref receipt 'valid?))

;; : (-> PooToolPolicyCatalogValidationReceipt [Alist])
(def (poo-flow-tool-policy-catalog-validation-receipt-diagnostics receipt)
  (.ref receipt 'diagnostics))

(defpoo-final-projection
  poo-flow-tool-policy-catalog-validation-receipt->alist (receipt)
  (bindings ((checked-receipt
              (poo-flow-session-require
               "tool validation projection requires a receipt"
               (poo-flow-tool-policy-catalog-validation-receipt? receipt)
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
