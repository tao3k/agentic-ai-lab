;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine agent/profile/session runtime projection rows.
;;; Invariant: projections describe Marlin-owned work and never open sessions.

(import (only-in :yuanxu/modules/funflow/control-plane/agent-harness
                 make-yuanxu-agent-operation
                 make-yuanxu-dispatch-receipt
                 make-yuanxu-workflow-run
                 yuanxu-agent-operation->alist
                 yuanxu-dispatch-receipt->alist
                 yuanxu-workflow-run->alist)
        "core.ss"
        "result-contract.ss"
        "runtime-agent-profile-harness.ss"
        "runtime-agent-session.ss"
        "runtime-agent-values.ss"
        "runtime-base.ss")

(export agentic-ai-lab-user-loop-engine-intent-agent-profile
        agentic-ai-lab-user-loop-engine-intent-agent-profiles
        agentic-ai-lab-user-loop-engine-intent-agent-harness
        agentic-ai-lab-user-loop-engine-intent-agent-harnesses
        agentic-ai-lab-user-loop-engine-intent-agent-session
        agentic-ai-lab-user-loop-engine-intent-agent-sessions
        agentic-ai-lab-user-loop-engine-intent-session-agent-graph
        agentic-ai-lab-user-loop-engine-intent-session-agent-topology-trace
        agentic-ai-lab-user-loop-engine-intent-workflow-run
        agentic-ai-lab-user-loop-engine-intent-dispatch-receipt
        agentic-ai-lab-user-loop-engine-intent-agent-operation
        agentic-ai-lab-user-loop-engine-intent-delegated-operation)

;; : (-> Alist Symbol [Datum])
(def (agentic-ai-lab-loop-engine-session-agent-graph-agent-node-field-values
      graph
      key)
  (agentic-ai-lab-loop-engine-runtime-agent-field-values
   (agentic-ai-lab-user-loop-engine-intent-ref graph 'agent-nodes '())
   key))

;; : (-> Alist Symbol [Datum])
(def (agentic-ai-lab-loop-engine-session-agent-graph-agent-node-flat-field-values
      graph
      key)
  (agentic-ai-lab-loop-engine-runtime-agent-flat-field-values
   (agentic-ai-lab-user-loop-engine-intent-ref graph 'agent-nodes '())
   key))

