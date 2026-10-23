;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: POO-native tool specs and policy-catalog validation.
;;; Invariant: Scheme builds tool handoff receipts only; no tool runtime starts.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :agentic-ai-lab/modules/tool-core/objects-policy-refs
                 agentic-ai-lab-tool-merge-policy-tool-refs
                 agentic-ai-lab-tool-unique-symbols)
        :agentic-ai-lab/modules/session/config
        :agentic-ai-lab/modules/tool-core/config)

(export tool-core-test)

;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;; : (-> [Alist] Symbol [Value])
(def (test-field-values rows key)
  (map (lambda (row) (test-ref row key)) rows))

;; : TestSuite
(def tool-core-test
  (test-suite "agentic-ai-lab tool-core"
    (yuanxu-test-case "deduplicates policy refs while preserving wildcard and seed semantics"
      (check-equal?
       (agentic-ai-lab-tool-unique-symbols
        '(calculator * shell calculator audit shell)
        '(audit))
       '(calculator shell))
      (check-equal?
       (agentic-ai-lab-tool-merge-policy-tool-refs
        '(calculator shell calculator)
        '(* shell audit calculator))
       '(calculator shell audit)))
    (yuanxu-test-case "authors custom tool specs and projects handoff manifests"
      (let* ((calculator
              (agentic-ai-lab-tool-spec
               'calculator
               'custom
               '(calculate)
               '((expression . string))
               '((result . number))
               "marlin-agent-core"
               'tool/calculator
               #f
               #f
               'marlin-tool-adapter
               '((source . unit-test))))
             (catalog
              (agentic-ai-lab-tool-catalog
               'tool-core/custom
               (list calculator)
               '((scope . unit-test))))
             (manifest
              (agentic-ai-lab-tool-handoff-manifest->alist
               (agentic-ai-lab-tool-handoff-manifest
                'request/calculator
                calculator))))
        (check-equal? (agentic-ai-lab-tool-catalog? catalog) #t)
        (check-equal? (agentic-ai-lab-tool-catalog-ref catalog)
                      'tool-core/custom)
        (check-equal? (agentic-ai-lab-tool-catalog-tool-refs catalog)
                      '(calculator))
        (check-equal? (test-ref manifest 'tool-ref) 'calculator)
        (check-equal? (test-ref manifest 'handoff-ready?) #t)
        (check-equal? (test-ref manifest 'runtime-executed) #f)))
    (yuanxu-test-case "projects built-in shell and filesystem tools as sandboxed handoff specs"
      (let* ((catalog agentic-ai-lab-tool-core-default-catalog)
             (shell
              (agentic-ai-lab-tool-catalog-find catalog 'run-shell-command))
             (read-file
              (agentic-ai-lab-tool-catalog-find catalog 'read-workspace-file))
             (manifest
              (agentic-ai-lab-tool-handoff-manifest
               'request/run-shell
               shell))
             (row (agentic-ai-lab-tool-handoff-manifest->alist manifest)))
        (check-equal? (agentic-ai-lab-tool-spec? shell) #t)
        (check-equal? (agentic-ai-lab-tool-spec? read-file) #t)
        (check-equal? (agentic-ai-lab-tool-spec-sandbox-required? shell) #t)
        (check-equal? (agentic-ai-lab-tool-spec-sandbox-profile-ref shell)
                      'agent/nono)
        (check-equal? (test-ref row 'handoff-ready?) #t)
        (check-equal? (test-ref row 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (test-ref row 'runtime-executed) #f)))
    (yuanxu-test-case "represents MCP tools without starting an MCP server"
      (let* ((mcp-tool
              (agentic-ai-lab-tool-core-mcp-tool
               'github/search-issues
               'mcp/github
               '(query)
               '((q . string))
               '((issues . list))
               '((transport . external-mcp))))
             (manifest
              (agentic-ai-lab-tool-handoff-manifest
               'request/mcp-search
               mcp-tool))
             (row (agentic-ai-lab-tool-handoff-manifest->alist manifest)))
        (check-equal? (agentic-ai-lab-tool-spec-tool-kind mcp-tool) 'mcp)
        (check-equal? (agentic-ai-lab-tool-spec-sandbox-required? mcp-tool) #f)
        (check-equal? (test-ref row 'runtime-backend) 'mcp/github)
        (check-equal? (test-ref row 'handoff-ready?) #t)
        (check-equal? (test-ref row 'runtime-executed) #f)))
    (yuanxu-test-case "validates session tool policies against concrete catalog specs"
      (let* ((calc
              (agentic-ai-lab-tool-spec
               'calculator
               'custom
               '(calculate)
               '((expression . string))
               '((result . number))
               "marlin-agent-core"
               'tool/calculator
               #f
               #f
               'marlin-tool-adapter))
             (unsafe-shell
              (agentic-ai-lab-tool-spec
               'unsafe-shell
               'builtin-command
               '(run)
               '((argv . list))
               '((exit-status . integer))
               "marlin-agent-core"
               'tool/unsafe-shell
               #t
               #f
               'marlin-tool-adapter))
             (catalog
              (agentic-ai-lab-tool-catalog
               'tool-core/test
               (list calc
                     agentic-ai-lab-tool-core-builtin-run-shell-command
                     unsafe-shell)))
             (calc-grant
              (agentic-ai-lab-session-tool-grant
               'grant/calc
               'calculator
               '(calculate)
               '(session/input)
               '(agent-turn)))
             (shell-grant
              (agentic-ai-lab-session-tool-grant
               'grant/shell
               'run-shell-command
               '(run)
               '(project-workspace)
               '(agent-turn)))
             (unsafe-grant
              (agentic-ai-lab-session-tool-grant
               'grant/unsafe
               'unsafe-shell
               '(run)
               '(project-workspace)
               '(agent-turn)))
             (missing-grant
              (agentic-ai-lab-session-tool-grant
               'grant/missing
               'delete-world
               '(run)
               '(project-workspace)
               '(agent-turn)))
             (bad-action-grant
              (agentic-ai-lab-session-tool-grant
               'grant/calc-delete
               'calculator
               '(delete)
               '(session/input)
               '(agent-turn)))
             (agent-policy
              (agentic-ai-lab-session-tool-permission-policy
               'policy/tool-core-agent
               'session/tool-core
               (list calc-grant
                     shell-grant
                     unsafe-grant
                     missing-grant
                     bad-action-grant)
               '()
               'deny))
             (hook-policy
              (agentic-ai-lab-session-hook-tool-permission-policy
               'policy/tool-core-hook
               'session/tool-core
               '(hook/pre-check)
               (list calc-grant)
               'deny-escalation
               'deny))
             (receipt
              (agentic-ai-lab-tool-policy-catalog-validation-receipt
               'validation/tool-core
               catalog
               agent-policy
               hook-policy))
             (row
              (agentic-ai-lab-tool-policy-catalog-validation-receipt->alist
               receipt)))
        (check-equal?
         (agentic-ai-lab-tool-policy-catalog-validation-receipt? receipt)
         #t)
        (check-equal?
         (agentic-ai-lab-tool-policy-catalog-validation-receipt-valid? receipt)
         #f)
        (check-equal? (test-ref row 'resolved-tool-refs)
                      '(calculator run-shell-command unsafe-shell))
        (check-equal? (test-ref row 'unresolved-tool-refs)
                      '(delete-world))
        (check-equal? (test-ref row 'sandbox-required-tool-refs)
                      '(run-shell-command unsafe-shell))
        (check-equal? (test-field-values
                       (test-ref row 'action-mismatch-grants)
                       'grant-id)
                      '(grant/calc-delete))
        (check-equal? (test-field-values
                       (test-ref row 'action-mismatch-grants)
                       'unsupported-actions)
                      '((delete)))
        (check-equal? (test-field-values (test-ref row 'diagnostics) 'code)
                      '(tool-spec-not-in-catalog
                        tool-spec-missing-sandbox-profile
                        tool-grant-action-not-supported))
        (check-equal? (test-ref row 'runtime-executed) #f)))))
