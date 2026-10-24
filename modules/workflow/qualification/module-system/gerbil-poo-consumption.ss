;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: records the concrete gerbil-poo provider surface consumed by Agentic AI Lab.
;;; Invariant: provider validation uses native POO objects rather than parallel adapters.
(import (only-in :clan/poo/object
                 .o
                 .@
                 .ref
                 object?)
        (only-in :yuanxu/utilities/functional
                 yuanxu-set-subset?))

(export +agentic-ai-lab-gerbil-poo-provider-label+
        +agentic-ai-lab-gerbil-poo-resolution-receipt-label+
        +agentic-ai-lab-gerbil-poo-required-api+
        agentic-ai-lab-gerbil-poo-consumption-prototype
        agentic-ai-lab-gerbil-poo-consumption-manifest
        agentic-ai-lab-gerbil-poo-api-closed?)

(def +agentic-ai-lab-gerbil-poo-provider-label+
  "//:gerbil_poo_package")

(def +agentic-ai-lab-gerbil-poo-resolution-receipt-label+
  "@gerbil_poo_sources//:source_resolution_receipt")

(def +agentic-ai-lab-gerbil-poo-required-api+
  '(.o .def .@ .get .ref .slot? .has? .all-slots .call
    .cc .extend .mix .+
    .put! .set! .putslot! .putdefault! .def! uninstantiate-object!
    compute-precedence-list! $constant-slot-spec $computed-slot-spec
    NoApplicableMethod?
    .defgeneric define-type
    Type Type. TypeError? element? validate raise-type-error
    object? object<-alist))

(def agentic-ai-lab-gerbil-poo-consumption-prototype
  (.o (kind 'gerbil-poo-consumption)))

;; : (-> POOObject)
(def (agentic-ai-lab-gerbil-poo-consumption-manifest)
  (.o (kind 'gerbil-poo-consumption)
      (provider-label +agentic-ai-lab-gerbil-poo-provider-label+)
      (source-resolution-receipt-label
       +agentic-ai-lab-gerbil-poo-resolution-receipt-label+)
      (required-api +agentic-ai-lab-gerbil-poo-required-api+)))

;; agentic-ai-lab-gerbil-poo-api-closed?
;;   : (-> [Symbol] Boolean)
;;   | doc m%
;;       Verify that the observed Gerbil POO surface is exactly the required API.
;;
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-gerbil-poo-api-closed? +agentic-ai-lab-gerbil-poo-required-api+)
;;       ;; => #t
;;       ```
;;     %
(def (agentic-ai-lab-gerbil-poo-api-closed? observed-api)
  (and (= (length observed-api)
          (length +agentic-ai-lab-gerbil-poo-required-api+))
       (yuanxu-set-subset?
        +agentic-ai-lab-gerbil-poo-required-api+
        observed-api)))
