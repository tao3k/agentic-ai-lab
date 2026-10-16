;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine agent/profile/session runtime projection rows.
;;; Invariant: projections describe Marlin-owned work and never open sessions.

(import (only-in :poo-flow/modules/workflow/control-plane/agent-harness
                 make-poo-flow-agent-operation
                 make-poo-flow-dispatch-receipt
                 make-poo-flow-workflow-run
                 poo-flow-agent-operation->alist
                 poo-flow-dispatch-receipt->alist
                 poo-flow-workflow-run->alist)
        "core.ss"
        "result-contract.ss"
        "runtime-agent-profile-harness.ss"
        "runtime-agent-session.ss"
        "runtime-agent-values.ss"
        "runtime-base.ss")

(export poo-flow-user-loop-engine-intent-agent-profile
        poo-flow-user-loop-engine-intent-agent-profiles
        poo-flow-user-loop-engine-intent-agent-harness
        poo-flow-user-loop-engine-intent-agent-harnesses
        poo-flow-user-loop-engine-intent-agent-session
        poo-flow-user-loop-engine-intent-agent-sessions
        poo-flow-user-loop-engine-intent-session-agent-graph
        poo-flow-user-loop-engine-intent-session-agent-topology-trace
        poo-flow-user-loop-engine-intent-workflow-run
        poo-flow-user-loop-engine-intent-dispatch-receipt
        poo-flow-user-loop-engine-intent-agent-operation
        poo-flow-user-loop-engine-intent-delegated-operation)

;; : (-> Alist Symbol [Datum])
(def (poo-flow-loop-engine-session-agent-graph-agent-node-field-values
      graph
      key)
  (poo-flow-loop-engine-runtime-agent-field-values
   (poo-flow-user-loop-engine-intent-ref graph 'agent-nodes '())
   key))

;; : (-> Alist Symbol [Datum])
(def (poo-flow-loop-engine-session-agent-graph-agent-node-flat-field-values
      graph
      key)
  (poo-flow-loop-engine-runtime-agent-flat-field-values
   (poo-flow-user-loop-engine-intent-ref graph 'agent-nodes '())
   key))

