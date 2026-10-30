;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: sandbox resources expose native POO Type/Contract descriptors.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test)

;; : (-> AgenticAILabSandboxResourceExpr AgenticAILabSandboxResourceValue)
(def (sandbox-resource-eval expr)
  (eval expr))

;; : (-> Alist Symbol Object Object)
(def (alist-ref/default entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

(export sandbox-resource-native-type-contract-test)

(def sandbox-resource-native-type-contract-test
  (test-suite "sandbox-resource-native-type-contract-test"
    (yuanxu-test-case "validates the native contract"
      (eval '(import (only-in :clan/poo/object .o)))
      (eval '(import (only-in :clan/poo/mop Type element?)))
      (eval '(import "./modules/sandbox-core/resource-contract.ss"))
      (let* ((row
        (sandbox-resource-eval
         '(agentic-ai-lab-sandbox-resources-prototype-type-contract->alist)))
       (slot-rows (alist-ref/default row 'slots '()))
       (slot-names
        (map (lambda (slot-row)
               (alist-ref/default slot-row 'slot #f))
             slot-rows)))
  (unless (and (eq? (alist-ref/default row 'object-kind #f)
                    'PooSandboxResourcesPrototype)
               (equal? slot-names
                       '(filesystem cpu ports memory timeout-ms)))
    (error "sandbox resource type contract should expose structured slot contracts")))

(unless (sandbox-resource-eval
         '(and (element? Type AgenticAILabSandboxResourcesPrototypeContract)
               (element? AgenticAILabSandboxResourcesPrototypeContract
                         agentic-ai-lab-runtime-volume-resources-prototype)))
  (error "sandbox resource contract should be native and admit valid resources"))

(when (sandbox-resource-eval
       '(element? AgenticAILabSandboxResourcesPrototypeContract
                  (.o filesystem: agentic-ai-lab-runtime-volume-filesystem-prototype
                      cpu: "two"
                      memory: "4Gi")))
  (error "native sandbox resource contract should reject an invalid cpu slot"))

(def valid-validation
  (sandbox-resource-eval
   '(agentic-ai-lab-sandbox-resources-prototype-contract-validation
     agentic-ai-lab-runtime-volume-resources-prototype)))

(unless (sandbox-resource-eval
         `(agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
           ',valid-validation))
  (error "runtime volume resources should satisfy native validation"))

(def invalid-validation
  (sandbox-resource-eval
   '(agentic-ai-lab-sandbox-resources-prototype-contract-validation
     (.o filesystem: agentic-ai-lab-runtime-volume-filesystem-prototype
         cpu: "two"
         memory: "4Gi"))))

(when (sandbox-resource-eval
       `(agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
         ',invalid-validation))
  (error "invalid cpu should fail native validation")))))
