;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scenario: user-interface LangChain and LangGraph composition instances.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :clan/poo/object .all-slots .def .o .ref .slot?)
        (only-in :std/test check-equal? test-suite)
        :core/graph/types
        :core/graph/algorithms
        :core/graph/control-analysis
        :poo-flow/modules/workflow/graph/runtime-executor
        :poo-flow/modules/workflow/scenario/configuration/init-syntax
        (only-in :poo-flow/modules/workflow/scenario/composition-syntax
                 user-composition)
        :core/profile-composition/profile-bundle
        (rename-in
         (only-in :core/profile-composition/selection-syntax
                  use-module)
         (use-module use-profile-module))
        :poo-flow/modules/workflow/scenario/accessors
        (only-in :poo-flow/modules/workflow/scenario/case poo-flow-scenario-case?)
        :poo-flow/user-interface/profiles/langchain
        :poo-flow/user-interface/profiles/langgraph
        :poo-flow/user-interface/scenarios/langchain/scenario
        :poo-flow/user-interface/scenarios/langgraph/scenario)


(def langchain-composition
  langchain-scenario)

(def langgraph-composition
  langgraph-scenario)

(.def AuditedLangChainModelProfile
  (identity 'model)
  (name 'langchain-audited-chat-model)
  (contract 'single-turn-input-output)
  (policy 'audit-model-call-before-terminal))

(user-composition audited-langchain-composition
  (compose profiles
    (use-profile-module LangChainModule as chain memory prompt)
    AuditedLangChainModelProfile
    (use-profile-module LangChainModule as chain parser no-tool)
    LangChainProductionProfile))

(def langchain-linear-control-graph
  (poo-flow-graph
   'langchain-linear-chain
   (list (poo-flow-graph-node 'memory)
         (poo-flow-graph-node 'prompt)
         (poo-flow-graph-node 'model)
         (poo-flow-graph-node 'parser)
         (poo-flow-graph-node 'parsed-output))
   (list (poo-flow-graph-edge 'memory 'prompt)
         (poo-flow-graph-edge 'prompt 'model)
         (poo-flow-graph-edge 'model 'parser)
         (poo-flow-graph-edge 'parser 'parsed-output))
   (list (cons 'entry-ids '(memory))
         (cons 'finish-ids '(parsed-output)))))

(def langgraph-state-control-graph
  (poo-flow-graph
   'langgraph-state-graph
   (list (poo-flow-graph-node 'session)
         (poo-flow-graph-node 'state)
         (poo-flow-graph-node 'router)
         (poo-flow-graph-node 'agent-node)
         (poo-flow-graph-node 'tool-node)
         (poo-flow-graph-node 'terminal)
         (poo-flow-graph-node 'runtime-handoff))
   (list (poo-flow-graph-edge 'session 'state)
         (poo-flow-graph-edge 'state 'router)
         (poo-flow-graph-edge 'router 'agent-node 'conditional)
         (poo-flow-graph-edge 'agent-node 'router 'loop)
         (poo-flow-graph-edge 'router 'tool-node 'conditional)
         (poo-flow-graph-edge 'tool-node 'router 'loop)
         (poo-flow-graph-edge 'router 'terminal 'conditional)
         (poo-flow-graph-edge 'terminal 'runtime-handoff))
   (list (cons 'entry-ids '(session))
         (cons 'finish-ids '(runtime-handoff)))))

(def langgraph-broken-branch-graph
  (poo-flow-graph
   'langgraph-broken-branch
   (list (poo-flow-graph-node 'router)
         (poo-flow-graph-node 'terminal))
   (list (poo-flow-graph-edge 'router 'missing-node 'conditional))
   (list (cons 'entry-ids '(router))
         (cons 'finish-ids '(terminal)))))

(def langgraph-production-runtime-graph
  (poo-flow-graph
   'langgraph-production-runtime
   (list (poo-flow-graph-node 'session)
         (poo-flow-graph-node 'sandbox)
         (poo-flow-graph-node 'router)
         (poo-flow-graph-node 'retriever)
         (poo-flow-graph-node 'agent-node)
         (poo-flow-graph-node 'tool-node)
         (poo-flow-graph-node 'checkpoint)
         (poo-flow-graph-node 'human-approval)
         (poo-flow-graph-node 'runtime-handoff))
   (list (poo-flow-graph-edge 'session 'sandbox)
         (poo-flow-graph-edge 'sandbox 'router)
         (poo-flow-graph-edge 'router 'retriever 'conditional)
         (poo-flow-graph-edge 'retriever 'router 'loop)
         (poo-flow-graph-edge 'router 'agent-node 'conditional)
         (poo-flow-graph-edge 'agent-node 'tool-node)
         (poo-flow-graph-edge 'tool-node 'checkpoint)
         (poo-flow-graph-edge 'checkpoint 'human-approval)
         (poo-flow-graph-edge 'human-approval 'runtime-handoff))
   (list (cons 'entry-ids '(session))
         (cons 'finish-ids '(runtime-handoff)))))

(def langgraph-production-runtime-policy
  (poo-flow-graph-runtime-policy
   'langgraph-production-runtime
   'session
   'runtime-handoff
   (list (poo-flow-graph-branch-choice 'router 'retriever)
         (poo-flow-graph-branch-choice 'router 'agent-node))
   8
   #t
   #t
   #t
   #t
   #t
   #t
   #t))

(def langgraph-human-approval-missing-policy
  (poo-flow-graph-runtime-policy
   'langgraph-production-runtime
   'session
   'runtime-handoff
   (list (poo-flow-graph-branch-choice 'router 'retriever)
         (poo-flow-graph-branch-choice 'router 'agent-node))
   8
   #t
   #t
   #t
   #t
   #f
   #t
   #t))

(def (alist-value alist key)
  (let loop ((remaining alist))
    (cond
     ((null? remaining) #f)
     ((eq? (caar remaining) key) (cdar remaining))
     (else (loop (cdr remaining))))))

(def (string-contains? value needle)
  (let ((value-length (string-length value))
        (needle-length (string-length needle)))
    (let loop ((index 0))
      (cond
       ((= needle-length 0) #t)
       ((> (+ index needle-length) value-length) #f)
       ((string-prefix-at? value needle index 0 needle-length) #t)
       (else (loop (+ index 1)))))))

(def (string-prefix-at? value needle value-index needle-index needle-length)
  (cond
   ((= needle-index needle-length) #t)
   ((char=? (string-ref value (+ value-index needle-index))
            (string-ref needle needle-index))
    (string-prefix-at? value
                       needle
                       value-index
                       (+ needle-index 1)
                       needle-length))
   (else #f)))

(def (single-stage composition)
  (.ref (poo-flow-scenario-case-stages composition) 'production))

(def (profile-identity profile)
  (.ref profile (if (.slot? profile 'identity) 'identity 'name)))

(def langchain-langgraph-core-test
 (test-suite "langchain and langgraph user compositions"
  (poo-flow-test-case "langchain linear chain declares one production stage"
    (let* ((stage (single-stage langchain-composition))
           (compose-payload
            (poo-flow-scenario-case-profiles langchain-composition))
           (loop-value (.ref stage 'loop)))
      (check-equal? (poo-flow-scenario-case? langchain-composition) #t)
      (check-equal? (poo-flow-scenario-case-name langchain-composition)
                    'langchain)
      (check-equal? (length (poo-flow-scenario-case-modules
                             langchain-composition))
                    1)
      (check-equal? (length compose-payload) 6)
      (check-equal? (.ref stage 'graph) 'langchain-linear-chain)
      (check-equal? (.ref loop-value 'fuel) 1)
      (check-equal? (.ref loop-value 'exit) 'parsed-output)
      (check-equal? (.all-slots (.ref stage 'proofs))
                    '(chain-order
                      prompt-before-model
                      parser-after-model
                      no-implicit-tool-branch))))

  (poo-flow-test-case "graph core proves the LangChain case is a total linear chain"
    (let* ((analysis (poo-flow-graph-control-analysis-receipt
                      langchain-linear-control-graph))
           (metadata (.ref analysis 'metadata)))
      (check-equal? (alist-value metadata 'entry-ids)
                    '(memory))
      (check-equal? (alist-value metadata 'finish-ids)
                    '(parsed-output))
      (check-equal? (poo-flow-graph-acyclic? langchain-linear-control-graph)
                    #t)
      (check-equal? (.ref analysis 'topological-order)
                    '(memory prompt model parser parsed-output))
      (check-equal? (.ref analysis 'diagnostics) '())
      (check-equal? (alist-value metadata 'finish-total?) #t)
      (check-equal? (alist-value metadata 'conditional-edge-pairs) '())
      (check-equal? (alist-value metadata 'dead-end-ids) '())))

  (poo-flow-test-case "local composition preserves source module and selected profiles"
    (let* ((stage (single-stage audited-langchain-composition))
           (compose-payload
            (poo-flow-scenario-case-profiles
             audited-langchain-composition))
           (module-binding
            (car (poo-flow-scenario-case-modules
                  audited-langchain-composition)))
           (module (.ref module-binding 'module)))
      (check-equal? (length compose-payload) 6)
      (check-equal? (map profile-identity compose-payload)
                    '(memory prompt model parser no-tool
                      langchain-production))
      (check-equal? (.ref (.ref module 'identity) 'name) 'langchain)))

  (poo-flow-test-case "langgraph state graph declares bounded loop and handoff"
    (let* ((stage (single-stage langgraph-composition))
           (compose-payload
            (poo-flow-scenario-case-profiles langgraph-composition))
           (loop-value (.ref stage 'loop)))
      (check-equal? (poo-flow-scenario-case? langgraph-composition) #t)
      (check-equal? (poo-flow-scenario-case-name langgraph-composition)
                    'langgraph)
      (check-equal? (length (poo-flow-scenario-case-modules
                             langgraph-composition))
                    1)
      (check-equal? (length compose-payload) 8)
      (check-equal? (.ref stage 'graph) 'langgraph-state-graph)
      (check-equal? (.ref loop-value 'fuel) 8)
      (check-equal? (.ref loop-value 'exit) 'terminal-edge)
      (check-equal? (.all-slots (.ref stage 'proofs))
                    '(declared-branch-targets
                      typed-state-merge
                      bounded-loop-progress
                      explicit-runtime-handoff))
      (check-equal? (.ref stage 'handoff) 'marlin-control-plane)))

  (poo-flow-test-case "graph core accepts explicit LangGraph loop edges"
    (let* ((analysis (poo-flow-graph-control-analysis-receipt
                      langgraph-state-control-graph))
           (metadata (.ref analysis 'metadata)))
      (check-equal? (alist-value metadata 'entry-ids)
                    '(session))
      (check-equal? (alist-value metadata 'finish-ids)
                    '(runtime-handoff))
      (check-equal? (poo-flow-graph-acyclic? langgraph-state-control-graph)
                    #f)
      (check-equal? (.ref analysis 'topological-order) #f)
      (check-equal? (.ref analysis 'diagnostics) '())
      (check-equal? (alist-value metadata 'branch-targets-declared?) #t)
      (check-equal? (alist-value metadata 'finish-total?) #t)
      (check-equal? (alist-value metadata 'loop-edge-pairs)
                    '((agent-node router) (tool-node router)))))

  (poo-flow-test-case "graph core reports undeclared LangGraph branch targets"
    (let* ((analysis (poo-flow-graph-control-analysis-receipt
                      langgraph-broken-branch-graph))
           (metadata (.ref analysis 'metadata))
           (diagnostics (.ref analysis 'diagnostics)))
      (check-equal? (alist-value metadata 'branch-targets-declared?) #f)
      (check-equal? (alist-value metadata 'finish-total?) #f)
      (check-equal? (alist-value diagnostics 'undeclared-edge-pairs)
                    '((router missing-node)))
      (check-equal? (alist-value diagnostics 'undeclared-branch-targets)
                    '(missing-node))))

  (poo-flow-test-case "runtime executor records a production LangGraph path"
    (let* ((receipt
            (poo-flow-graph-runtime-execute
             langgraph-production-runtime-graph
             langgraph-production-runtime-policy))
           (facts (poo-flow-graph-runtime-receipt->lean-facts receipt))
           (lean-source
            (poo-flow-graph-runtime-receipt->lean-module receipt)))
      (check-equal? (poo-flow-graph-runtime-receipt-ref receipt 'runtime-executed) #t)
      (check-equal? (poo-flow-graph-runtime-receipt-ref receipt 'finished) #t)
      (check-equal? (poo-flow-graph-runtime-receipt-ref receipt 'trace)
                    '(session
                      sandbox
                      router
                      retriever
                      router
                      agent-node
                      tool-node
                      checkpoint
                      human-approval
                      runtime-handoff))
      (check-equal? (poo-flow-graph-runtime-receipt-ref receipt 'fuel-after) 7)
      (check-equal? (poo-flow-graph-runtime-receipt-ref receipt 'diagnostics) '())
      (check-equal? (alist-value facts 'graph.runtime/executed) #t)
      (check-equal? (alist-value facts 'graph.runtime/finished) #t)
      (check-equal? (alist-value facts 'graph.runtime/handoff-reached) #t)
      (check-equal? (alist-value facts 'graph.runtime/checkpoint-persisted)
                    #t)
      (check-equal? (alist-value facts 'graph.runtime/human-approval-sound)
                    #t)
      (check-equal? (alist-value facts
                                 'graph.runtime/reusable-production-case)
                    #t)
      (check-equal? (poo-flow-graph-runtime-lean-fact-contract-complete?
                     facts)
                    #t)
      (check-equal? (string-contains?
                     lean-source
                     "def generatedProductionRuntimeFacts")
                    #t)
      (check-equal? (string-contains?
                     lean-source
                     "theorem generatedProductionRuntimeReusable")
                    #t)))

  (poo-flow-test-case "runtime executor rejects missing human approval"
    (let* ((receipt
            (poo-flow-graph-runtime-execute
             langgraph-production-runtime-graph
             langgraph-human-approval-missing-policy))
           (facts (poo-flow-graph-runtime-receipt->lean-facts receipt)))
      (check-equal? (poo-flow-graph-runtime-receipt-ref receipt 'finished) #t)
      (check-equal? (alist-value (poo-flow-graph-runtime-receipt-ref receipt 'diagnostics)
                                 'human-approval-missing)
                    'langgraph-production-runtime)
      (check-equal? (alist-value facts 'graph.runtime/human-approval-sound)
                    #f)
      (check-equal? (alist-value facts
                                 'graph.runtime/reusable-production-case)
                    #f)
      (check-equal? (poo-flow-graph-runtime-lean-fact-contract-complete?
                     facts)
                    #t)))))
