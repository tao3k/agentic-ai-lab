;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test test-suite check-equal? check-exception)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :yuanxu/modules/funflow/workload)

(export scenario-workload-test)

(def scenario-workload-test
  (test-suite "Scenario workload owner"
    (yuanxu-test-case "ordered launch ranges preserve local ordinals"
      (let* ((first (scenario-multiplicity 'first 2))
             (second (scenario-multiplicity 'second 3))
             (workload (scenario-workload
                        (list first second)))
             (at-zero (scenario-workload/ref workload 0))
             (at-four (scenario-workload/ref workload 4)))
        (check-equal? (.ref workload 'total-count) 5)
        (check-equal? (.ref at-zero 'composition) 'first)
        (check-equal? (.ref at-zero 'local-ordinal) 0)
        (check-equal? (.ref at-four 'composition) 'second)
        (check-equal? (.ref at-four 'local-ordinal) 2)
        (check-exception
         (scenario-workload/ref workload 5)
         (lambda (_) #t))))
    (yuanxu-test-case "one thousand ranges retain bounded ordinal lookup"
      (let* ((multiplicities
              (map (lambda (index)
                     (scenario-multiplicity index 1))
                   (iota 1000)))
             (workload (scenario-workload multiplicities))
             (last (scenario-workload/ref workload 999)))
        (check-equal? (.ref workload 'total-count) 1000)
        (check-equal? (.ref last 'composition) 999)
        (check-equal? (.ref last 'local-ordinal) 0)))))
