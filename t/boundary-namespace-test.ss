;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Contract: scenario test for P0 boundary namespace validation.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test)

;; : (-> PooFlowBoundaryNamespaceExpr PooFlowBoundaryNamespaceValue)
(def (boundary-eval expr)
  (eval expr))

;; : (-> Alist Symbol PooFlowAlistValue)
(def (boundary-test-ref row key)
  (cdr (assq key row)))

;; : (-> Alist Symbol Symbol PooFlowAlistValue)
(def (boundary-test-nested-ref row outer-key inner-key)
  (boundary-test-ref (boundary-test-ref row outer-key) inner-key))

(export boundary-namespace-test)

(def boundary-namespace-test
  (test-suite "boundary-namespace-test"
    (poo-flow-test-case "validates the native contract"
      (eval '(import "./modules/workflow/contracts/boundary-namespace.ss"))
      (def author-namespace
  (boundary-eval
   '(poo-flow-boundary-namespace 'author '(init))))

(unless (eq? (boundary-eval
              `(poo-flow-namespace-descriptor->symbol ',author-namespace))
             'poo-flow.author.init)
  (error "boundary namespace should render poo-flow.<boundary>.*"))

(unless (boundary-eval
         `(poo-flow-boundary-namespace-validation-valid?
           (poo-flow-boundary-namespace-contract-validation ',author-namespace)))
  (error "author boundary namespace should validate"))

(def sandbox-namespace
  (boundary-eval
   '(poo-flow-category-module-namespace 'sandbox 'nono-sandbox)))

(unless (eq? (boundary-eval
              `(poo-flow-namespace-descriptor->symbol ',sandbox-namespace))
             'poo-flow.sandbox.nono-sandbox)
  (error "category module namespace should render poo-flow.<category>.<module>"))

(unless (eq? (boundary-eval
              `(poo-flow-namespace-descriptor-repair-layer ',sandbox-namespace))
             'author)
  (error "category module namespaces should repair at author layer"))

(def invalid-namespace
  (boundary-eval
   '(poo-flow-boundary-namespace 'core)))

(when (boundary-eval
       `(poo-flow-boundary-namespace-validation-valid?
         (poo-flow-boundary-namespace-contract-validation ',invalid-namespace)))
  (error "non-canonical boundary namespace should fail validation"))

(def runtime-namespace
  (boundary-eval
   '(poo-flow-boundary-namespace 'runtime)))

(unless (boundary-eval
         `(poo-flow-boundary-namespace-validation-valid?
           (poo-flow-boundary-namespace-contract-validation ',runtime-namespace)))
  (error "runtime boundary namespace should validate"))

(when (boundary-eval
       `(poo-flow-namespace-descriptor-repair-layer ',runtime-namespace))
  (error "runtime namespace should not be a normal agent repair target"))

(def stale-modules-namespace
  (boundary-eval
   '(poo-flow-category-module-namespace 'modules 'nono-sandbox)))

(when (boundary-eval
       `(poo-flow-boundary-namespace-validation-valid?
         (poo-flow-boundary-namespace-contract-validation
          ',stale-modules-namespace)))
  (error "poo-flow.modules.* should not be a public category namespace"))

(let (row
      (boundary-eval
       `(poo-flow-boundary-namespace-validation->alist
         (poo-flow-boundary-namespace-contract-validation ',author-namespace))))
  (unless (and (assq 'type-facts row)
               (assq 'lean-fact-contracts row)
               (assq 'descriptor row))
    (error "boundary namespace validation should project type/proof facts")))

(let (feedback
      (boundary-eval
       `(poo-flow-boundary-namespace-agent-feedback
         (poo-flow-boundary-namespace-contract-validation ',author-namespace))))
  (unless (eq? (boundary-test-ref feedback 'next-action)
               'accept-boundary-namespace)
    (error "valid namespace feedback should accept the namespace")))

(let (feedback
      (boundary-eval
       `(poo-flow-boundary-namespace-agent-feedback
         (poo-flow-boundary-namespace-contract-validation
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
