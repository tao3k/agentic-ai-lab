;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test test-suite check-equal? check-exception)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :agentic-ai-lab/modules/workflow/scenario/workload)

(export scenario-workload-test)

(def scenario-workload-test
  (test-suite "Scenario workload owner"
    (yuanxu-test-case "ordered launch ranges preserve local ordinals"
      (let* ((first (agentic-ai-lab-scenario-case-multiplicity 'first 2))
             (second (agentic-ai-lab-scenario-case-multiplicity 'second 3))
             (workload (agentic-ai-lab-scenario-case-workload
                        (list first second)))
             (at-zero (agentic-ai-lab-scenario-case-workload/ref workload 0))
             (at-four (agentic-ai-lab-scenario-case-workload/ref workload 4)))
        (check-equal? (.ref workload 'total-count) 5)
        (check-equal? (.ref at-zero 'composition) 'first)
        (check-equal? (.ref at-zero 'local-ordinal) 0)
        (check-equal? (.ref at-four 'composition) 'second)
        (check-equal? (.ref at-four 'local-ordinal) 2)
        (check-exception
         (agentic-ai-lab-scenario-case-workload/ref workload 5)
         (lambda (_) #t))))
    (yuanxu-test-case "one thousand ranges retain bounded ordinal lookup"
      (let* ((multiplicities
              (map (lambda (index)
                     (agentic-ai-lab-scenario-case-multiplicity index 1))
                   (iota 1000)))
             (workload (agentic-ai-lab-scenario-case-workload multiplicities))
             (last (agentic-ai-lab-scenario-case-workload/ref workload 999)))
        (check-equal? (.ref workload 'total-count) 1000)
        (check-equal? (.ref last 'composition) 999)
        (check-equal? (.ref last 'local-ordinal) 0)))))
