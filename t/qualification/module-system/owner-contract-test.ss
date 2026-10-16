;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: direct behavior qualification for RFC45 source owners that do not
;;; already have a narrower production test owner.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-not-equal?
                 check-output
                 test-error
                 test-suite)
        (only-in :clan/poo/object .ref)
        :poo-flow/modules/workflow/qualification/module-system/g0
        :poo-flow/modules/session/runtime-context-recovery
        :core/composition/lineage
        :poo-flow/modules/workflow/qualification/module-system/gerbil-poo-consumption)

(export owner-contract-test)

(def owner-contract-test
  (test-suite
   "RFC45 source owner contracts"
   (poo-flow-test-case "G0 rejects missing evidence and requires authorization"
     (let ((missing (poo-flow-g0-resolve 'g0 #f #t))
           (denied (poo-flow-g0-resolve 'g0 #t #f))
           (admitted (poo-flow-g0-resolve 'g0 #t #t)))
       (check-equal? (poo-flow-g0-decision? missing) #t)
       (check-equal? (.ref missing 'admitted?) #f)
       (check-equal? (.ref missing 'reason) 'missing-observation)
       (check-equal? (.ref denied 'admitted?) #f)
       (check-equal? (.ref denied 'reason) 'policy-denied)
       (check-equal? (.ref admitted 'admitted?) #t)))
   (poo-flow-test-case "runtime recovery preserves explicit transition decisions"
     (let ((context (poo-flow-runtime-context 'runtime-a 'active 3))
           (resume (poo-flow-recovery-decision 'transient #t 1))
           (abort (poo-flow-recovery-decision 'terminal #f 3)))
       (check-equal? (poo-flow-runtime-control-object? context) #t)
       (check-equal? (.ref context 'generation) 3)
       (check-equal? (poo-flow-demand-cell-transition 'pending 'realizing)
                     'realizing)
       (check-equal? (poo-flow-demand-cell-transition 'realized 'pending)
                     'invalid-transition)
       (check-equal? (.ref resume 'action) 'resume)
       (check-equal? (.ref abort 'action) 'abort)))
   (poo-flow-test-case "lineage analysis distinguishes productive cycles"
     (let ((acyclic (poo-flow-lineage-analysis '(a b c) '(b)))
           (productive (poo-flow-lineage-analysis '(a b a) '(b)))
           (blocked (poo-flow-lineage-analysis '(a b a) '(c))))
       (check-equal? (.ref acyclic 'status) 'acyclic)
       (check-equal? (.ref productive 'status) 'productive-recursion)
       (check-equal? (.ref blocked 'status) 'non-productive-cycle)))
   (poo-flow-test-case "Gerbil POO manifest names the admitted provider surface"
     (let (manifest (poo-flow-gerbil-poo-consumption-manifest))
       (check-equal? (.ref manifest 'provider-label)
                     +poo-flow-gerbil-poo-provider-label+)
       (check-equal? (.ref manifest 'source-resolution-receipt-label)
                     +poo-flow-gerbil-poo-resolution-receipt-label+)
       (check-equal?
        (poo-flow-gerbil-poo-api-closed?
         (.ref manifest 'required-api))
        #t)
       (check-equal?
       (poo-flow-gerbil-poo-api-closed?
         (cdr (.ref manifest 'required-api)))
        #f)
       (check-equal?
        (poo-flow-gerbil-poo-api-closed?
         (append (cdr (.ref manifest 'required-api))
                 (list (car (.ref manifest 'required-api)))))
        #t)
       (check-equal?
        (poo-flow-gerbil-poo-api-closed?
         (cons (car (.ref manifest 'required-api))
               (.ref manifest 'required-api)))
        #f)))))
