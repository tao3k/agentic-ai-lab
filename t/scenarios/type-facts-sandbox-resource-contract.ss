;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: scenario test for native POO resource validation receipts.

(import (only-in :clan/poo/object .o))

(eval '(import "./modules/sandbox-core/resource-contract.ss"))

;; : (-> AgenticAILabTypeFactsSandboxScenarioExpr AgenticAILabTypeFactsSandboxScenarioValue)
(def (type-facts-sandbox-scenario-eval expr)
  (eval expr))

(unless
 (type-facts-sandbox-scenario-eval
  '(let (valid-validation
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation
          agentic-ai-lab-runtime-volume-resources-prototype))
     (agentic-ai-lab-sandbox-resources-prototype-contract-validation?
      valid-validation)))
  (error "sandbox resource validation should return a native POO receipt"))

(unless
 (type-facts-sandbox-scenario-eval
  '(let (valid-validation
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation
          agentic-ai-lab-runtime-volume-resources-prototype))
     (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
      valid-validation)))
  (error "runtime volume resource prototype should pass typed validation"))

(unless
 (type-facts-sandbox-scenario-eval
  '(let* ((valid-validation
           (agentic-ai-lab-sandbox-resources-prototype-contract-validation
            agentic-ai-lab-runtime-volume-resources-prototype))
          (row
           (agentic-ai-lab-sandbox-resources-prototype-contract-validation->alist
            valid-validation)))
     (and (assq 'type-facts row)
          (assq 'lean-fact-contracts row)
          (eq? (cdr (assq 'runtime-executed row)) #f))))
 (error "typed validation projection should expose type and Lean facts"))

(when
 (type-facts-sandbox-scenario-eval
  '(let (invalid-validation
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation
          (.o filesystem: agentic-ai-lab-runtime-volume-filesystem-prototype
              cpu: 2)))
     (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
      invalid-validation)))
  (error "resource prototype without memory should fail typed validation"))
