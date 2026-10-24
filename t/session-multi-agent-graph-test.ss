;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only multi-agent session graph topology.
;;; Invariant: graph construction is declarative; Scheme does not run agents or
;;; deliver messages.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/session/config)

(export session-multi-agent-graph-test)

;; : (-> Symbol Symbol PooSession)
(def (make-agent-graph-session session-id parent-id)
  (agentic-ai-lab-session-value
   session-id
   (list (agentic-ai-lab-session-chunk session-id 'assistant "agent graph node"))
   (agentic-ai-lab-session-lineage
    session-id
    (if parent-id (list parent-id) '())
    (if parent-id 'child-agent 'root))
   (agentic-ai-lab-session-placement 'agent/nono)))

;; : TestSuite
(def session-multi-agent-graph-test
  (test-suite "agentic-ai-lab multi-agent session graph"
    (yuanxu-test-case "unifies child agent sessions through shared topology"
      (let* ((root-session
              (make-agent-graph-session 'graph/root #f))
             (build-session
              (make-agent-graph-session 'graph/build 'graph/root))
             (audit-session
              (make-agent-graph-session 'graph/audit 'graph/root))
             (build-node
              (agentic-ai-lab-session-agent-node
               'agent/build
               'project/graph
               'graph/root
               'graph/root
               'graph/build-system
               'graph/root
               'graph/build
               '(graph/audit)
               '(channel/build-audit)
               'policy/build-model
               'policy/build-prompt
               'policy/build-tools
               'policy/build-hook-tools
               'policy/build-resources
               'durable/graph
               '(read-workspace-file run-build-command)
               '(session/memory)
               'agent/nono
               'builder
               'agentic-ai-lab.session.agent.build-result.v1))
             (audit-node
              (agentic-ai-lab-session-agent-node
               'agent/audit
               'project/graph
               'graph/root
               'graph/root
               'graph/audit-system
               'graph/build
               'graph/audit
               '(graph/build)
               '(channel/build-audit channel/audit-root)
               'policy/audit-model
               'policy/audit-prompt
               'policy/audit-tools
               'policy/audit-hook-tools
               'policy/audit-resources
               'durable/graph
               '(read-workspace-file)
               '(session/memory)
               'agent/nono
               'auditor
               'agentic-ai-lab.session.agent.audit-result.v1))
             (root-entry
              (agentic-ai-lab-session-registry-entry
               root-session
               'agent/root
               '()
               '((isolation . root))))
             (build-entry
              (agentic-ai-lab-session-agent-node->registry-entry
               build-node
               build-session))
             (audit-entry
              (agentic-ai-lab-session-agent-node->registry-entry
               audit-node
               audit-session))
             (registry
              (agentic-ai-lab-session-registry-receipt
               'project/graph
               '(graph/root)
               '(graph/build graph/audit)
               'graph/root
               (list root-entry build-entry audit-entry)))
             (build-audit-channel
              (agentic-ai-lab-session-communication-channel-receipt
               'project/graph
               'channel/build-audit
               'sibling
               'graph/build
               'graph/audit
               'agent/build
               'agent/audit
               '(artifact)
               '(declared-channel-only)))
             (audit-root-channel
              (agentic-ai-lab-session-communication-channel-receipt
               'project/graph
               'channel/audit-root
               'child-parent
               'graph/audit
               'graph/root
               'agent/audit
               'agent/root
               '(receipt)
               '(receipt-only)))
             (build-audit-message
              (agentic-ai-lab-session-communication-receipt
               'project/graph
               'sibling
               'graph/root
               'graph/root
               'graph/build
               'graph/audit
               'agent/build
               'agent/audit
               'channel/build-audit
               'artifact
               '((artifact . build-report))
               'declared-channel-only))
             (audit-root-message
              (agentic-ai-lab-session-communication-receipt
               'project/graph
               'child-parent
               'graph/root
               'graph/root
               'graph/audit
               'graph/root
               'agent/audit
               'agent/root
               'channel/audit-root
               'receipt
               '((receipt . audit-result))
               'receipt-only))
             (graph
              (agentic-ai-lab-session-agent-graph
               'project/graph
               'graph/root
               (list build-node audit-node)
               (list root-session build-session audit-session)
               registry
               (list build-audit-message audit-root-message)
               (list (cons 'communication-channel-receipts
                           (list build-audit-channel
                                 audit-root-channel)))))
             (registry-row
              (agentic-ai-lab-session-registry-receipt->alist
               (agentic-ai-lab-session-agent-graph-registry-receipt graph))))
        (check-equal? (agentic-ai-lab-session-agent-node? build-node) #t)
        (check-equal? (agentic-ai-lab-session-agent-node-agent-id build-node)
                      'agent/build)
        (check-equal? (agentic-ai-lab-session-agent-node-output-session-ref
                       build-node)
                      'graph/build)
        (check-equal? (.ref build-node 'tool-permission-policy-ref)
                      'policy/build-tools)
        (check-equal? (agentic-ai-lab-session-agent-node-durable-policy-ref
                       build-node)
                      'durable/graph)
        (check-equal? (.ref audit-node 'peer-session-refs)
                      '(graph/build))
        (check-equal? (agentic-ai-lab-session-agent-graph? graph) #t)
        (check-equal? (agentic-ai-lab-session-agent-graph-agent-ids graph)
                      '(agent/build agent/audit))
        (check-equal? (agentic-ai-lab-session-agent-graph-session-ids graph)
                      '(graph/root graph/build graph/audit))
        (check-equal? (.ref graph 'lineage-edge-pairs)
                      '((graph/root . graph/build)
                        (graph/root . graph/audit)))
        (check-equal? (.ref graph 'durable-policy-refs)
                      '(durable/graph durable/graph))
        (check-equal? (.ref graph 'communication-receipt-count) 2)
        (check-equal? (.ref graph 'communication-channel-receipt-count) 2)
        (check-equal? (map agentic-ai-lab-session-communication-channel-receipt-channel-id
                           (agentic-ai-lab-session-agent-graph-communication-channel-receipts
                            graph))
                      '(channel/build-audit channel/audit-root))
        (check-equal? (map agentic-ai-lab-session-communication-receipt-relation-kind
                           (agentic-ai-lab-session-agent-graph-communication-receipts
                            graph))
                      '(sibling child-parent))
        (check-equal? (cdr (assoc 'entry-count registry-row))
                      3)
        (check-equal? (cdr (assoc 'durable-policy-refs registry-row))
                      '(durable/graph durable/graph))
        (check-equal? (.ref graph 'runtime-executed) #f)))))
