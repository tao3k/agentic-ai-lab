;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: reusable workloads for recursive JSON Schema contract gates.
;;; Invariant: workloads measure Scheme-side contract validation only.

(import (only-in :clan/poo/object
                 object<-alist)
        (only-in :gerbil/runtime/hash
                 list->hash-table)
        (only-in "./performance.ss"
                 poo-flow-performance-build-list)
        (only-in :core/modules/json-schema/json-schema-ir
                 poo-flow-json-schema-normalization-schema)
        (only-in :core/modules/json-schema/json-schema-receipt
                 poo-flow-json-schema-contract-artifact-normalization)
        (only-in :core/modules/json-schema/json-schema-valid
                 poo-flow-json-schema-node-valid?)
        (only-in :poo-flow/modules/funflow/github-ci-contract
                 poo-flow-funflow-github-ci-contract-artifact
                 poo-flow-funflow-github-ci-validate-workflow->alist))

(export json-schema-contract-performance-ref
        json-schema-contract-performance-step
        json-schema-contract-performance-job
        json-schema-contract-performance-workflow
        json-schema-contract-performance-native-step
        json-schema-contract-performance-native-job
        json-schema-contract-performance-native-workflow
        json-schema-contract-performance-poo-workflow
        json-schema-contract-performance-valid-receipt?
        json-schema-contract-performance-repeat
        json-schema-contract-performance-fast-validate-rounds
        json-schema-contract-performance-validate-rounds)

;; : (-> Alist Symbol Object)
(def (json-schema-contract-performance-ref rows key)
  (let (entry (assoc key rows))
    (if entry (cdr entry) #f)))

;; : (-> Integer Alist)
(def (json-schema-contract-performance-step index)
  (list
   (cons 'id
         (string-append "step_" (number->string index)))
   (cons 'run "echo poo-flow-json-schema-contract")))

;; : (-> Integer Integer Pair)
(def (json-schema-contract-performance-job index step-count)
  (cons
   (string->symbol
    (string-append "job_" (number->string index)))
   (list
    (cons 'runs-on "ubuntu-latest")
    (cons 'steps
          (poo-flow-performance-build-list
           step-count
           json-schema-contract-performance-step)))))

;; : (-> Integer Integer Alist)
(def (json-schema-contract-performance-workflow job-count step-count)
  (list
   (cons 'name "POO Flow recursive contract benchmark")
   (cons 'on "push")
   (cons 'jobs
         (poo-flow-performance-build-list
          job-count
          (lambda (index)
            (json-schema-contract-performance-job index step-count))))))

;; : (-> Integer HashTable)
(def (json-schema-contract-performance-native-step index)
  (list->hash-table
   (list
    (cons "id"
          (string-append "step_" (number->string index)))
    (cons "run" "echo poo-flow-json-schema-contract"))))

;; : (-> Integer Integer Pair)
(def (json-schema-contract-performance-native-job index step-count)
  (cons
   (string-append "job_" (number->string index))
   (list->hash-table
    (list
     (cons "runs-on" "ubuntu-latest")
     (cons "steps"
           (poo-flow-performance-build-list
            step-count
            json-schema-contract-performance-native-step))))))

;; This is Gerbil's default :std/text/json native representation: string-keyed
;; hash tables for objects and lists for arrays.
;; : (-> Integer Integer HashTable)
(def (json-schema-contract-performance-native-workflow job-count step-count)
  (list->hash-table
   (list
    (cons "name" "POO Flow recursive contract benchmark")
    (cons "on" "push")
    (cons "jobs"
          (list->hash-table
           (poo-flow-performance-build-list
            job-count
            (lambda (index)
              (json-schema-contract-performance-native-job
               index
               step-count))))))))

;; : (-> Integer Integer PooFlowObject)
(def (json-schema-contract-performance-poo-workflow job-count step-count)
  (object<-alist
   (json-schema-contract-performance-workflow job-count step-count)))

;; : (-> Alist Boolean)
(def (json-schema-contract-performance-valid-receipt? receipt)
  (and (eq? (json-schema-contract-performance-ref receipt 'valid?) #t)
       (= (json-schema-contract-performance-ref receipt 'diagnostic-count) 0)))

;; : (-> Integer (-> Integer) Integer)
(def (json-schema-contract-performance-repeat rounds workload)
  (let loop ((remaining rounds)
             (total 0))
    (if (<= remaining 0)
      total
      (loop (- remaining 1)
            (+ total (workload))))))

;; : (-> Object Integer Integer)
(def (json-schema-contract-performance-validate-rounds workflow rounds)
  (json-schema-contract-performance-repeat
   rounds
   (lambda ()
     (if (json-schema-contract-performance-valid-receipt?
          (poo-flow-funflow-github-ci-validate-workflow->alist workflow))
       1
       0))))

;; : (-> Object Integer Integer)
(def (json-schema-contract-performance-fast-validate-rounds workflow rounds)
  (let (root-node
        (poo-flow-json-schema-normalization-schema
         (poo-flow-json-schema-contract-artifact-normalization
          poo-flow-funflow-github-ci-contract-artifact)))
    (json-schema-contract-performance-repeat
     rounds
     (lambda ()
       (if (poo-flow-json-schema-node-valid? root-node workflow)
         1
         0)))))
