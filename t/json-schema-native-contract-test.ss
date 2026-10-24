;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: JSON Schema emits and validates native POO Contracts directly.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test)

(def (json-schema-native-eval expr)
  (eval expr))

(export json-schema-native-contract-test)

(def json-schema-native-contract-test
  (test-suite "json-schema-native-contract-test"
    (yuanxu-test-case "validates the native contract"
      (eval '(import "./core/modules/json-schema/json-schema-receipt.ss"))
      (eval '(import "./core/modules/json-schema/json-schema-validate.ss"))
      (eval '(import :yuanxu/module-system/schema/slot-contracts))
      (eval '(import "./core/type-facts/objects.ss"))
      (eval '(import :clan/poo/mop))
      (json-schema-native-eval
 '(def +json-schema-native-artifact+
    (yuanxu-json-schema->contract-artifact
     '((type . "object")
       (required . ("name"))
       (properties . ((name . ((type . "string"))))))
     '((owner . contract-test)
       (object-kind . AgenticAILabJsonSchemaNativeFixture)
       (object-key . json-schema/native-fixture)))))

(unless
 (json-schema-native-eval
  '(let (contract
         (yuanxu-json-schema-contract-artifact-object-contract
          +json-schema-native-artifact+))
     (and (element? Type contract)
          (element? contract '((name . "flow")))
          (not (element? contract '((name . 42))))
          (= (length (yuanxu-object-contract->type-facts contract)) 1)
          (= (length (yuanxu-object-contract->lean-fact-contracts contract))
             1))))
 (error "JSON Schema should emit a native Contract with proof projections"))

(unless
 (json-schema-native-eval
  '(yuanxu-json-schema-object-contract-validation-valid?
    (yuanxu-json-schema-contract-artifact-validate
     +json-schema-native-artifact+
     '((name . "flow")))))
 (error "native JSON Schema validation should admit a valid candidate"))

(when
 (json-schema-native-eval
  '(yuanxu-json-schema-object-contract-validation-valid?
    (yuanxu-json-schema-contract-artifact-validate
     +json-schema-native-artifact+
     '((name . 42)))))
 (error "native JSON Schema validation should reject an invalid candidate")))))
