;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test test-suite check-equal? check-exception)
        (only-in :clan/poo/object .ref)
        (only-in :core/observability/testing-case poo-flow-test-case)
        :poo-flow/modules/workflow/scenario/workload)

(export scenario-workload-test)

(def scenario-workload-test
  (test-suite "Scenario workload owner"
    (poo-flow-test-case "ordered launch ranges preserve local ordinals"
      (let* ((first (poo-flow-scenario-case-multiplicity 'first 2))
             (second (poo-flow-scenario-case-multiplicity 'second 3))
             (workload (poo-flow-scenario-case-workload
                        (list first second)))
             (at-zero (poo-flow-scenario-case-workload/ref workload 0))
             (at-four (poo-flow-scenario-case-workload/ref workload 4)))
        (check-equal? (.ref workload 'total-count) 5)
        (check-equal? (.ref at-zero 'composition) 'first)
        (check-equal? (.ref at-zero 'local-ordinal) 0)
        (check-equal? (.ref at-four 'composition) 'second)
        (check-equal? (.ref at-four 'local-ordinal) 2)
        (check-exception
         (poo-flow-scenario-case-workload/ref workload 5)
         (lambda (_) #t))))
    (poo-flow-test-case "one thousand ranges retain bounded ordinal lookup"
      (let* ((multiplicities
              (map (lambda (index)
                     (poo-flow-scenario-case-multiplicity index 1))
                   (iota 1000)))
             (workload (poo-flow-scenario-case-workload multiplicities))
             (last (poo-flow-scenario-case-workload/ref workload 999)))
        (check-equal? (.ref workload 'total-count) 1000)
        (check-equal? (.ref last 'composition) 999)
        (check-equal? (.ref last 'local-ordinal) 0)))))
