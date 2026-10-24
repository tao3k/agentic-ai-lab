;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .o .ref)
        :yuanxu/contribution/objects
        (only-in :yuanxu/profile-composition/profile-bundle
                 compose profiles))
(export contract-test)

(def sample (make-contribution "test/sample" "1" "test-owner"
                              (.o value: 42) '(test-facet) '(test-read)))
(def contract-test
  (test-suite "independent core contribution contract"
    (yuanxu-test-case "admission preserves values without executing"
      (let ((receipt (admit-contributions (list sample) '(test-read))))
        (check-equal? (.ref receipt 'accepted?) #t)
        (check-equal? (eq? (car (.ref receipt 'selected)) sample) #t)
        (check-equal? (.ref receipt 'runtime-executed?) #f)))
    (yuanxu-test-case "missing requirements and duplicates fail closed"
      (check-equal? (.ref (admit-contributions (list sample) '()) 'accepted?) #f)
      (check-equal? (.ref (admit-contributions (list sample sample) '(test-read))
                         'accepted?) #f))
    (yuanxu-test-case "wrong shape and unsupported contract fail closed"
      (check-equal? (.ref (admit-contributions (list (.o)) '()) 'accepted?) #f)
      (check-equal? (.ref (admit-contributions
                          (list (.o (:: @ sample) core-contract: 'future))
                          '(test-read)) 'reasons)
                    '(incompatible-core-contract)))
    (yuanxu-test-case "native composition keeps explicit Profile payloads"
      (let* ((profile (.o identity: 'sample-contribution payload: sample))
             (selection (compose profiles profile)))
        (check-equal? (eq? (.ref (car (.ref selection 'profiles)) 'payload)
                           sample)
                      #t)))))
