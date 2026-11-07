;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: hook-scoped tool permission policy.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :agentic-ai-lab/modules/session/config)

(export session-hook-tool-policy-test)

;; : TestSuite
(def session-hook-tool-policy-test
  (test-suite "agentic-ai-lab session hook tool policy"
    (yuanxu-test-case "does not inherit child-agent command grants implicitly"
      (let* ((read-grant
              (agentic-ai-lab-session-tool-grant
               'grant/hook-read
               'read-workspace-file
               '(read)
               '(project-workspace)
               '(hook/pre-check)))
             (hook-policy
              (agentic-ai-lab-session-hook-tool-permission-policy
               'policy/pre-check-hook-tools
               'session/root
               '(hook/pre-check)
               (list read-grant)
               'human-approval-on-escalation
               'deny)))
        (check-equal? (agentic-ai-lab-session-hook-tool-permission-policy-allows?
                       hook-policy
                       'hook/pre-check
                       'read-workspace-file
                       'read)
                      #t)
        (check-equal? (agentic-ai-lab-session-hook-tool-permission-policy-allows?
                       hook-policy
                       'hook/pre-check
                       'run-build-command
                       'run)
                      #f)
        (check-equal? (agentic-ai-lab-session-hook-tool-permission-policy-allows?
                       hook-policy
                       'hook/post-check
                       'read-workspace-file
                       'read)
                      #f)
        (check-equal? (agentic-ai-lab-session-policy-default-action hook-policy)
                      'deny)))))
