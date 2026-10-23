;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite)
        :agentic-ai-lab/modules/workflow/graph/scenario-gap-rejection-facts)

(def scenario-gap-rejection-facts-test
  (test-suite "scenario gap rejection facts"
    (yuanxu-test-case "projects each rejection class"

(def (alist-ref key alist)
  (let ((entry (assq key alist)))
    (if entry
      (cdr entry)
      (error "missing scenario gap proof fact key" key alist))))

(def (assert-equal label actual expected)
  (unless (equal? actual expected)
    (error "scenario gap proof fact mismatch" label actual expected)))

(def missing-kind-facts
  (agentic-ai-lab-scenario-gap-runtime-contract->proof-facts
   'generated-scenario-gap-missing-kind-runtime-row
   #t
   #t
   #f
   'accepted))

(assert-equal 'schema
              (alist-ref 'schema missing-kind-facts)
              'agentic-ai-lab.proof.scenario-gap.runtime-row)
(assert-equal 'fact-id
              (alist-ref 'fact-id missing-kind-facts)
              'generated-scenario-gap-missing-kind-runtime-row)
(assert-equal 'plan-ok (alist-ref 'plan-ok missing-kind-facts) #t)
(assert-equal 'rejections-ok (alist-ref 'rejections-ok missing-kind-facts) #t)
(assert-equal 'accepted-ok (alist-ref 'accepted-ok missing-kind-facts) #f)
(assert-equal 'accepted? (alist-ref 'accepted? missing-kind-facts) #f)
(assert-equal 'rejection (alist-ref 'rejection missing-kind-facts) 'accepted)
(assert-equal 'rejection-rule
              (alist-ref 'rejection-rule missing-kind-facts)
              'runtime-row-rejected-by-accepted)
(assert-equal 'ffi-ready? (alist-ref 'ffi-ready? missing-kind-facts) #t)

(def wrong-plan-facts
  (agentic-ai-lab-scenario-gap-runtime-contract->proof-facts
   'generated-scenario-gap-wrong-plan-runtime-row
   #f
   #t
   #t
   'plan))

(assert-equal 'wrong-plan-rule
              (alist-ref 'rejection-rule wrong-plan-facts)
              'runtime-row-rejected-by-plan)

(def rejected-kind-facts
  (agentic-ai-lab-scenario-gap-runtime-contract->proof-facts
   'generated-scenario-gap-rejected-kind-runtime-row
   #t
   #f
   #t
   'rejections))

(assert-equal 'rejected-kind-rule
              (alist-ref 'rejection-rule rejected-kind-facts)
              'runtime-row-rejected-by-rejections))))
