;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: hygienic macros for core receipt/projection alists.
;;; Invariant: generated functions are final boundary projections only; public
;;; object construction remains ordinary core code.

(import :core/utilities/product-syntax)

(export poo-flow-product-rows/tail
        poo-flow-product-rows-into/rev
        poo-flow-product-field-rows
        poo-flow-product-field-rows/tail
        defpoo-core-receipt-projection)

;; defpoo-core-receipt-projection
;;   : (-> Syntax Definition)
;;   | contract: generate fixed core receipt projection functions
;;   | result: the generated function returns an ordered core receipt alist
;;   | doc m%
;;       The call site names the function, arguments, local bindings, and every
;;       projected field so expansion stays ordinary Scheme. Field names are
;;       fixed alist keys, not expressions, and generated functions keep
;;       projection-only behavior at the core receipt boundary.
;;
;;       # Examples
;;
;;       ```scheme
;;       (defpoo-core-receipt-projection make-row (value)
;;         (bindings ((status-value 'ok)))
;;         (fields ((kind 'receipt)
;;                  (status status-value))))
;;       ;; => (make-row 1)
;;       ;; => ((kind . receipt) (status . ok))
;;       ```
;;     %
(defrules defpoo-core-receipt-projection
  (bindings fields)
  ((_ constructor (argument ...)
      (bindings ((binding-name binding-expr) ...))
      (fields ((field-key field-expr) ...)))
   (def (constructor argument ...)
     (let* ((binding-name binding-expr) ...)
       (list (cons 'field-key field-expr) ...)))))