;; : (-> Alist [Symbol])
(def (agentic-ai-lab-loop-engine-session-agent-graph-output-session-refs graph)
  (agentic-ai-lab-loop-engine-session-agent-graph-agent-node-field-values
   graph
   'output-session-ref))

;; : (-> Alist [Symbol])
(def (agentic-ai-lab-loop-engine-session-agent-graph-channel-refs graph)
  (agentic-ai-lab-loop-engine-runtime-agent-unique
   (agentic-ai-lab-loop-engine-session-agent-graph-agent-node-flat-field-values
    graph
    'communication-channels)))

;; : (-> Alist [Symbol])
(def (agentic-ai-lab-loop-engine-session-agent-graph-communication-channel-refs
      graph)
  (agentic-ai-lab-loop-engine-runtime-agent-unique
   (agentic-ai-lab-loop-engine-runtime-agent-field-values
    (agentic-ai-lab-user-loop-engine-intent-ref graph 'communication-receipts '())
    'channel-id)))

;; : (-> Alist Symbol Datum Datum)
(def (agentic-ai-lab-loop-engine-session-agent-graph-registry-ref graph
                                                            key
                                                            default)
  (agentic-ai-lab-user-loop-engine-intent-ref
   (agentic-ai-lab-user-loop-engine-intent-ref graph 'registry-receipt '())
   key
   default))

;; : (-> Alist Symbol)
(def (agentic-ai-lab-loop-engine-session-agent-topology-loop-session-ref intent)
  (agentic-ai-lab-user-loop-engine-runtime-id
   (agentic-ai-lab-user-loop-engine-intent-use-case-name intent)
   "session"))

;; : (-> Symbol [Datum] [Datum] Alist)
(def (agentic-ai-lab-loop-engine-session-agent-topology-diagnostic code
                                                             expected
                                                             actual)
  (list (cons 'kind 'agentic-ai-lab.loop-engine.session-agent-topology.diagnostic)
        (cons 'code code)
        (cons 'expected expected)
        (cons 'actual actual)
        (cons 'severity 'error)
        (cons 'runtime-executed #f)))

;; : (-> Symbol [Datum] [Datum] [Alist])
(def (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics/one code
                                                                 expected
                                                                 actual)
  (if (equal? expected actual)
    '()
    (list
     (agentic-ai-lab-loop-engine-session-agent-topology-diagnostic
      code
      expected
      actual))))

;;; Boundary: topology diagnostics compare agent, harness, session, registry,
;;; and communication views without mutating loop-engine intent.
;; : (-> Alist [Alist] [Alist] [Alist] Alist [Alist])
(def (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics intent
                                                              profiles
                                                              harnesses
                                                              sessions
                                                              graph)
  (let ((profile-names
         (agentic-ai-lab-loop-engine-runtime-agent-field-values profiles 'name))
        (harness-profiles
         (agentic-ai-lab-loop-engine-runtime-agent-field-values harnesses 'profile))
        (agent-session-refs
         (agentic-ai-lab-loop-engine-runtime-agent-field-values sessions 'name))
        (graph-agent-ids
         (agentic-ai-lab-user-loop-engine-intent-ref graph 'agent-ids '()))
        (graph-output-session-refs
         (agentic-ai-lab-loop-engine-session-agent-graph-output-session-refs graph))
        (graph-root-session-ref
         (agentic-ai-lab-user-loop-engine-intent-ref graph 'root-session-ref #f))
        (graph-session-ids
         (agentic-ai-lab-user-loop-engine-intent-ref graph 'session-ids '()))
        (graph-durable-policy-refs
         (agentic-ai-lab-user-loop-engine-intent-ref graph 'durable-policy-refs '()))
        (graph-channel-refs
         (agentic-ai-lab-loop-engine-session-agent-graph-channel-refs graph))
        (communication-channel-refs
         (agentic-ai-lab-loop-engine-session-agent-graph-communication-channel-refs
          graph))
        (registry-root-session-ids
         (agentic-ai-lab-loop-engine-session-agent-graph-registry-ref
          graph
          'root-session-ids
          '()))
        (registry-session-ids
         (agentic-ai-lab-loop-engine-session-agent-graph-registry-ref
          graph
          'session-ids
          '()))
        (registry-active-session-ref
         (agentic-ai-lab-loop-engine-session-agent-graph-registry-ref
          graph
          'active-session-ref
          #f))
        (registry-durable-policy-refs
         (agentic-ai-lab-loop-engine-session-agent-graph-registry-ref
          graph
          'durable-policy-refs
          '()))
        (loop-session-ref
         (agentic-ai-lab-loop-engine-session-agent-topology-loop-session-ref
          intent)))
    (append
     (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics/one
      'loop-agent-profile-graph-mismatch
      graph-agent-ids
      profile-names)
     (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics/one
      'loop-agent-harness-graph-mismatch
      graph-agent-ids
      harness-profiles)
     (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics/one
      'loop-agent-session-graph-mismatch
      graph-output-session-refs
      agent-session-refs)
     (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics/one
      'loop-session-graph-registry-root-mismatch
      (list graph-root-session-ref)
      registry-root-session-ids)
     (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics/one
      'loop-session-graph-registry-session-mismatch
      graph-session-ids
      registry-session-ids)
     (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics/one
      'loop-session-graph-registry-active-mismatch
      loop-session-ref
      registry-active-session-ref)
     (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics/one
      'loop-agent-durable-policy-registry-mismatch
      graph-durable-policy-refs
      registry-durable-policy-refs)
     (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics/one
      'loop-agent-channel-communication-mismatch
      graph-channel-refs
      communication-channel-refs))))

;;; Boundary: topology trace is the bounded observability projection for
;;; multi-agent session graph validation.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-loop-engine-intent-session-agent-topology-trace intent)
  (let* ((profiles
          (agentic-ai-lab-user-loop-engine-intent-agent-profiles intent))
         (harnesses
          (agentic-ai-lab-user-loop-engine-intent-agent-harnesses intent))
         (sessions
          (agentic-ai-lab-user-loop-engine-intent-agent-sessions intent))
         (graph
          (agentic-ai-lab-user-loop-engine-intent-session-agent-graph intent))
         (profile-names
          (agentic-ai-lab-loop-engine-runtime-agent-field-values profiles 'name))
         (harness-profiles
          (agentic-ai-lab-loop-engine-runtime-agent-field-values harnesses 'profile))
         (agent-session-refs
          (agentic-ai-lab-loop-engine-runtime-agent-field-values sessions 'name))
         (graph-agent-ids
         (agentic-ai-lab-user-loop-engine-intent-ref graph 'agent-ids '()))
         (graph-output-session-refs
          (agentic-ai-lab-loop-engine-session-agent-graph-output-session-refs graph))
         (graph-root-session-ref
          (agentic-ai-lab-user-loop-engine-intent-ref graph 'root-session-ref #f))
         (graph-session-ids
          (agentic-ai-lab-user-loop-engine-intent-ref graph 'session-ids '()))
         (graph-lineage-edge-pairs
          (agentic-ai-lab-user-loop-engine-intent-ref graph
                                                'lineage-edge-pairs
                                                '()))
         (graph-durable-policy-refs
          (agentic-ai-lab-user-loop-engine-intent-ref graph
                                                'durable-policy-refs
                                                '()))
         (graph-channel-refs
          (agentic-ai-lab-loop-engine-session-agent-graph-channel-refs graph))
         (communication-channel-refs
          (agentic-ai-lab-loop-engine-session-agent-graph-communication-channel-refs
           graph))
         (communication-receipt-count
          (agentic-ai-lab-user-loop-engine-intent-ref graph
                                                'communication-receipt-count
                                                0))
         (registry-root-session-ids
          (agentic-ai-lab-loop-engine-session-agent-graph-registry-ref
           graph
           'root-session-ids
           '()))
         (registry-session-ids
          (agentic-ai-lab-loop-engine-session-agent-graph-registry-ref
           graph
           'session-ids
           '()))
         (registry-active-session-ref
          (agentic-ai-lab-loop-engine-session-agent-graph-registry-ref
           graph
           'active-session-ref
           #f))
         (registry-durable-policy-refs
          (agentic-ai-lab-loop-engine-session-agent-graph-registry-ref
           graph
           'durable-policy-refs
           '()))
         (loop-session-ref
          (agentic-ai-lab-loop-engine-session-agent-topology-loop-session-ref
           intent))
         (diagnostics
          (agentic-ai-lab-loop-engine-session-agent-topology-diagnostics
           intent
           profiles
           harnesses
           sessions
           graph)))
    (list
     (cons 'kind 'loop-engine-session-agent-topology-trace)
     (cons 'contract
           'agentic-ai-lab.loop-engine.session-agent-topology-trace.v1)
     (cons 'profile-names profile-names)
     (cons 'harness-profiles harness-profiles)
     (cons 'agent-session-refs agent-session-refs)
     (cons 'graph-agent-ids graph-agent-ids)
     (cons 'graph-root-session-ref graph-root-session-ref)
     (cons 'loop-session-ref loop-session-ref)
     (cons 'graph-session-ids graph-session-ids)
     (cons 'graph-output-session-refs graph-output-session-refs)
     (cons 'graph-lineage-edge-pairs graph-lineage-edge-pairs)
     (cons 'graph-durable-policy-refs graph-durable-policy-refs)
     (cons 'graph-channel-refs graph-channel-refs)
     (cons 'communication-channel-refs communication-channel-refs)
     (cons 'communication-receipt-count communication-receipt-count)
     (cons 'registry-root-session-ids registry-root-session-ids)
     (cons 'registry-session-ids registry-session-ids)
     (cons 'registry-active-session-ref registry-active-session-ref)
     (cons 'registry-durable-policy-refs registry-durable-policy-refs)
     (cons 'valid? (null? diagnostics))
     (cons 'diagnostic-count (length diagnostics))
     (cons 'diagnostics diagnostics)
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f))))

;;; The workflow-run projection is an admission plan for runtime lowering. It
;;; is not evidence that a workflow has started.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-loop-engine-intent-workflow-run intent)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (run-id
          (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "workflow-run")))
    (yuanxu-workflow-run->alist
     (make-yuanxu-workflow-run
      run-id
      (agentic-ai-lab-user-loop-engine-intent-workflow-ref intent)
      (list (cons 'use-case
                  (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-case '()))
            (cons 'use-cases
                  (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-cases '())))
      (agentic-ai-lab-user-loop-engine-intent-status intent)
      (agentic-ai-lab-user-loop-engine-intent-ref intent 'agent-judges '())
      (list 'loop-engine-events use-case-name)
      '()
      #f
      #f
      #f
      (list (cons 'source 'user-config-loop-engine)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))

;;; Dispatch receipts are projected separately from workflow runs so async
;;; agent input does not pretend to be a terminal workflow result.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-loop-engine-intent-dispatch-receipt intent)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (target-agent
          (agentic-ai-lab-user-loop-engine-primary-agent
           (agentic-ai-lab-user-loop-engine-intent-ref intent 'agent-judges '()))))
    (yuanxu-dispatch-receipt->alist
     (make-yuanxu-dispatch-receipt
      (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "dispatch")
      target-agent
      (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "runtime-instance")
      (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "session")
      (list 'loop-engine-payload use-case-name)
      #f
      'admitted
      (agentic-ai-lab-user-loop-engine-intent-runtime-intent intent)
      (list (cons 'source 'user-config-loop-engine)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))

;;; Agent operations capture the node-level action: governor judge by default,
;;; or human-audit when the user declares a manual loop gate.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-loop-engine-intent-agent-operation intent)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (operation-kind
          (agentic-ai-lab-user-loop-engine-intent-operation-kind intent)))
    (yuanxu-agent-operation->alist
     (make-yuanxu-agent-operation
      (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "operation")
      operation-kind
      (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "session")
      (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "workflow-run")
      (list (cons 'use-case
                  (agentic-ai-lab-user-loop-engine-intent-ref intent 'use-case '()))
            (cons 'governor
                  (agentic-ai-lab-user-loop-engine-intent-ref intent 'governor '()))
            (cons 'agent-judges
                  (agentic-ai-lab-user-loop-engine-intent-ref intent 'agent-judges '()))
            (cons 'human-audit
                  (agentic-ai-lab-user-loop-engine-intent-ref intent 'human-audit '())))
      (agentic-ai-lab-user-loop-engine-intent-operation-result-contract intent)
      (agentic-ai-lab-user-loop-engine-intent-runtime-intent intent)
      (agentic-ai-lab-user-loop-engine-intent-status intent)
      #f
      (list (cons 'source 'user-config-loop-engine)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))

;;; Delegated operations are the Flue-style readable view over the canonical
;;; agent-operation row. They name the governor, reviewer, and human audit gate
;;; without claiming Scheme has executed the node.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-loop-engine-intent-delegated-operation intent)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (agent-judges
          (agentic-ai-lab-user-loop-engine-intent-ref intent 'agent-judges '()))
         (governor-agent
          (agentic-ai-lab-user-loop-engine-agent-judge-ref
           agent-judges
           'governor
           'loop-governor-agent))
         (explicit-reviewer-agent
          (agentic-ai-lab-user-loop-engine-agent-judge-ref
           agent-judges
           'reviewer
           #f))
         (reviewer-agent
          (if explicit-reviewer-agent
            explicit-reviewer-agent
            (agentic-ai-lab-user-loop-engine-agent-judge-ref
             agent-judges
             'verifier
             (agentic-ai-lab-user-loop-engine-agent-judge-ref
              agent-judges
              'auditor
              'loop-reviewer-agent))))
         (auditor-agent
          (agentic-ai-lab-user-loop-engine-agent-judge-ref
           agent-judges
           'auditor
           reviewer-agent))
         (human-audit
          (agentic-ai-lab-user-loop-engine-intent-ref intent 'human-audit '())))
    (list
     (cons 'kind 'delegated-operation)
     (cons 'contract 'agentic-ai-lab.loop-engine.delegated-operation.v1)
     (cons 'source 'user-config-loop-engine)
     (cons 'object-family 'agent-operation)
     (cons 'operation-ref
           (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "operation"))
     (cons 'operation-kind
           (agentic-ai-lab-user-loop-engine-intent-operation-kind intent))
     (cons 'workflow-run-ref
           (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "workflow-run"))
     (cons 'session-ref
           (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "session"))
     (cons 'child-session-ref
           (agentic-ai-lab-user-loop-engine-runtime-id
            use-case-name
            "delegate-session"))
     (cons 'workflow-ref
           (agentic-ai-lab-user-loop-engine-intent-workflow-ref intent))
     (cons 'governor-agent governor-agent)
     (cons 'reviewer-agent reviewer-agent)
     (cons 'reviewer-role
           (if explicit-reviewer-agent 'reviewer 'verifier))
     (cons 'auditor-agent auditor-agent)
     (cons 'human-audit human-audit)
     (cons 'human-audit-profile
           (if (null? human-audit) #f 'human-audit))
     (cons 'human-audit-required?
           (not (null? human-audit)))
     (cons 'result-contract
           (agentic-ai-lab-user-loop-engine-intent-result-contract intent))
     (cons 'structured-result-contract
           (agentic-ai-lab-user-loop-engine-intent-operation-result-contract
            intent))
     (cons 'runtime-intent
           (agentic-ai-lab-user-loop-engine-intent-runtime-intent intent))
     (cons 'status
           (agentic-ai-lab-user-loop-engine-intent-status intent))
     (cons 'descriptor-realized? #f)
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f))))
