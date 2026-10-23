;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox resource POO prototypes use native typed contracts.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .def .o .ref object?)
        (only-in :std/test
                 check-equal?
                 test-suite)
        :agentic-ai-lab/modules/sandbox-core/resource-contract)

(export sandbox-core-resource-contract-test)

;; : PooSandboxResourcesPrototype
(.def invalid-cpu-resources-prototype
  filesystem: agentic-ai-lab-runtime-volume-filesystem-prototype
  cpu: "two"
  memory: "4Gi")

;; : PooSandboxResourcesPrototype
(.def missing-filesystem-resources-prototype
  cpu: 2
  memory: "4Gi")

;; : PooSandboxResourcesPrototype
(.def unreadable-root-mixin-resources-prototype
  filesystem: =>.+ agentic-ai-lab-runtime-volume-filesystem-prototype
  cpu: 2
  memory: "4Gi")

;; : PooSandboxResourcesPrototype
(.def unreadable-optional-resources-prototype
  filesystem: agentic-ai-lab-runtime-volume-filesystem-prototype
  ports: =>.+ '((scope . runtime))
  cpu: 2
  memory: "4Gi"
  timeout-ms: =>.+ 1000)

;; : PooSandboxFilesystemPrototype
(.def unstructured-filesystem-prototype
  scope: 'volume)

;; : PooSandboxResourcesPrototype
(.def unstructured-filesystem-resources-prototype
  filesystem: unstructured-filesystem-prototype
  cpu: 2
  memory: "4Gi")

;; : PooSandboxResourcesPrototype
(.def runtime-volume-ports-resources-prototype
  filesystem: agentic-ai-lab-runtime-volume-filesystem-prototype
  ports: '((scope . runtime)
           (published-by . runtime))
  cpu: 2
  memory: "4Gi")

;; : (-> Alist Symbol Object Object)
(def (alist-ref/default entries key default-value)
  (let (entry (assoc key entries))
    (if entry (cdr entry) default-value)))