;; : (-> Alist [Symbol])
(def (poo-flow-loop-engine-session-agent-graph-output-session-refs graph)
  (poo-flow-loop-engine-session-agent-graph-agent-node-field-values
   graph
   'output-session-ref))

;; : (-> Alist [Symbol])
(def (poo-flow-loop-engine-session-agent-graph-channel-refs graph)
  (poo-flow-loop-engine-runtime-agent-unique
   (poo-flow-loop-engine-session-agent-graph-agent-node-flat-field-values
    graph
    'communication-channels)))

;; : (-> Alist [Symbol])
(def (poo-flow-loop-engine-session-agent-graph-communication-channel-refs
      graph)
  (poo-flow-loop-engine-runtime-agent-unique
   (poo-flow-loop-engine-runtime-agent-field-values
    (poo-flow-user-loop-engine-intent-ref graph 'communication-receipts '())
    'channel-id)))

;; : (-> Alist Symbol Datum Datum)
(def (poo-flow-loop-engine-session-agent-graph-registry-ref graph
                                                            key
                                                            default)
  (poo-flow-user-loop-engine-intent-ref
   (poo-flow-user-loop-engine-intent-ref graph 'registry-receipt '())
   key
   default))

;; : (-> Alist Symbol)
(def (poo-flow-loop-engine-session-agent-topology-loop-session-ref intent)
  (poo-flow-user-loop-engine-runtime-id
   (poo-flow-user-loop-engine-intent-use-case-name intent)
   "session"))

;; : (-> Symbol [Datum] [Datum] Alist)
(def (poo-flow-loop-engine-session-agent-topology-diagnostic code
                                                             expected
                                                             actual)
  (list (cons 'kind 'poo-flow.loop-engine.session-agent-topology.diagnostic)
        (cons 'code code)
        (cons 'expected expected)
        (cons 'actual actual)
        (cons 'severity 'error)
        (cons 'runtime-executed #f)))

;; : (-> Symbol [Datum] [Datum] [Alist])
(def (poo-flow-loop-engine-session-agent-topology-diagnostics/one code
                                                                 expected
                                                                 actual)
  (if (equal? expected actual)
    '()
    (list
     (poo-flow-loop-engine-session-agent-topology-diagnostic
      code
      expected
      actual))))

;;; Boundary: topology diagnostics compare agent, harness, session, registry,
;;; and communication views without mutating loop-engine intent.
;; : (-> Alist [Alist] [Alist] [Alist] Alist [Alist])
(def (poo-flow-loop-engine-session-agent-topology-diagnostics intent
                                                              profiles
                                                              harnesses
                                                              sessions
                                                              graph)
  (let ((profile-names
         (poo-flow-loop-engine-runtime-agent-field-values profiles 'name))
        (harness-profiles
         (poo-flow-loop-engine-runtime-agent-field-values harnesses 'profile))
        (agent-session-refs
         (poo-flow-loop-engine-runtime-agent-field-values sessions 'name))
        (graph-agent-ids
         (poo-flow-user-loop-engine-intent-ref graph 'agent-ids '()))
        (graph-output-session-refs
         (poo-flow-loop-engine-session-agent-graph-output-session-refs graph))
        (graph-root-session-ref
         (poo-flow-user-loop-engine-intent-ref graph 'root-session-ref #f))
        (graph-session-ids
         (poo-flow-user-loop-engine-intent-ref graph 'session-ids '()))
        (graph-durable-policy-refs
         (poo-flow-user-loop-engine-intent-ref graph 'durable-policy-refs '()))
        (graph-channel-refs
         (poo-flow-loop-engine-session-agent-graph-channel-refs graph))
        (communication-channel-refs
         (poo-flow-loop-engine-session-agent-graph-communication-channel-refs
          graph))
        (registry-root-session-ids
         (poo-flow-loop-engine-session-agent-graph-registry-ref
          graph
          'root-session-ids
          '()))
        (registry-session-ids
         (poo-flow-loop-engine-session-agent-graph-registry-ref
          graph
          'session-ids
          '()))
        (registry-active-session-ref
         (poo-flow-loop-engine-session-agent-graph-registry-ref
          graph
          'active-session-ref
          #f))
        (registry-durable-policy-refs
         (poo-flow-loop-engine-session-agent-graph-registry-ref
          graph
          'durable-policy-refs
          '()))
        (loop-session-ref
         (poo-flow-loop-engine-session-agent-topology-loop-session-ref
          intent)))
    (append
     (poo-flow-loop-engine-session-agent-topology-diagnostics/one
      'loop-agent-profile-graph-mismatch
      graph-agent-ids
      profile-names)
     (poo-flow-loop-engine-session-agent-topology-diagnostics/one
      'loop-agent-harness-graph-mismatch
      graph-agent-ids
      harness-profiles)
     (poo-flow-loop-engine-session-agent-topology-diagnostics/one
      'loop-agent-session-graph-mismatch
      graph-output-session-refs
      agent-session-refs)
     (poo-flow-loop-engine-session-agent-topology-diagnostics/one
      'loop-session-graph-registry-root-mismatch
      (list graph-root-session-ref)
      registry-root-session-ids)
     (poo-flow-loop-engine-session-agent-topology-diagnostics/one
      'loop-session-graph-registry-session-mismatch
      graph-session-ids
      registry-session-ids)
     (poo-flow-loop-engine-session-agent-topology-diagnostics/one
      'loop-session-graph-registry-active-mismatch
      loop-session-ref
      registry-active-session-ref)
     (poo-flow-loop-engine-session-agent-topology-diagnostics/one
      'loop-agent-durable-policy-registry-mismatch
      graph-durable-policy-refs
      registry-durable-policy-refs)
     (poo-flow-loop-engine-session-agent-topology-diagnostics/one
      'loop-agent-channel-communication-mismatch
      graph-channel-refs
      communication-channel-refs))))

;;; Boundary: topology trace is the bounded observability projection for
;;; multi-agent session graph validation.
;; : (-> Alist Alist)
(def (poo-flow-user-loop-engine-intent-session-agent-topology-trace intent)
  (let* ((profiles
          (poo-flow-user-loop-engine-intent-agent-profiles intent))
         (harnesses
          (poo-flow-user-loop-engine-intent-agent-harnesses intent))
         (sessions
          (poo-flow-user-loop-engine-intent-agent-sessions intent))
         (graph
          (poo-flow-user-loop-engine-intent-session-agent-graph intent))
         (profile-names
          (poo-flow-loop-engine-runtime-agent-field-values profiles 'name))
         (harness-profiles
          (poo-flow-loop-engine-runtime-agent-field-values harnesses 'profile))
         (agent-session-refs
          (poo-flow-loop-engine-runtime-agent-field-values sessions 'name))
         (graph-agent-ids
         (poo-flow-user-loop-engine-intent-ref graph 'agent-ids '()))
         (graph-output-session-refs
          (poo-flow-loop-engine-session-agent-graph-output-session-refs graph))
         (graph-root-session-ref
          (poo-flow-user-loop-engine-intent-ref graph 'root-session-ref #f))
         (graph-session-ids
          (poo-flow-user-loop-engine-intent-ref graph 'session-ids '()))
         (graph-lineage-edge-pairs
          (poo-flow-user-loop-engine-intent-ref graph
                                                'lineage-edge-pairs
                                                '()))
         (graph-durable-policy-refs
          (poo-flow-user-loop-engine-intent-ref graph
                                                'durable-policy-refs
                                                '()))
         (graph-channel-refs
          (poo-flow-loop-engine-session-agent-graph-channel-refs graph))
         (communication-channel-refs
          (poo-flow-loop-engine-session-agent-graph-communication-channel-refs
           graph))
         (communication-receipt-count
          (poo-flow-user-loop-engine-intent-ref graph
                                                'communication-receipt-count
                                                0))
         (registry-root-session-ids
          (poo-flow-loop-engine-session-agent-graph-registry-ref
           graph
           'root-session-ids
           '()))
         (registry-session-ids
          (poo-flow-loop-engine-session-agent-graph-registry-ref
           graph
           'session-ids
           '()))
         (registry-active-session-ref
          (poo-flow-loop-engine-session-agent-graph-registry-ref
           graph
           'active-session-ref
           #f))
         (registry-durable-policy-refs
          (poo-flow-loop-engine-session-agent-graph-registry-ref
           graph
           'durable-policy-refs
           '()))
         (loop-session-ref
          (poo-flow-loop-engine-session-agent-topology-loop-session-ref
           intent))
         (diagnostics
          (poo-flow-loop-engine-session-agent-topology-diagnostics
           intent
           profiles
           harnesses
           sessions
           graph)))
    (list
     (cons 'kind 'loop-engine-session-agent-topology-trace)
     (cons 'contract
           'poo-flow.loop-engine.session-agent-topology-trace.v1)
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
(def (poo-flow-user-loop-engine-intent-workflow-run intent)
  (let* ((use-case-name
          (poo-flow-user-loop-engine-intent-use-case-name intent))
         (run-id
          (poo-flow-user-loop-engine-runtime-id use-case-name "workflow-run")))
    (poo-flow-workflow-run->alist
     (make-poo-flow-workflow-run
      run-id
      (poo-flow-user-loop-engine-intent-workflow-ref intent)
      (list (cons 'use-case
                  (poo-flow-user-loop-engine-intent-ref intent 'use-case '()))
            (cons 'use-cases
                  (poo-flow-user-loop-engine-intent-ref intent 'use-cases '())))
      (poo-flow-user-loop-engine-intent-status intent)
      (poo-flow-user-loop-engine-intent-ref intent 'agent-judges '())
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
(def (poo-flow-user-loop-engine-intent-dispatch-receipt intent)
  (let* ((use-case-name
          (poo-flow-user-loop-engine-intent-use-case-name intent))
         (target-agent
          (poo-flow-user-loop-engine-primary-agent
           (poo-flow-user-loop-engine-intent-ref intent 'agent-judges '()))))
    (poo-flow-dispatch-receipt->alist
     (make-poo-flow-dispatch-receipt
      (poo-flow-user-loop-engine-runtime-id use-case-name "dispatch")
      target-agent
      (poo-flow-user-loop-engine-runtime-id use-case-name "runtime-instance")
      (poo-flow-user-loop-engine-runtime-id use-case-name "session")
      (list 'loop-engine-payload use-case-name)
      #f
      'admitted
      (poo-flow-user-loop-engine-intent-runtime-intent intent)
      (list (cons 'source 'user-config-loop-engine)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))

;;; Agent operations capture the node-level action: governor judge by default,
;;; or human-audit when the user declares a manual loop gate.
;; : (-> Alist Alist)
(def (poo-flow-user-loop-engine-intent-agent-operation intent)
  (let* ((use-case-name
          (poo-flow-user-loop-engine-intent-use-case-name intent))
         (operation-kind
          (poo-flow-user-loop-engine-intent-operation-kind intent)))
    (poo-flow-agent-operation->alist
     (make-poo-flow-agent-operation
      (poo-flow-user-loop-engine-runtime-id use-case-name "operation")
      operation-kind
      (poo-flow-user-loop-engine-runtime-id use-case-name "session")
      (poo-flow-user-loop-engine-runtime-id use-case-name "workflow-run")
      (list (cons 'use-case
                  (poo-flow-user-loop-engine-intent-ref intent 'use-case '()))
            (cons 'governor
                  (poo-flow-user-loop-engine-intent-ref intent 'governor '()))
            (cons 'agent-judges
                  (poo-flow-user-loop-engine-intent-ref intent 'agent-judges '()))
            (cons 'human-audit
                  (poo-flow-user-loop-engine-intent-ref intent 'human-audit '())))
      (poo-flow-user-loop-engine-intent-operation-result-contract intent)
      (poo-flow-user-loop-engine-intent-runtime-intent intent)
      (poo-flow-user-loop-engine-intent-status intent)
      #f
      (list (cons 'source 'user-config-loop-engine)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))

;;; Delegated operations are the Flue-style readable view over the canonical
;;; agent-operation row. They name the governor, reviewer, and human audit gate
;;; without claiming Scheme has executed the node.
;; : (-> Alist Alist)
(def (poo-flow-user-loop-engine-intent-delegated-operation intent)
  (let* ((use-case-name
          (poo-flow-user-loop-engine-intent-use-case-name intent))
         (agent-judges
          (poo-flow-user-loop-engine-intent-ref intent 'agent-judges '()))
         (governor-agent
          (poo-flow-user-loop-engine-agent-judge-ref
           agent-judges
           'governor
           'loop-governor-agent))
         (explicit-reviewer-agent
          (poo-flow-user-loop-engine-agent-judge-ref
           agent-judges
           'reviewer
           #f))
         (reviewer-agent
          (if explicit-reviewer-agent
            explicit-reviewer-agent
            (poo-flow-user-loop-engine-agent-judge-ref
             agent-judges
             'verifier
             (poo-flow-user-loop-engine-agent-judge-ref
              agent-judges
              'auditor
              'loop-reviewer-agent))))
         (auditor-agent
          (poo-flow-user-loop-engine-agent-judge-ref
           agent-judges
           'auditor
           reviewer-agent))
         (human-audit
          (poo-flow-user-loop-engine-intent-ref intent 'human-audit '())))
    (list
     (cons 'kind 'delegated-operation)
     (cons 'contract 'poo-flow.loop-engine.delegated-operation.v1)
     (cons 'source 'user-config-loop-engine)
     (cons 'object-family 'agent-operation)
     (cons 'operation-ref
           (poo-flow-user-loop-engine-runtime-id use-case-name "operation"))
     (cons 'operation-kind
           (poo-flow-user-loop-engine-intent-operation-kind intent))
     (cons 'workflow-run-ref
           (poo-flow-user-loop-engine-runtime-id use-case-name "workflow-run"))
     (cons 'session-ref
           (poo-flow-user-loop-engine-runtime-id use-case-name "session"))
     (cons 'child-session-ref
           (poo-flow-user-loop-engine-runtime-id
            use-case-name
            "delegate-session"))
     (cons 'workflow-ref
           (poo-flow-user-loop-engine-intent-workflow-ref intent))
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
           (poo-flow-user-loop-engine-intent-result-contract intent))
     (cons 'structured-result-contract
           (poo-flow-user-loop-engine-intent-operation-result-contract
            intent))
     (cons 'runtime-intent
           (poo-flow-user-loop-engine-intent-runtime-intent intent))
     (cons 'status
           (poo-flow-user-loop-engine-intent-status intent))
     (cons 'descriptor-realized? #f)
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f))))
