;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Scenario: user-interface LangChain and LangGraph composition instances.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :clan/poo/object .all-slots .def .o .ref .slot?)
        (only-in :std/test check-equal? test-suite)
        :yuanxu/graph/types
        :yuanxu/graph/algorithms
        :yuanxu/graph/control-analysis
        :agentic-ai-lab/modules/workflow/graph/runtime-executor
        :agentic-ai-lab/modules/workflow/scenario/configuration/init-syntax
        (only-in :agentic-ai-lab/modules/workflow/scenario/composition-syntax
                 user-composition)
        :yuanxu/profile-composition/profile-bundle
        (rename-in
         (only-in :yuanxu/profile-composition/selection-syntax
                  use-module)
         (use-module use-profile-module))
        :agentic-ai-lab/modules/workflow/scenario/accessors
        (only-in :agentic-ai-lab/modules/workflow/scenario/case agentic-ai-lab-scenario-case?)
        :agentic-ai-lab/user-interface/profiles/langchain
        :agentic-ai-lab/user-interface/profiles/langgraph
        :agentic-ai-lab/user-interface/scenarios/langchain/scenario
        :agentic-ai-lab/user-interface/scenarios/langgraph/scenario)


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
  (yuanxu-graph
   'langchain-linear-chain
   (list (yuanxu-graph-node 'memory)
         (yuanxu-graph-node 'prompt)
         (yuanxu-graph-node 'model)
         (yuanxu-graph-node 'parser)
         (yuanxu-graph-node 'parsed-output))
   (list (yuanxu-graph-edge 'memory 'prompt)
         (yuanxu-graph-edge 'prompt 'model)
         (yuanxu-graph-edge 'model 'parser)
         (yuanxu-graph-edge 'parser 'parsed-output))
   (list (cons 'entry-ids '(memory))
         (cons 'finish-ids '(parsed-output)))))

(def langgraph-state-control-graph
  (yuanxu-graph
   'langgraph-state-graph
   (list (yuanxu-graph-node 'session)
         (yuanxu-graph-node 'state)
         (yuanxu-graph-node 'router)
         (yuanxu-graph-node 'agent-node)
         (yuanxu-graph-node 'tool-node)
         (yuanxu-graph-node 'terminal)
         (yuanxu-graph-node 'runtime-handoff))
   (list (yuanxu-graph-edge 'session 'state)
         (yuanxu-graph-edge 'state 'router)
         (yuanxu-graph-edge 'router 'agent-node 'conditional)
         (yuanxu-graph-edge 'agent-node 'router 'loop)
         (yuanxu-graph-edge 'router 'tool-node 'conditional)
         (yuanxu-graph-edge 'tool-node 'router 'loop)
         (yuanxu-graph-edge 'router 'terminal 'conditional)
         (yuanxu-graph-edge 'terminal 'runtime-handoff))
   (list (cons 'entry-ids '(session))
         (cons 'finish-ids '(runtime-handoff)))))

(def langgraph-broken-branch-graph
  (yuanxu-graph
   'langgraph-broken-branch
   (list (yuanxu-graph-node 'router)
         (yuanxu-graph-node 'terminal))
   (list (yuanxu-graph-edge 'router 'missing-node 'conditional))
   (list (cons 'entry-ids '(router))
         (cons 'finish-ids '(terminal)))))

(def langgraph-production-runtime-graph
  (yuanxu-graph
   'langgraph-production-runtime
   (list (yuanxu-graph-node 'session)
         (yuanxu-graph-node 'sandbox)
         (yuanxu-graph-node 'router)
         (yuanxu-graph-node 'retriever)
         (yuanxu-graph-node 'agent-node)
         (yuanxu-graph-node 'tool-node)
         (yuanxu-graph-node 'checkpoint)
         (yuanxu-graph-node 'human-approval)
         (yuanxu-graph-node 'runtime-handoff))
   (list (yuanxu-graph-edge 'session 'sandbox)
         (yuanxu-graph-edge 'sandbox 'router)
         (yuanxu-graph-edge 'router 'retriever 'conditional)
         (yuanxu-graph-edge 'retriever 'router 'loop)
         (yuanxu-graph-edge 'router 'agent-node 'conditional)
         (yuanxu-graph-edge 'agent-node 'tool-node)
         (yuanxu-graph-edge 'tool-node 'checkpoint)
         (yuanxu-graph-edge 'checkpoint 'human-approval)
         (yuanxu-graph-edge 'human-approval 'runtime-handoff))
   (list (cons 'entry-ids '(session))
         (cons 'finish-ids '(runtime-handoff)))))

(def langgraph-production-runtime-policy
  (agentic-ai-lab-graph-runtime-policy
   'langgraph-production-runtime
   'session
   'runtime-handoff
   (list (agentic-ai-lab-graph-branch-choice 'router 'retriever)
         (agentic-ai-lab-graph-branch-choice 'router 'agent-node))
   8
   #t
   #t
   #t
   #t
   #t
   #t
   #t))

(def langgraph-human-approval-missing-policy
  (agentic-ai-lab-graph-runtime-policy
   'langgraph-production-runtime
   'session
   'runtime-handoff
   (list (agentic-ai-lab-graph-branch-choice 'router 'retriever)
         (agentic-ai-lab-graph-branch-choice 'router 'agent-node))
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
  (.ref (agentic-ai-lab-scenario-case-stages composition) 'production))

(def (profile-identity profile)
  (.ref profile (if (.slot? profile 'identity) 'identity 'name)))

(def langchain-langgraph-core-test
 (test-suite "langchain and langgraph user compositions"
  (yuanxu-test-case "langchain linear chain declares one production stage"
    (let* ((stage (single-stage langchain-composition))
           (compose-payload
            (agentic-ai-lab-scenario-case-profiles langchain-composition))
           (loop-value (.ref stage 'loop)))
      (check-equal? (agentic-ai-lab-scenario-case? langchain-composition) #t)
      (check-equal? (agentic-ai-lab-scenario-case-name langchain-composition)
                    'langchain)
      (check-equal? (length (agentic-ai-lab-scenario-case-modules
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

  (yuanxu-test-case "graph core proves the LangChain case is a total linear chain"
    (let* ((analysis (yuanxu-graph-control-analysis-receipt
                      langchain-linear-control-graph))
           (metadata (.ref analysis 'metadata)))
      (check-equal? (alist-value metadata 'entry-ids)
                    '(memory))
      (check-equal? (alist-value metadata 'finish-ids)
                    '(parsed-output))
      (check-equal? (yuanxu-graph-acyclic? langchain-linear-control-graph)
                    #t)
      (check-equal? (.ref analysis 'topological-order)
                    '(memory prompt model parser parsed-output))
      (check-equal? (.ref analysis 'diagnostics) '())
      (check-equal? (alist-value metadata 'finish-total?) #t)
      (check-equal? (alist-value metadata 'conditional-edge-pairs) '())
      (check-equal? (alist-value metadata 'dead-end-ids) '())))

  (yuanxu-test-case "local composition preserves source module and selected profiles"
    (let* ((stage (single-stage audited-langchain-composition))
           (compose-payload
            (agentic-ai-lab-scenario-case-profiles
             audited-langchain-composition))
           (module-binding
            (car (agentic-ai-lab-scenario-case-modules
                  audited-langchain-composition)))
           (module (.ref module-binding 'module)))
      (check-equal? (length compose-payload) 6)
      (check-equal? (map profile-identity compose-payload)
                    '(memory prompt model parser no-tool
                      langchain-production))
      (check-equal? (.ref (.ref module 'identity) 'name) 'langchain)))

  (yuanxu-test-case "langgraph state graph declares bounded loop and handoff"
    (let* ((stage (single-stage langgraph-composition))
           (compose-payload
            (agentic-ai-lab-scenario-case-profiles langgraph-composition))
           (loop-value (.ref stage 'loop)))
      (check-equal? (agentic-ai-lab-scenario-case? langgraph-composition) #t)
      (check-equal? (agentic-ai-lab-scenario-case-name langgraph-composition)
                    'langgraph)
      (check-equal? (length (agentic-ai-lab-scenario-case-modules
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

  (yuanxu-test-case "graph core accepts explicit LangGraph loop edges"
    (let* ((analysis (yuanxu-graph-control-analysis-receipt
                      langgraph-state-control-graph))
           (metadata (.ref analysis 'metadata)))
      (check-equal? (alist-value metadata 'entry-ids)
                    '(session))
      (check-equal? (alist-value metadata 'finish-ids)
                    '(runtime-handoff))
      (check-equal? (yuanxu-graph-acyclic? langgraph-state-control-graph)
                    #f)
      (check-equal? (.ref analysis 'topological-order) #f)
      (check-equal? (.ref analysis 'diagnostics) '())
      (check-equal? (alist-value metadata 'branch-targets-declared?) #t)
      (check-equal? (alist-value metadata 'finish-total?) #t)
      (check-equal? (alist-value metadata 'loop-edge-pairs)
                    '((agent-node router) (tool-node router)))))

  (yuanxu-test-case "graph core reports undeclared LangGraph branch targets"
    (let* ((analysis (yuanxu-graph-control-analysis-receipt
                      langgraph-broken-branch-graph))
           (metadata (.ref analysis 'metadata))
           (diagnostics (.ref analysis 'diagnostics)))
      (check-equal? (alist-value metadata 'branch-targets-declared?) #f)
      (check-equal? (alist-value metadata 'finish-total?) #f)
      (check-equal? (alist-value diagnostics 'undeclared-edge-pairs)
                    '((router missing-node)))
      (check-equal? (alist-value diagnostics 'undeclared-branch-targets)
                    '(missing-node))))

  (yuanxu-test-case "runtime executor records a production LangGraph path"
    (let* ((receipt
            (agentic-ai-lab-graph-runtime-execute
             langgraph-production-runtime-graph
             langgraph-production-runtime-policy))
           (facts (agentic-ai-lab-graph-runtime-receipt->lean-facts receipt))
           (lean-source
            (agentic-ai-lab-graph-runtime-receipt->lean-module receipt)))
      (check-equal? (agentic-ai-lab-graph-runtime-receipt-ref receipt 'runtime-executed) #t)
      (check-equal? (agentic-ai-lab-graph-runtime-receipt-ref receipt 'finished) #t)
      (check-equal? (agentic-ai-lab-graph-runtime-receipt-ref receipt 'trace)
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
      (check-equal? (agentic-ai-lab-graph-runtime-receipt-ref receipt 'fuel-after) 7)
      (check-equal? (agentic-ai-lab-graph-runtime-receipt-ref receipt 'diagnostics) '())
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
      (check-equal? (agentic-ai-lab-graph-runtime-lean-fact-contract-complete?
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

  (yuanxu-test-case "runtime executor rejects missing human approval"
    (let* ((receipt
            (agentic-ai-lab-graph-runtime-execute
             langgraph-production-runtime-graph
             langgraph-human-approval-missing-policy))
           (facts (agentic-ai-lab-graph-runtime-receipt->lean-facts receipt)))
      (check-equal? (agentic-ai-lab-graph-runtime-receipt-ref receipt 'finished) #t)
      (check-equal? (alist-value (agentic-ai-lab-graph-runtime-receipt-ref receipt 'diagnostics)
                                 'human-approval-missing)
                    'langgraph-production-runtime)
      (check-equal? (alist-value facts 'graph.runtime/human-approval-sound)
                    #f)
      (check-equal? (alist-value facts
                                 'graph.runtime/reusable-production-case)
                    #f)
      (check-equal? (agentic-ai-lab-graph-runtime-lean-fact-contract-complete?
                     facts)
                    #t)))))