;; : (-> Object Object)
(def (diagnostic-code diagnostic)
  (if (object? diagnostic)
    (.ref diagnostic 'code)
    #f))

;; diagnostic-codes
;;   : (-> [Object] [Object])
;;   | doc m%
;;       Projects structured diagnostics to their code rows and drops raw string
;;       diagnostics so contract tests can assert the structural failure path.
;;
;;       # Examples
;;       ```scheme
;;       (diagnostic-codes '(((code . missing-filesystem-slot)) "raw"))
;;       ;; => (missing-filesystem-slot)
;;       ```
;;     %
(def (diagnostic-codes diagnostics)
  (filter-map diagnostic-code diagnostics))

;; : (-> Object [Object] Boolean)
(def (diagnostic-member? diagnostic diagnostics)
  (if (member diagnostic diagnostics) #t #f))

;; : (-> Thunk Boolean)
(def (contract-error? thunk)
  (with-catch
   (lambda (_failure) #t)
   (lambda ()
     (thunk)
     #f)))

;; : TestSuite
(def sandbox-core-resource-contract-test
  (test-suite "sandbox-core resource prototype typed contracts"
    (yuanxu-test-case "projects shared filesystem fragments to resource policies"
      (check-equal?
       (agentic-ai-lab-sandbox-filesystem-prototype->resource-entry
        agentic-ai-lab-runtime-filesystem-prototype)
       '(filesystem
         (scope . runtime)
         (materialized-by . runtime)
         (mounts . runtime)))
      (check-equal?
       (agentic-ai-lab-sandbox-filesystem-prototype->resource-entry
        agentic-ai-lab-runtime-volume-filesystem-prototype)
       '(filesystem
         (scope . volume)
         (materialized-by . runtime)
         (mounts . runtime)))
      (check-equal?
       (agentic-ai-lab-sandbox-filesystem-prototype->resource-entry
        agentic-ai-lab-snapshot-filesystem-prototype)
       '(filesystem
         (scope . snapshot)
         (snapshot . clone))))
    (yuanxu-test-case "projects shared resources with ports, cpu, and memory"
      (let ((validation
             (agentic-ai-lab-sandbox-resources-prototype-contract-validation
              runtime-volume-ports-resources-prototype)))
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
          validation)
         #t)
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype->resource-policy
          runtime-volume-ports-resources-prototype)
         '((filesystem
            (scope . volume)
            (materialized-by . runtime)
            (mounts . runtime))
           (ports
            (scope . runtime)
            (published-by . runtime))
           (cpu . 2)
           (memory . "4Gi")))))
    (yuanxu-test-case "validates runtime volume resources with native POO contracts"
      (let* ((validation
              (agentic-ai-lab-sandbox-resources-prototype-contract-validation
               agentic-ai-lab-runtime-volume-resources-prototype))
             (summary
              (agentic-ai-lab-sandbox-resources-prototype-contract-validation->alist
               validation)))
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
          validation)
         #t)
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation-diagnostics
          validation)
         '())
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation?
          validation)
         #t)
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation?
          agentic-ai-lab-runtime-volume-resources-prototype)
         #f)
        (check-equal? (not (not (member 'native-poo-slot-types
                                        (alist-ref/default summary
                                                           'checked-signals '()))))
                      #t)
        (check-equal? (alist-ref/default summary 'diagnostic-count #f) 0)))
    (yuanxu-test-case "reports typed cpu contract failures natively"
      (let* ((validation
              (agentic-ai-lab-sandbox-resources-prototype-contract-validation
               invalid-cpu-resources-prototype))
             (diagnostics
              (agentic-ai-lab-sandbox-resources-prototype-contract-validation-diagnostics
               validation))
             (summary
              (agentic-ai-lab-sandbox-resources-prototype-contract-validation->alist
               validation)))
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
          validation)
         #f)
        (check-equal?
         (diagnostic-member?
          'slot-contract-failed
          (diagnostic-codes diagnostics))
         #t)
        (check-equal?
         (map (lambda (entry) (alist-ref/default entry 'code #f))
              (alist-ref/default summary 'diagnostics '()))
         '(slot-contract-failed))
        (check-equal?
         (contract-error?
          (lambda ()
            (agentic-ai-lab-require-sandbox-resources-prototype-contract!
             invalid-cpu-resources-prototype)))
         #t)))
    (yuanxu-test-case "reports missing filesystem as sandbox-core structure failure"
      (let ((validation
             (agentic-ai-lab-sandbox-resources-prototype-contract-validation
              missing-filesystem-resources-prototype)))
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
          validation)
         #f)
        (check-equal?
         (diagnostic-codes
          (agentic-ai-lab-sandbox-resources-prototype-contract-validation-diagnostics
           validation))
         '(missing-filesystem-slot))))
    (yuanxu-test-case "reports root resource mixins without parent slot"
      (let ((validation
             (agentic-ai-lab-sandbox-resources-prototype-contract-validation
              unreadable-root-mixin-resources-prototype)))
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
          validation)
         #f)
        (check-equal?
         (diagnostic-codes
          (agentic-ai-lab-sandbox-resources-prototype-contract-validation-diagnostics
           validation))
         '(unreadable-filesystem-slot))))
    (yuanxu-test-case "reports present but unreadable optional slots"
      (let ((validation
             (agentic-ai-lab-sandbox-resources-prototype-contract-validation
              unreadable-optional-resources-prototype)))
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
          validation)
         #f)
        (check-equal?
         (diagnostic-codes
          (agentic-ai-lab-sandbox-resources-prototype-contract-validation-diagnostics
           validation))
         '(unreadable-ports-slot unreadable-timeout-slot))))
    (yuanxu-test-case "rejects incomplete validation receipts safely"
      (let* ((complete
              (agentic-ai-lab-sandbox-resources-prototype-contract-validation
               agentic-ai-lab-runtime-volume-resources-prototype))
             (incomplete
              (.o kind: (.ref complete 'kind)
                  schema: (.ref complete 'schema))))
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation?
          incomplete)
         #f)
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
          incomplete)
         #f)))
    (yuanxu-test-case "reports unstructured filesystem projection"
      (let ((validation
             (agentic-ai-lab-sandbox-resources-prototype-contract-validation
              unstructured-filesystem-resources-prototype)))
        (check-equal?
         (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
          validation)
         #f)
        (check-equal?
         (diagnostic-codes
          (agentic-ai-lab-sandbox-resources-prototype-contract-validation-diagnostics
           validation))
         '(filesystem-not-structured))))))
