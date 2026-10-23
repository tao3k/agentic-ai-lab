;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: agent-scoped tool permission policy.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        :agentic-ai-lab/modules/session/config)

(export session-agent-tool-policy-test)

;; : TestSuite
(def session-agent-tool-policy-test
  (test-suite "agentic-ai-lab session agent tool policy"
    (yuanxu-test-case "admits only explicitly granted agent tools"
      (let* ((read-grant
              (agentic-ai-lab-session-tool-grant
               'grant/read
               'read-workspace-file
               '(read)
               '(project-workspace)
               '(agent-turn)))
             (run-grant
              (agentic-ai-lab-session-tool-grant
               'grant/build
               'run-build-command
               '(run)
               '(project-workspace build-cache)
               '(agent-turn)))
             (policy
              (agentic-ai-lab-session-tool-permission-policy
               'policy/build-agent-tools
               'session/build
               (list read-grant run-grant)
               '(write-workspace-file)
               'deny)))
        (check-equal? (agentic-ai-lab-session-tool-permission-policy-allows?
                       policy
                       'read-workspace-file
                       'read)
                      #t)
        (check-equal? (agentic-ai-lab-session-tool-permission-policy-allows?
                       policy
                       'run-build-command
                       'run)
                      #t)
        (check-equal? (agentic-ai-lab-session-tool-permission-policy-allows?
                       policy
                       'write-workspace-file
                       'write)
                      #f)
        (check-equal? (agentic-ai-lab-session-policy-default-action policy)
                      'deny)))))
