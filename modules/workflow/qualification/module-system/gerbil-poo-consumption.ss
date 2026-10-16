;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: records the concrete gerbil-poo provider surface consumed by POO Flow.
;;; Invariant: provider validation uses native POO objects rather than parallel adapters.
(import (only-in :clan/poo/object
                 .o
                 .@
                 .ref
                 object?)
        (only-in :core/utilities/functional
                 poo-flow-set-subset?))

(export +poo-flow-gerbil-poo-provider-label+
        +poo-flow-gerbil-poo-resolution-receipt-label+
        +poo-flow-gerbil-poo-required-api+
        poo-flow-gerbil-poo-consumption-prototype
        poo-flow-gerbil-poo-consumption-manifest
        poo-flow-gerbil-poo-api-closed?)

(def +poo-flow-gerbil-poo-provider-label+
  "//:gerbil_poo_package")

(def +poo-flow-gerbil-poo-resolution-receipt-label+
  "@gerbil_poo_sources//:source_resolution_receipt")

(def +poo-flow-gerbil-poo-required-api+
  '(.o .def .@ .get .ref .slot? .has? .all-slots .call
    .cc .extend .mix .+
    .put! .set! .putslot! .putdefault! .def! uninstantiate-object!
    compute-precedence-list! $constant-slot-spec $computed-slot-spec
    NoApplicableMethod?
    .defgeneric define-type
    Type Type. TypeError? element? validate raise-type-error
    object? object<-alist))

(def poo-flow-gerbil-poo-consumption-prototype
  (.o (kind 'gerbil-poo-consumption)))

;; : (-> POOObject)
(def (poo-flow-gerbil-poo-consumption-manifest)
  (.o (kind 'gerbil-poo-consumption)
      (provider-label +poo-flow-gerbil-poo-provider-label+)
      (source-resolution-receipt-label
       +poo-flow-gerbil-poo-resolution-receipt-label+)
      (required-api +poo-flow-gerbil-poo-required-api+)))

;; poo-flow-gerbil-poo-api-closed?
;;   : (-> [Symbol] Boolean)
;;   | doc m%
;;       Verify that the observed Gerbil POO surface is exactly the required API.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-gerbil-poo-api-closed? +poo-flow-gerbil-poo-required-api+)
;;       ;; => #t
;;       ```
;;     %
(def (poo-flow-gerbil-poo-api-closed? observed-api)
  (and (= (length observed-api)
          (length +poo-flow-gerbil-poo-required-api+))
       (poo-flow-set-subset?
        +poo-flow-gerbil-poo-required-api+
        observed-api)))
