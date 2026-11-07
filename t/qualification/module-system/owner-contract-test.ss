;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: direct behavior qualification for RFC45 source owners that do not
;;; already have a narrower production test owner.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check
                 check-eq?
                 check-equal?
                 check-not-equal?
                 check-output
                 test-error
                 test-suite)
        (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/workflow/qualification/module-system/g0
        :agentic-ai-lab/modules/session/runtime-context-recovery
        :yuanxu/composition/lineage
        :agentic-ai-lab/modules/workflow/qualification/module-system/gerbil-poo-consumption)

(export owner-contract-test)

(def owner-contract-test
  (test-suite
   "RFC45 source owner contracts"
   (yuanxu-test-case "G0 rejects missing evidence and requires authorization"
     (let ((missing (agentic-ai-lab-g0-resolve 'g0 #f #t))
           (denied (agentic-ai-lab-g0-resolve 'g0 #t #f))
           (admitted (agentic-ai-lab-g0-resolve 'g0 #t #t)))
       (check-equal? (agentic-ai-lab-g0-decision? missing) #t)
       (check-equal? (.ref missing 'admitted?) #f)
       (check-equal? (.ref missing 'reason) 'missing-observation)
       (check-equal? (.ref denied 'admitted?) #f)
       (check-equal? (.ref denied 'reason) 'policy-denied)
       (check-equal? (.ref admitted 'admitted?) #t)))
   (yuanxu-test-case "runtime recovery preserves explicit transition decisions"
     (let ((context (agentic-ai-lab-runtime-context 'runtime-a 'active 3))
           (resume (agentic-ai-lab-recovery-decision 'transient #t 1))
           (abort (agentic-ai-lab-recovery-decision 'terminal #f 3)))
       (check-equal? (agentic-ai-lab-runtime-control-object? context) #t)
       (check-equal? (.ref context 'generation) 3)
       (check-equal? (agentic-ai-lab-demand-cell-transition 'pending 'realizing)
                     'realizing)
       (check-equal? (agentic-ai-lab-demand-cell-transition 'realized 'pending)
                     'invalid-transition)
       (check-equal? (.ref resume 'action) 'resume)
       (check-equal? (.ref abort 'action) 'abort)))
   (yuanxu-test-case "lineage analysis distinguishes productive cycles"
     (let ((acyclic (yuanxu-lineage-analysis '(a b c) '(b)))
           (productive (yuanxu-lineage-analysis '(a b a) '(b)))
           (blocked (yuanxu-lineage-analysis '(a b a) '(c))))
       (check-equal? (.ref acyclic 'status) 'acyclic)
       (check-equal? (.ref productive 'status) 'productive-recursion)
       (check-equal? (.ref blocked 'status) 'non-productive-cycle)))
   (yuanxu-test-case "Gerbil POO manifest names the admitted provider surface"
     (let (manifest (agentic-ai-lab-gerbil-poo-consumption-manifest))
       (check-equal? (.ref manifest 'provider-label)
                     +agentic-ai-lab-gerbil-poo-provider-label+)
       (check-equal? (.ref manifest 'source-resolution-receipt-label)
                     +agentic-ai-lab-gerbil-poo-resolution-receipt-label+)
       (check-equal?
        (agentic-ai-lab-gerbil-poo-api-closed?
         (.ref manifest 'required-api))
        #t)
       (check-equal?
       (agentic-ai-lab-gerbil-poo-api-closed?
         (cdr (.ref manifest 'required-api)))
        #f)
       (check-equal?
        (agentic-ai-lab-gerbil-poo-api-closed?
         (append (cdr (.ref manifest 'required-api))
                 (list (car (.ref manifest 'required-api)))))
        #t)
       (check-equal?
        (agentic-ai-lab-gerbil-poo-api-closed?
         (cons (car (.ref manifest 'required-api))
               (.ref manifest 'required-api)))
        #f)))))
