;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: functional kernel tests cover Category/Arrow composition in Scheme.
;;; Invariant: heavy runtime execution still belongs behind runtime adapters.

(import (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-false
                 check-not-equal?
                 check-output
                 check-true
                 test-error
                 test-suite)
        (only-in :poo-flow/testing-api poo-flow-test-case)
        :poo-flow/modules/workflow/control-plane/api)

(export functional-flow-kernel-test)

;; : (-> Unit Runner)
(def (kernel-runner)
  (make-runner (make-local-eager-strategy)
               (make-request-only-adapter)))

;; : (-> Flow Value Value)
(def (kernel-run flow input)
  (run-result-value (runner-run (kernel-runner) flow input)))

;; : (-> Symbol Alist MaybeValue)
(def (functional-flow-alist-value key entries)
  (cond
   ((null? entries) #f)
   ((equal? key (caar entries)) (cdar entries))
   (else
    (functional-flow-alist-value key (cdr entries)))))

(defpoo-flow-arr macro-inc
  macro-inc
  (lambda (x) (+ x 1))
  'number
  'number)

(defpoo-flow-arr macro-double
  macro-double
  (lambda (x) (* x 2))
  'number
  'number)

(defpoo-flow-compose macro-pipeline
  macro-pipeline
  macro-inc
  macro-double)

(defpoo-flow-map macro-mapped
  macro-mapped
  macro-inc
  (lambda (x) (* x 10))
  'number)

(defpoo-flow-fanout macro-fanout
  macro-fanout
  macro-inc
  macro-double)

(defpoo-flow-dag macro-dag
  macro-dag
  macro-inc
  macro-double)

(def macro-throw
  (throw-string-flow 'macro-throw
                     "macro try failure"
                     'unit
                     'unit))

(defpoo-flow-try macro-try
  macro-try
  macro-throw)

(defpoo-flow-dag-artifacts macro-dag-receipt
  macro-dag-manifest
  macro-dag
  'macro-dag-request)

(defpoo-flow-first macro-first
  macro-first
  macro-inc
  'symbol)

(defpoo-flow-second macro-second
  macro-second
  macro-inc
  'symbol)

;;; This suite covers pure flow composition as the kernel contract beneath
;;; module and runtime adapters.
;; : TestSuite
(def functional-flow-kernel-test
  (test-suite "functional flow kernel"
    (poo-flow-test-case "exposes a POO category object for flow arrows"
      (let* ((category default-flow-category)
             (inc (flow-category-arr category
                                     'inc
                                     (lambda (x) (+ x 1))
                                     'number
                                     'number)))
        (check-equal? (flow-category? category) #t)
        (check-equal? (flow-category-name category) 'flow)
        (check-equal? (flow-category-arrow category) 'flow)
        (check-equal? (flow-category-domain category inc) 'number)
        (check-equal? (flow-category-codomain category inc) 'number)))
    (poo-flow-test-case "exposes Funflow-style required strands as POO metadata"
      (let* ((category default-flow-category)
             (registry (flow-category-strand-registry category))
             (simple (flow-strand-for-kind-in registry 'simple))
             (store (flow-strand-for-kind-in registry 'store))
             (docker (flow-strand-for-kind-in registry 'docker))
             (snapshot (flow-strand-registry->alist registry)))
        (check-equal? (flow-strand-registry? registry) #t)
        (check-equal? (flow-strand-names registry)
                      '(simple store docker))
        (check-equal? (flow-strand-task-families simple)
                      '(pure scheme))
        (check-equal? (flow-strand-route simple) 'local)
        (check-equal? (flow-strand-interpreter-owner store)
                      'rust-or-external-runtime)
        (check-equal? (flow-strand-route docker) 'adapter)
        (check-equal? (flow-strand-required? docker) #t)
        (check-equal? (functional-flow-alist-value 'runtime-executed snapshot)
                      #f)
        (check-equal? (flow-strand-registry-core-requirements registry)
                      '(arrow
                        arrow-choice
                        error-throw
                        error-try
                        io-lift
                        caching
                        runtime-handoff))))
    (poo-flow-test-case "extends flow strands with POO override semantics"
      (let* ((word-count
              (make-flow-strand-descriptor
               'word-count
               '(word-count external)
               '(text-analysis runtime-command)
               'adapter
               'rust-or-external-runtime
               #f))
             (extended (flow-strand-registry-extend
                        default-flow-strand-registry
                        word-count))
             (simple-override
              (make-flow-strand-descriptor
               'simple
               '(pure scheme custom-simple)
               '(pure-function io-continuation local-kleisli extension-hook)
               'local
               'gerbil
               #t))
             (overridden (flow-strand-registry-extend
                          extended
                          simple-override))
             (word-count-entry (flow-strand-for-kind-in extended 'word-count))
             (simple-entry (flow-strand-for-kind-in overridden 'simple)))
        (check-equal? (flow-strand-names extended)
                      '(simple store docker word-count))
        (check-equal? (flow-strand-task-families word-count-entry)
                      '(word-count external))
        (check-equal? (flow-strand-required? word-count-entry) #f)
        (check-equal? (flow-strand-names overridden)
                      '(simple store docker word-count))
        (check-equal? (flow-strand-task-families simple-entry)
                      '(pure scheme custom-simple))
        (check-equal? (flow-strand-capabilities simple-entry)
                      '(pure-function
                        io-continuation
                        local-kleisli
                        extension-hook))))
    (poo-flow-test-case "exposes Arrow first and second through the category object"
      (let* ((category default-flow-category)
             (inc (flow-category-arr category
                                     'inc
                                     (lambda (x) (+ x 1))
                                     'number
                                     'number))
             (first (flow-category-first category 'first-inc inc 'symbol))
             (second (flow-category-second category 'second-inc inc 'symbol)))
        (check-equal? (kernel-run first '(3 tag)) '(4 tag))
        (check-equal? (kernel-run second '(tag 3)) '(tag 4))))
    (poo-flow-test-case "composes category arrows and identity without execution side effects"
      (let* ((category default-flow-category)
             (inc (flow-category-arr category
                                     'inc
                                     (lambda (x) (+ x 1))
                                     'number
                                     'number))
             (double (flow-category-arr category
                                        'double
                                        (lambda (x) (* x 2))
                                        'number
                                        'number))
             (identity (flow-category-identity category 'same 'number))
             (pipeline (flow-category-compose
                        category
                        'pipeline
                        (flow-category-compose category 'inc-double inc double)
                        identity)))
        (check-equal? (flow-step-count pipeline) 3)
        (check-equal? (kernel-run pipeline 3) 8)))
    (poo-flow-test-case "observes category identity and associativity laws"
      (let* ((category default-flow-category)
             (inc (flow-category-arr category
                                     'inc
                                     (lambda (x) (+ x 1))
                                     'number
                                     'number))
             (double (flow-category-arr category
                                        'double
                                        (lambda (x) (* x 2))
                                        'number
                                        'number))
             (dec (flow-category-arr category
                                     'dec
                                     (lambda (x) (- x 1))
                                     'number
                                     'number))
             (identity (flow-category-identity category 'same 'number))
             (left-identity (flow-category-compose category 'left-id identity inc))
             (right-identity (flow-category-compose category 'right-id inc identity))
             (assoc-left
              (flow-category-compose
               category
               'assoc-left
               (flow-category-compose category 'assoc-left-inner inc double)
               dec))
             (assoc-right
              (flow-category-compose
               category
               'assoc-right
               inc
               (flow-category-compose category 'assoc-right-inner double dec))))
        (check-equal? (kernel-run left-identity 3) (kernel-run inc 3))
        (check-equal? (kernel-run right-identity 3) (kernel-run inc 3))
        (check-equal? (kernel-run assoc-left 3) (kernel-run assoc-right 3))
        (check-equal? (flow-step-count assoc-left) (flow-step-count assoc-right))))
    (poo-flow-test-case "maps flow output as functional composition"
      (let* ((inc (flow-arr 'inc (lambda (x) (+ x 1)) 'number 'number))
             (mapped (flow-category-map default-flow-category
                                        'mapped
                                        inc
                                        (lambda (x) (* x 10))
                                        'number)))
        (check-equal? (flow-step-count mapped) 2)
        (check-equal? (kernel-run mapped 4) 50)))
    (poo-flow-test-case "fans out two arrows with branch declaration semantics"
      (let* ((inc (flow-arr 'inc (lambda (x) (+ x 1)) 'number 'number))
             (double (flow-arr 'double (lambda (x) (* x 2)) 'number 'number))
             (fanout (flow-category-fanout default-flow-category
                                           'fanout
                                           inc
                                           double)))
        (check-equal? (flow-branch-declaration? fanout) #t)
        (check-equal? (kernel-run fanout 3) '(4 6))))
    (poo-flow-test-case "projects Arrow fanout into a report-only DAG receipt"
      (let* ((inc (flow-arr 'inc (lambda (x) (+ x 1)) 'number 'number))
             (double (flow-arr 'double (lambda (x) (* x 2)) 'number 'number))
             (fanout (flow-category-fanout default-flow-category
                                           'arrow-dag
                                           inc
                                           double))
             (plan (flow->linear-plan fanout))
             (plan-receipt (execution-plan->dag-receipt plan))
             (receipt (flow->dag-receipt fanout)))
        (check-equal? (functional-flow-alist-value 'kind receipt)
                      flow-dag-receipt-kind)
        (check-equal? (functional-flow-alist-value 'flow receipt) 'arrow-dag)
        (check-equal? (functional-flow-alist-value 'node-count receipt) 3)
        (check-equal? (functional-flow-alist-value 'root-node-ids receipt)
                      '((node arrow-dag 0 branch-left inc)
                        (node arrow-dag 1 branch-right double)))
        (check-equal? (functional-flow-alist-value 'terminal-node-ids receipt)
                      '((node arrow-dag 2 branch arrow-dag)))
        (check-equal? (functional-flow-alist-value 'strategy-facing receipt) #t)
        (check-equal? (functional-flow-alist-value 'runtime-executed receipt) #f)
        (check-equal? plan-receipt receipt)))
    (poo-flow-test-case "publishes Arrow DAG runtime manifest for Marlin discovery"
      (let* ((inc (flow-arr 'inc (lambda (x) (+ x 1)) 'number 'number))
             (double (flow-arr 'double (lambda (x) (* x 2)) 'number 'number))
             (fanout (flow-category-fanout default-flow-category
                                           'arrow-dag
                                           inc
                                           double))
             (plan (flow->linear-plan fanout))
             (plan-manifest
              (execution-plan->dag-runtime-manifest plan 'dag-manifest-1))
             (manifest
              (flow->dag-runtime-manifest fanout 'dag-manifest-1))
             (receipt (functional-flow-alist-value 'dag-receipt manifest)))
        (check-equal? (functional-flow-alist-value 'schema manifest)
                      +flow-dag-runtime-manifest-schema+)
        (check-equal? (functional-flow-alist-value 'bridge manifest)
                      'runtime-manifest)
        (check-equal? (functional-flow-alist-value 'consumer manifest)
                      'marlin-agent-core)
        (check-equal? (functional-flow-alist-value 'operation manifest)
                      'inspect-flow-dag)
        (check-equal? (functional-flow-alist-value 'receipt-schema manifest)
                      flow-dag-receipt-kind)
        (check-equal? (functional-flow-alist-value 'node-count manifest) 3)
        (check-equal? (functional-flow-alist-value 'entrypoints manifest)
                      '((flow . flow->dag-runtime-manifest)
                        (execution-plan . execution-plan->dag-runtime-manifest)
                        (receipt . flow->dag-receipt)))
        (check-equal? (functional-flow-alist-value 'runtime-executed manifest)
                      #f)
        (check-equal? (functional-flow-alist-value 'runtime-executed receipt)
                      #f)
        (check-equal? plan-manifest manifest)))
    (poo-flow-test-case "authors user-facing functional DAG flow artifacts"
      (check-equal? (flow-name macro-dag) 'macro-dag)
      (check-equal? (flow-branch-declaration? macro-dag) #t)
      (check-equal? (kernel-run macro-dag 3) '(4 6))
      (check-equal? (functional-flow-alist-value 'kind macro-dag-receipt)
                    flow-dag-receipt-kind)
      (check-equal? (functional-flow-alist-value 'flow macro-dag-receipt)
                    'macro-dag)
      (check-equal? (functional-flow-alist-value 'schema macro-dag-manifest)
                    +flow-dag-runtime-manifest-schema+)
      (check-equal? (functional-flow-alist-value 'request-id macro-dag-manifest)
                    'macro-dag-request)
      (check-equal? (functional-flow-alist-value 'consumer macro-dag-manifest)
                    'marlin-agent-core)
      (check-equal? (functional-flow-alist-value 'runtime-executed
                                                 macro-dag-manifest)
                    #f))
    (poo-flow-test-case "applies first and second arrows over pair-shaped values"
      (let* ((inc (flow-arr 'inc (lambda (x) (+ x 1)) 'number 'number))
             (first (flow-first 'first-inc inc 'symbol))
             (second (flow-second 'second-inc inc 'symbol)))
        (check-equal? (kernel-run first '(3 tag)) '(4 tag))
        (check-equal? (kernel-run second '(tag 3)) '(tag 4))))
    (poo-flow-test-case "authors functional flows with hygienic Gerbil macros"
      (check-equal? (flow-name macro-inc) 'macro-inc)
      (check-equal? (flow-name macro-pipeline) 'macro-pipeline)
      (check-equal? (kernel-run macro-pipeline 3) 8)
      (check-equal? (kernel-run macro-mapped 4) 50)
      (check-equal? (flow-branch-declaration? macro-fanout) #t)
      (check-equal? (kernel-run macro-fanout 3) '(4 6))
      (check-equal? (try-left? (kernel-run macro-try #!void)) #t)
      (check-equal? (kernel-run macro-first '(3 tag)) '(4 tag))
      (check-equal? (kernel-run macro-second '(tag 3)) '(tag 4)))))
