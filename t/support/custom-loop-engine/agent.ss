;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Agent graph, receipt, and handoff checks for custom loop-engine tests.

(import (only-in :std/test check-equal?)
        (only-in :clan/poo/object object?)
        (only-in :agentic-ai-lab/modules/loop-engine/runtime
                 loop-engine-capability-receipt?)
        "./fixtures")

(export check-custom-loop-agent-boundary)

;;; The handoff, contract, and sandbox checks are the root facts every graph
;;; projection below depends on.
;; : (-> Alist Alist Alist [Alist] [Alist] [Alist])
(def (check-custom-loop-handoff-agent-head! handoff
                                            result-contract
                                            sandbox-agreement
                                            agent-profiles
                                            agent-harnesses
                                            agent-sessions)
  (check-equal? (test-ref handoff 'contract)
                'agentic-ai-lab.loop-governor.runtime-handoff.v1)
  (check-equal? (test-ref handoff 'workflow-ref) 'funflow-cicd)
  (check-equal? (test-field-values agent-profiles 'name)
                expected-loop-engine-agent-names)
  (check-equal? (test-ref result-contract 'contract)
                'agentic-ai-lab.loop-governor.result-contract.v1)
  (check-equal? (test-ref result-contract 'valid?) #t)
  (check-equal? (test-ref result-contract 'diagnostic-count) 0)
  (check-equal? (test-ref result-contract 'diagnostics) '())
  (check-equal? (test-ref result-contract 'human-audit)
                expected-loop-engine-human-audit-result-contract)
  (check-equal? (test-ref result-contract 'required-fields)
                expected-loop-engine-required-result-fields)
  (check-equal? (test-ref sandbox-agreement 'valid?) #f)
  (check-equal? (test-ref sandbox-agreement 'unresolved-profile-refs)
                '(ci/build))
  (check-equal? (test-ref sandbox-agreement 'diagnostic-count) 1)
  (check-equal? (test-field-values
                 (test-ref sandbox-agreement 'diagnostics)
                 'code)
                '(unresolved-sandbox-profile-refs))
  (check-equal? (test-ref (test-ref (car agent-profiles) 'loop-policy)
                          'result-contract)
                'agentic-ai-lab.loop-governor.audit-result.v1)
  (check-equal? (test-ref (test-ref (car agent-profiles) 'loop-policy)
                          'topology-source)
                'session-agent-graph)
  (check-equal? (test-field-values agent-harnesses 'profile)
                expected-loop-engine-agent-names)
  (check-equal? (test-field-values agent-sessions 'kind)
                '(agent-session agent-session agent-session agent-session)))

;;; Session-agent graph checks prove profile rows project into concrete graph
;;; metadata before any runtime language receives the handoff.
;; : (-> Alist)
(def (check-custom-loop-session-agent-graph! session-agent-graph)
  (check-equal? (test-ref session-agent-graph 'kind)
                'agentic-ai-lab.session.agent-graph)
  (check-equal? (test-ref session-agent-graph 'root-session-ref)
                'incoming-ci-request-session)
  (check-equal? (test-ref session-agent-graph 'agent-count) 4)
  (check-equal? (test-ref session-agent-graph 'agent-ids)
                expected-loop-engine-agent-names)
  (check-equal? (test-ref session-agent-graph 'session-ids)
                expected-loop-engine-session-ids)
  (check-equal? (test-ref session-agent-graph 'lineage-edge-pairs)
                expected-loop-engine-lineage-edge-pairs)
  (check-equal? (test-ref session-agent-graph 'durable-policy-refs)
                expected-loop-engine-durable-policy-refs)
  (check-equal? (test-ref session-agent-graph 'communication-receipt-count)
                8)
  (check-equal? (map (lambda (row) (test-ref row 'relation-kind))
                     (test-ref session-agent-graph 'communication-receipts))
                '(parent-child child-parent parent-child child-parent
                  parent-child child-parent parent-child child-parent))
  (check-equal? (test-ref session-agent-graph 'runtime-executed) #f)
  (check-equal? (test-ref (test-ref session-agent-graph
                                    'registry-receipt)
                          'active-session-ref)
                'loop-engine/current-system-build-loop/session))

;;; Topology trace checks keep the registry, graph, communication, and durable
;;; projections aligned without interpreting runtime behavior.
;; : (-> Alist)
(def (check-custom-loop-session-topology! session-agent-topology-trace)
  (check-equal? (test-ref session-agent-topology-trace 'kind)
                'loop-engine-session-agent-topology-trace)
  (check-equal? (test-ref session-agent-topology-trace 'valid?) #t)
  (check-equal? (test-ref session-agent-topology-trace 'diagnostics) '())
  (check-equal? (test-ref session-agent-topology-trace 'profile-names)
                expected-loop-engine-agent-names)
  (check-equal? (test-ref session-agent-topology-trace 'harness-profiles)
                expected-loop-engine-agent-names)
  (check-equal? (test-ref session-agent-topology-trace 'graph-agent-ids)
                expected-loop-engine-agent-names)
  (check-equal? (test-ref session-agent-topology-trace
                          'graph-root-session-ref)
                'incoming-ci-request-session)
  (check-equal? (test-ref session-agent-topology-trace
                          'loop-session-ref)
                'loop-engine/current-system-build-loop/session)
  (check-equal? (test-ref session-agent-topology-trace
                          'graph-session-ids)
                expected-loop-engine-session-ids)
  (check-equal? (test-ref session-agent-topology-trace
                          'agent-session-refs)
                (test-ref session-agent-topology-trace
                          'graph-output-session-refs))
  (check-equal? (test-ref session-agent-topology-trace
                          'graph-lineage-edge-pairs)
                expected-loop-engine-lineage-edge-pairs)
  (check-equal? (test-ref session-agent-topology-trace
                          'graph-durable-policy-refs)
                expected-loop-engine-durable-policy-refs)
  (check-equal? (test-ref session-agent-topology-trace
                          'registry-durable-policy-refs)
                expected-loop-engine-durable-policy-refs)
  (check-equal? (test-ref session-agent-topology-trace
                          'graph-channel-refs)
                expected-loop-engine-channel-refs)
  (check-equal? (test-ref session-agent-topology-trace
                          'communication-channel-refs)
                expected-loop-engine-channel-refs)
  (check-equal? (test-ref session-agent-topology-trace
                          'communication-receipt-count)
                8)
  (check-equal? (test-ref session-agent-topology-trace
                          'registry-root-session-ids)
                '(incoming-ci-request-session))
  (check-equal? (test-ref session-agent-topology-trace
                          'registry-session-ids)
                expected-loop-engine-session-ids)
  (check-equal? (test-ref session-agent-topology-trace
                          'registry-active-session-ref)
                'loop-engine/current-system-build-loop/session))

;;; Runtime flags prove every projected agent row stays report-only.
;; : (-> [Alist] [Alist])
(def (check-custom-loop-runtime-flags! agent-profiles
                                       agent-harnesses
                                       agent-sessions)
  (check-equal? (test-ref (car agent-profiles) 'runtime-executed) #f)
  (check-equal? (test-ref (car agent-harnesses) 'runtime-executed) #f)
  (check-equal? (test-ref (test-ref (car agent-sessions) 'metadata)
                          'runtime-executed)
                #f)
  (check-equal? (test-ref (test-ref (car agent-sessions) 'metadata)
                          'topology-source)
                'session-agent-graph))

;;; Agent graph assertions prove profile, harness, and session rows are
;;; projected before the runtime handoff without becoming execution.
;; : (-> Alist Alist Alist Alist Alist)
(def (check-custom-loop-agent-graph-boundary handoff
                                             result-contract
                                             sandbox-agreement
                                             agent-profiles
                                             agent-harnesses
                                             agent-sessions
                                             session-agent-graph
                                             session-agent-topology-trace)
  (check-custom-loop-handoff-agent-head! handoff
                                        result-contract
                                        sandbox-agreement
                                        agent-profiles
                                        agent-harnesses
                                        agent-sessions)
  (check-custom-loop-session-agent-graph! session-agent-graph)
  (check-custom-loop-session-topology! session-agent-topology-trace)
  (check-custom-loop-runtime-flags! agent-profiles
                                   agent-harnesses
                                   agent-sessions))

;;; Policy receipt assertions keep lineage, selection, resource, memory, and
;;; compression facts report-only while preserving their selected loop branch.
;; : (-> Alist Alist Alist Alist Alist Alist)
(def (check-custom-loop-policy-receipt-boundary lineage-receipt
                                                selector-receipt
                                                resource-dispatch-receipt
                                                capability-receipt
                                                memory-receipt
                                                compression-receipt)
  (check-equal? (test-ref lineage-receipt 'lineage-kind)
                'guarded-handoff)
  (check-equal? (test-ref selector-receipt 'candidates)
                '(current-system-build-loop current-system-recovery-loop))
  (check-equal? (test-ref selector-receipt 'selected-branch)
                'current-system-build-loop)
  (check-equal? (test-ref resource-dispatch-receipt 'dispatch-groups)
                '(((run-shell-command) . serial)
                  ((write-workspace-file read-workspace-file) . serial)))
  (check-equal? (test-ref capability-receipt 'backend) 'nono)
  (check-equal? (test-ref capability-receipt 'supported-backends)
                '(sandbox nono cube))
  (check-equal? (test-ref capability-receipt 'valid?) #t)
  (check-equal? (test-ref capability-receipt 'diagnostics) '())
  (check-equal? (test-ref capability-receipt 'required)
                '(command-run files-read files-write))
  (check-equal? (test-ref capability-receipt 'sandbox-ref) 'ci/build)
  (check-equal? (test-ref memory-receipt 'selected-use-case)
                'current-system-build-loop)
  (check-equal? (test-ref memory-receipt 'policy-count) 2)
  (check-equal? (test-ref memory-receipt 'available-use-cases)
                '(current-system-build-loop
                  current-system-recovery-loop))
  (check-equal? (test-ref memory-receipt 'selected-policy-found?) #t)
  (check-equal? (test-ref memory-receipt 'use-case)
                'current-system-build-loop)
  (check-equal? (test-ref memory-receipt 'store) 'project-memory)
  (check-equal? (test-ref memory-receipt 'state-path)
                "loop-state/current-system-build.org")
  (check-equal? (test-ref memory-receipt 'scope) 'session)
  (check-equal? (test-ref memory-receipt 'recall)
                '(last-user-message build-context prior-failure))
  (check-equal? (test-ref memory-receipt 'commit)
                '(decision-summary evidence-index handoff-receipt))
  (check-equal? (test-ref memory-receipt 'retention) 'report-only)
  (check-equal? (test-field-values (test-ref memory-receipt 'policies)
                                   'use-case)
                '(current-system-build-loop
                  current-system-recovery-loop))
  (check-equal? (test-ref (cadr (test-ref memory-receipt 'policies))
                          'state-path)
                "loop-state/current-system-recovery.org")
  (check-equal? (test-ref memory-receipt 'runtime-executed) #f)
  (check-equal? (test-ref compression-receipt 'strategy)
                'handoff-summary)
  (check-equal? (test-ref compression-receipt 'trigger)
                'after-human-audit)
  (check-equal? (test-ref compression-receipt 'summary-format)
                'structured-alist)
  (check-equal? (test-ref compression-receipt 'lineage-kind)
                'compressed-ci-session)
  (check-equal? (test-ref compression-receipt 'source-session-ref)
                'loop-engine/current-system-build-loop/session)
  (check-equal? (test-ref compression-receipt 'runtime-executed) #f))

;;; Handoff correlation assertions ensure the public handoff row references the
;;; exact receipt rows already exposed independently on the intent.
;; : (-> Alist Alist Alist Alist Alist Alist Alist Alist Alist Alist Alist Alist)
(def (check-custom-loop-handoff-correlation handoff
                                            result-contract
                                            agent-profiles
                                            agent-harnesses
                                            agent-sessions
                                            session-agent-graph
                                            session-agent-topology-trace
                                            lineage-receipt
                                            selector-receipt
                                            resource-dispatch-receipt
                                            capability-receipt
                                            memory-receipt
                                            compression-receipt)
  (check-equal? (test-ref handoff 'agent-profiles) agent-profiles)
  (check-equal? (test-ref handoff 'agent-harnesses) agent-harnesses)
  (check-equal? (test-ref handoff 'agent-sessions) agent-sessions)
  (check-equal? (test-ref handoff 'session-agent-graph)
                session-agent-graph)
  (check-equal? (test-ref handoff 'session-agent-topology-trace)
                session-agent-topology-trace)
  (check-equal? (test-ref handoff 'receipt-contracts)
                expected-loop-engine-receipt-contracts)
  (check-equal? (test-ref handoff 'lineage-receipt) lineage-receipt)
  (check-equal? (test-ref handoff 'selector-receipt) selector-receipt)
  (check-equal? (test-ref handoff 'resource-dispatch-receipt)
                resource-dispatch-receipt)
  (let (handoff-capability-receipt
        (test-ref handoff 'capability-receipt))
    (check-equal? (loop-engine-capability-receipt? capability-receipt) #t)
    (check-equal? (loop-engine-capability-receipt?
                   handoff-capability-receipt)
                  #f)
    (check-equal? (object? handoff-capability-receipt) #f)
    (check-equal? (pair? handoff-capability-receipt) #t)
    (check-equal? (test-ref handoff-capability-receipt 'backend)
                  (test-ref capability-receipt 'backend))
    (check-equal? (test-ref handoff-capability-receipt 'valid?)
                  (test-ref capability-receipt 'valid?))
    (check-equal? (test-ref handoff-capability-receipt 'diagnostics)
                  (test-ref capability-receipt 'diagnostics)))
  (check-equal? (test-ref handoff 'memory-receipt) memory-receipt)
  (check-equal? (test-ref handoff 'compression-receipt)
                compression-receipt)
  (check-equal? (test-field-values
                 (test-ref handoff
                           'spec-evolution-human-audit-review-items)
                 'pattern)
                (list expected-loop-engine-spec-evolution-proposal-id))
  (check-equal? (test-field-values
                 (test-ref handoff
                           'spec-evolution-runtime-manifest-rows)
                 'eligible-for-checked-mutation)
                '(#t))
  (check-equal? (test-field-values
                 (test-ref handoff 'session-selector-receipts)
                 'selector-id)
                '(selector/current-system-loop-router))
  (check-equal? (test-field-values
                 (test-ref handoff 'session-materialization-receipts)
                 'session-ref)
                '(current-system-build-session
                  current-system-recovery-session))
  (check-equal? (test-ref handoff 'result-contract) result-contract)
  (check-equal? (test-ref handoff 'runtime-executed) #f))

;;; Agent-boundary assertions coordinate the graph, receipt, and handoff
;;; checks against the same projected intent.
;; : (-> Alist)
(def (check-custom-loop-agent-boundary intent)
  (let ((handoff (test-ref intent 'runtime-handoff-facts))
        (result-contract (test-ref intent 'result-contract))
        (sandbox-agreement (test-ref intent 'sandbox-handoff-agreement))
        (agent-profiles (test-ref intent 'agent-profiles))
        (agent-harnesses (test-ref intent 'agent-harnesses))
        (agent-sessions (test-ref intent 'agent-sessions))
        (session-agent-graph (test-ref intent 'session-agent-graph))
        (session-agent-topology-trace
         (test-ref intent 'session-agent-topology-trace))
        (lineage-receipt (test-ref intent 'lineage-receipt))
        (selector-receipt (test-ref intent 'selector-receipt))
        (resource-dispatch-receipt
         (test-ref intent 'resource-dispatch-receipt))
        (capability-receipt
         (test-ref intent 'capability-receipt))
        (memory-receipt
         (test-ref intent 'memory-receipt))
        (compression-receipt
         (test-ref intent 'compression-receipt)))
    (check-custom-loop-agent-graph-boundary handoff
                                            result-contract
                                            sandbox-agreement
                                            agent-profiles
                                            agent-harnesses
                                            agent-sessions
                                            session-agent-graph
                                            session-agent-topology-trace)
    (check-custom-loop-policy-receipt-boundary lineage-receipt
                                               selector-receipt
                                               resource-dispatch-receipt
                                               capability-receipt
                                               memory-receipt
                                               compression-receipt)
    (check-custom-loop-handoff-correlation handoff
                                           result-contract
                                           agent-profiles
                                           agent-harnesses
                                           agent-sessions
                                           session-agent-graph
                                           session-agent-topology-trace
                                           lineage-receipt
                                           selector-receipt
                                           resource-dispatch-receipt
                                           capability-receipt
                                           memory-receipt
                                           compression-receipt)))
