;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The actual AWS publication Suite lives in t/scenarios/aws and is discovered by std/test.
(import :std/test :clan/poo/object
        (only-in "../init.ss" agentic-ai-lab.init.exports))
(export aws-context-publication-test)
(def aws-context-publication-test
  (test-suite "AWS qualification metadata"
    (test-case "qualification shares source authority without running another Harness"
      (def tests
        (.call (.get agentic-ai-lab.init.exports tests qualification) .select
               '(agentic-ai-lab/scenarios/aws/interface)))
      (check-equal? (.ref/cached tests 'selected-graph) #f)
      (check-equal? (eq? (.call tests .select '(agentic-ai-lab/scenarios/aws/interface)) tests) #t)
      (check-equal? (map path-strip-directory (.get tests spec))
                    '("context-publication-test.ss"))
      (check-equal? (eq? (.get tests admit-current) (.get tests source admit-current)) #t)
      (for-each (lambda (name) (check-equal? (.slot? tests name) #f))
                '(.run .compile execution))
      ((.get tests admit-current))
      (check-equal? (.ref/cached tests 'selected-graph) #f))))
