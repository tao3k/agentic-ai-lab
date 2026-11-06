;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The init-owned atomic endpoint, with no external package realization.
(import :std/test :clan/poo/object
        (only-in "../init.ss" agentic-ai-lab.init.exports))
(export aws-module-test)
(def aws-module-test
  (test-suite "AWS atomic endpoint"
    (test-case "cold discovery and repeated reads leave integration and scope cold"
      (def tests (.call (.get agentic-ai-lab.init.exports tests) .select
                        '(agentic-ai-lab/scenarios/aws/interface)))
      (check-equal? (.ref/cached tests 'selected-graph) #f)
      (def integration-before (.ref/cached tests 'integration))
      (def qualification-before (.ref/cached tests 'qualification))
      (def files (.get tests spec))
      ((.get tests admit-current))
      (check-equal? (map path-strip-directory files) '("atomic-test.ss"))
      (check-equal? (eq? files (.get tests spec)) #t)
      (for-each (lambda (name) (check-equal? (.slot? tests name) #f))
                '(.run .compile execution))
      (check-equal? (eq? (.ref/cached tests 'integration) integration-before) #t)
      (check-equal? (eq? (.ref/cached tests 'qualification) qualification-before) #t)
      (check-equal? (.ref/cached tests 'selected-graph) #f))
    (test-case "integration is an explicit lazy projection of the same Graph"
      (def tests (.call (.get agentic-ai-lab.init.exports tests) .select
                        '(agentic-ai-lab/scenarios/aws/interface)))
      (def integration (.get tests integration))
      (check-equal? (eq? (.get tests selected-graph) (.get integration selected-graph)) #t)
      ;; Publication fault injection is Core qualification, not an AWS suite.
      (check-equal? (.get integration spec) '())
      (check-equal? (.ref/cached integration 'execution) #f)
      (def qualification (.get tests qualification))
      (check-equal? (eq? (.get tests selected-graph) (.get qualification selected-graph)) #t)
      (check-equal? (map path-strip-directory (.get qualification spec)) '("context-publication-test.ss"))
      (check-equal? (.ref/cached qualification 'execution) #f)
      (check-equal? (.ref/cached (.get tests selected-graph) 'selected-records) #f))))
