;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: JSON Schema emits and validates POO Contracts directly.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :std/encoding/json JSONReadOptions string->json)
        :std/test)

(def (json-schema-gerbil-eval expr)
  (eval expr))

(export json-schema-poo-contract-test)

(def json-schema-poo-contract-test
  (test-suite "json-schema-poo-contract-test"
    (yuanxu-test-case "validates the runtime contract"
      (eval '(import "./core/modules/json-schema/json-schema-receipt.ss"))
      (eval '(import "./core/modules/json-schema/json-schema-validate.ss"))
      (eval '(import :yuanxu/module-system/schema/slot-contracts))
      (eval '(import :yuanxu/object-types/facts))
      (eval '(import :clan/poo/mop :clan/poo/object))
      (json-schema-gerbil-eval
 '(def +json-schema-host-artifact+
    (yuanxu-json-schema->contract-artifact
     '((type . "object")
       (required . ("name"))
       (properties . ((name . ((type . "string"))))))
     '((owner . contract-test)
       (object-kind . AgenticAILabJsonSchemaRuntimeFixture)
       (object-key . json-schema/runtime-fixture)))))

(unless
 (json-schema-gerbil-eval
  '(let (contract
         (yuanxu-json-schema-contract-artifact-object-contract
          +json-schema-host-artifact+))
     (and (element? Type contract)
          (element? contract (.o name: "flow"))
          (not (element? contract (.o name: 42)))
          (= (length (yuanxu-object-contract->type-facts contract)) 1)
          (= (length (yuanxu-object-contract->lean-fact-contracts contract))
             1))))
 (error "JSON Schema should emit a Contract with proof projections"))

(unless
 (json-schema-gerbil-eval
  '(yuanxu-json-schema-object-contract-validation-valid?
    (yuanxu-json-schema-contract-artifact-validate
     +json-schema-host-artifact+
     '((name . "flow")))))
 (error "runtime JSON Schema validation should admit a valid candidate"))

(when
 (json-schema-gerbil-eval
  '(yuanxu-json-schema-object-contract-validation-valid?
    (yuanxu-json-schema-contract-artifact-validate
     +json-schema-host-artifact+
     '((name . 42)))))
 (error "runtime JSON Schema validation should reject an invalid candidate")))))
