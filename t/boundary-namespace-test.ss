;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: scenario test for P0 boundary namespace validation.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test)

;; : (-> AgenticAILabBoundaryNamespaceExpr AgenticAILabBoundaryNamespaceValue)
(def (boundary-eval expr)
  (eval expr))

;; : (-> Alist Symbol AgenticAILabAlistValue)
(def (boundary-test-ref row key)
  (cdr (assq key row)))

;; : (-> Alist Symbol Symbol AgenticAILabAlistValue)
(def (boundary-test-nested-ref row outer-key inner-key)
  (boundary-test-ref (boundary-test-ref row outer-key) inner-key))

(export boundary-namespace-test)

(def boundary-namespace-test
  (test-suite "boundary-namespace-test"
    (yuanxu-test-case "validates the native contract"
      (eval '(import "./modules/workflow/contracts/boundary-namespace.ss"))
      (def author-namespace
  (boundary-eval
   '(agentic-ai-lab-boundary-namespace 'author '(init))))

(unless (eq? (boundary-eval
              `(agentic-ai-lab-namespace-descriptor->symbol ',author-namespace))
             'agentic-ai-lab.author.init)
  (error "boundary namespace should render agentic-ai-lab.<boundary>.*"))

(unless (boundary-eval
         `(agentic-ai-lab-boundary-namespace-validation-valid?
           (agentic-ai-lab-boundary-namespace-contract-validation ',author-namespace)))
  (error "author boundary namespace should validate"))

(def sandbox-namespace
  (boundary-eval
   '(agentic-ai-lab-category-module-namespace 'sandbox 'nono-sandbox)))

(unless (eq? (boundary-eval
              `(agentic-ai-lab-namespace-descriptor->symbol ',sandbox-namespace))
             'agentic-ai-lab.sandbox.nono-sandbox)
  (error "category module namespace should render agentic-ai-lab.<category>.<module>"))

(unless (eq? (boundary-eval
              `(agentic-ai-lab-namespace-descriptor-repair-layer ',sandbox-namespace))
             'author)
  (error "category module namespaces should repair at author layer"))

(def invalid-namespace
  (boundary-eval
   '(agentic-ai-lab-boundary-namespace 'core)))

(when (boundary-eval
       `(agentic-ai-lab-boundary-namespace-validation-valid?
         (agentic-ai-lab-boundary-namespace-contract-validation ',invalid-namespace)))
  (error "non-canonical boundary namespace should fail validation"))

(def runtime-namespace
  (boundary-eval
   '(agentic-ai-lab-boundary-namespace 'runtime)))

(unless (boundary-eval
         `(agentic-ai-lab-boundary-namespace-validation-valid?
           (agentic-ai-lab-boundary-namespace-contract-validation ',runtime-namespace)))
  (error "runtime boundary namespace should validate"))

(when (boundary-eval
       `(agentic-ai-lab-namespace-descriptor-repair-layer ',runtime-namespace))
  (error "runtime namespace should not be a normal agent repair target"))

(def stale-modules-namespace
  (boundary-eval
   '(agentic-ai-lab-category-module-namespace 'modules 'nono-sandbox)))

(when (boundary-eval
       `(agentic-ai-lab-boundary-namespace-validation-valid?
         (agentic-ai-lab-boundary-namespace-contract-validation
          ',stale-modules-namespace)))
  (error "agentic-ai-lab.modules.* should not be a public category namespace"))

(let (row
      (boundary-eval
       `(agentic-ai-lab-boundary-namespace-validation->alist
         (agentic-ai-lab-boundary-namespace-contract-validation ',author-namespace))))
  (unless (and (assq 'type-facts row)
               (assq 'lean-fact-contracts row)
               (assq 'descriptor row))
    (error "boundary namespace validation should project type/proof facts")))

(let (feedback
      (boundary-eval
       `(agentic-ai-lab-boundary-namespace-agent-feedback
         (agentic-ai-lab-boundary-namespace-contract-validation ',author-namespace))))
  (unless (eq? (boundary-test-ref feedback 'next-action)
               'accept-boundary-namespace)
    (error "valid namespace feedback should accept the namespace")))

(let (feedback
      (boundary-eval
       `(agentic-ai-lab-boundary-namespace-agent-feedback
         (agentic-ai-lab-boundary-namespace-contract-validation
          ',stale-modules-namespace))))
  (unless (and (eq? (boundary-test-ref feedback 'next-action)
                    'repair-boundary-namespace)
               (eq? (boundary-test-ref feedback 'family)
                    'observability/receipt)
               (eq? (boundary-test-nested-ref feedback 'graph 'kind)
                    'boundary-namespace)
               (eq? (boundary-test-nested-ref feedback 'repair 'target-layer)
                    'author)
               (eq? (boundary-test-nested-ref feedback 'readiness 'state)
                    'blocked)
               (member 'disallowed-public-category
                       (boundary-test-ref feedback 'diagnostic-codes)))
    (error "invalid namespace feedback should explain repair action"))))))
