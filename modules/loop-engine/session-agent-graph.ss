;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: lightweight loop-engine session-agent graph projection.
;;; Invariant: this owner builds report-only graph rows without importing the
;;; full runtime handoff stack or user config facades.

(import (only-in :agentic-ai-lab/modules/session/agent
                 agentic-ai-lab-session-agent-graph
                 agentic-ai-lab-session-agent-graph->alist
                 agentic-ai-lab-session-agent-node
                 agentic-ai-lab-session-agent-node->alist)
        (only-in :agentic-ai-lab/modules/session/communication
                 agentic-ai-lab-session-communication-channel-receipt
                 agentic-ai-lab-session-communication-receipt)
        (only-in :agentic-ai-lab/modules/session/objects
                 agentic-ai-lab-session-alist-ref
                 agentic-ai-lab-session-chunk
                 agentic-ai-lab-session-lineage
                 agentic-ai-lab-session-placement
                 agentic-ai-lab-session-value)
        (only-in :agentic-ai-lab/modules/session/registry
                 agentic-ai-lab-session-registry-entry
                 agentic-ai-lab-session-registry-receipt)
        "intent-utils.ss")

(export agentic-ai-lab-user-loop-engine-intent-session-agent-graph)

;; : Symbol
(def +agentic-ai-lab-loop-engine-default-result-contract+
  'agentic-ai-lab.loop-governor.node-result.v1)

;; : (-> AgentJudgeRow Symbol)
(def (agentic-ai-lab-loop-engine-agent-judge-role row)
  (car row))

;; : (-> AgentJudgeRow AgentJudgeTail)
(def (agentic-ai-lab-loop-engine-agent-judge-tail row)
  (cdr row))

;; : (-> AgentJudgeTail AgentJudgeValue)
(def (agentic-ai-lab-loop-engine-agent-judge-value tail)
  (if (pair? tail) (car tail) tail))

;; : (-> Value MaybeAgentJudgeRef)
(def (agentic-ai-lab-loop-engine-agent-judge-pair row)
  (and (pair? row)
       (symbol? (agentic-ai-lab-loop-engine-agent-judge-role row))
       (let (tail (agentic-ai-lab-loop-engine-agent-judge-tail row))
         (and (not (null? tail))
              (cons (agentic-ai-lab-loop-engine-agent-judge-role row)
                    (agentic-ai-lab-loop-engine-agent-judge-value tail))))))

;; : (-> [Value] [AgentProfileRef] [AgentProfileRef])
(def (agentic-ai-lab-loop-engine-agent-judge-pairs/rev agent-judges refs-rev)
  (cond
   ((null? agent-judges) refs-rev)
   ((agentic-ai-lab-loop-engine-agent-judge-pair (car agent-judges))
    => (lambda (role-ref)
         (agentic-ai-lab-loop-engine-agent-judge-pairs/rev
          (cdr agent-judges)
          (cons role-ref refs-rev))))
   (else
    (agentic-ai-lab-loop-engine-agent-judge-pairs/rev (cdr agent-judges)
                                                refs-rev))))

;; : (-> Alist [AgentProfileRef])
(def (agentic-ai-lab-loop-engine-intent-agent-profile-refs intent)
  (let* ((refs-rev
          (agentic-ai-lab-loop-engine-agent-judge-pairs/rev
           (agentic-ai-lab-user-loop-engine-intent-ref intent 'agent-judges '())
           '()))
         (refs-rev*
          (if (null? (agentic-ai-lab-user-loop-engine-intent-ref
                      intent
                      'human-audit
                      '()))
            refs-rev
            (cons (cons 'human-audit 'human-audit) refs-rev))))
    (reverse refs-rev*)))

;; : (-> Alist MaybeSymbol)
(def (agentic-ai-lab-loop-engine-intent-primary-sandbox-profile intent)
  (let (refs (agentic-ai-lab-user-loop-engine-intent-ref
              intent
              'sandbox-profile-refs
              '()))
    (if (null? refs) #f (car refs))))

;; : (-> Alist Symbol Symbol)
(def (agentic-ai-lab-loop-engine-intent-role-result-contract intent role)
  (let (result-rows
        (agentic-ai-lab-user-loop-engine-intent-ref intent 'result '()))
    (agentic-ai-lab-user-loop-engine-section-ref
     result-rows
     role
     (agentic-ai-lab-user-loop-engine-section-ref
      result-rows
      'default
      +agentic-ai-lab-loop-engine-default-result-contract+))))

;; : (-> Alist Symbol)
(def (agentic-ai-lab-loop-engine-first-parent-session-ref intent)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (lineage-policy
          (agentic-ai-lab-user-loop-engine-intent-ref intent 'lineage-policy '()))
         (parent-refs
          (agentic-ai-lab-user-loop-engine-intent-ref
           lineage-policy
           'parent-session-refs
           '())))
    (if (null? parent-refs)
      (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "root-session")
      (car parent-refs))))

;; : (-> Symbol String Symbol)
(def (agentic-ai-lab-loop-engine-symbol-suffix prefix suffix)
  (string->symbol
   (string-append
    (symbol->string prefix)
    "/"
    suffix)))

;; : (-> Alist [Symbol])
(def (agentic-ai-lab-loop-engine-memory-store-refs intent)
  (let loop ((policies
              (agentic-ai-lab-user-loop-engine-intent-ref
               intent
               'memory-policies
               '())))
    (cond
     ((null? policies) '())
     (else
      (let ((store-ref
             (agentic-ai-lab-user-loop-engine-intent-ref
              (car policies)
              'store
              #f)))
        (if store-ref
          (cons store-ref (loop (cdr policies)))
          (loop (cdr policies))))))))

;; : (-> Alist [Symbol])
(def (agentic-ai-lab-loop-engine-tool-refs intent)
  (agentic-ai-lab-user-loop-engine-intent-ref
   (agentic-ai-lab-user-loop-engine-intent-ref intent 'resource-policy '())
   'tool-refs
   '()))

;; : (-> Alist [Pair] [Symbol] [Symbol])
(def (agentic-ai-lab-loop-engine-agent-output-session-refs/rev intent
                                                         role-refs
                                                         output-session-refs)
  (if (null? role-refs)
    output-session-refs
    (agentic-ai-lab-loop-engine-agent-output-session-refs/rev
     intent
     (cdr role-refs)
     (cons
      (agentic-ai-lab-user-loop-engine-runtime-id
       (agentic-ai-lab-user-loop-engine-intent-use-case-name intent)
       (string-append (symbol->string (caar role-refs)) "-session"))
      output-session-refs))))

;; : (-> Alist [Symbol])
(def (agentic-ai-lab-loop-engine-agent-output-session-refs intent)
  (reverse
   (agentic-ai-lab-loop-engine-agent-output-session-refs/rev
    intent
    (agentic-ai-lab-loop-engine-intent-agent-profile-refs intent)
    '())))

;; : (-> Symbol [Symbol] [Symbol])
(def (agentic-ai-lab-loop-engine-peer-session-refs session-id session-ids)
  (cond
   ((null? session-ids) '())
   ((eq? session-id (car session-ids))
    (agentic-ai-lab-loop-engine-peer-session-refs session-id (cdr session-ids)))
   (else
    (cons (car session-ids)
          (agentic-ai-lab-loop-engine-peer-session-refs
           session-id
           (cdr session-ids))))))

;; : (-> Alist Symbol PooSession)
(def (agentic-ai-lab-loop-engine-session-value intent session-id)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (root-session-ref
          (agentic-ai-lab-loop-engine-first-parent-session-ref intent))
         (loop-session-ref
          (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "session"))
         (sandbox-profile-ref
          (or (agentic-ai-lab-loop-engine-intent-primary-sandbox-profile intent)
              'sandbox/unspecified))
         (parent-session-ids
          (cond
           ((eq? session-id root-session-ref) '())
           ((eq? session-id loop-session-ref) (list root-session-ref))
           (else (list loop-session-ref)))))
    (agentic-ai-lab-session-value
     session-id
     (list
      (agentic-ai-lab-session-chunk
       (agentic-ai-lab-loop-engine-symbol-suffix session-id "summary")
       'system
       "Loop-engine report-only session topology node."))
     (agentic-ai-lab-session-lineage
      session-id
      parent-session-ids
      'loop-engine-topology)
     (agentic-ai-lab-session-placement sandbox-profile-ref)
     (list (cons 'source 'loop-engine-session-agent-graph)
           (cons 'use-case use-case-name)
           (cons 'runtime-owner "marlin-agent-core")
           (cons 'runtime-executed #f)))))

;; : (-> Alist Pair [Symbol] PooSessionAgentNode)
(def (agentic-ai-lab-loop-engine-session-agent-node intent
                                              role-ref
                                              output-session-refs)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (role (car role-ref))
         (agent-id (cdr role-ref))
         (project-ref 'loop-engine/project)
         (root-session-ref
          (agentic-ai-lab-loop-engine-first-parent-session-ref intent))
         (loop-session-ref
          (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "session"))
         (output-session-ref
          (agentic-ai-lab-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-session")))
         (system-session-ref
          (agentic-ai-lab-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-system-session")))
         (channel-ref
          (agentic-ai-lab-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-channel")))
         (sandbox-profile-ref
          (or (agentic-ai-lab-loop-engine-intent-primary-sandbox-profile intent)
              'sandbox/unspecified)))
    (agentic-ai-lab-session-agent-node
     agent-id
     project-ref
     root-session-ref
     loop-session-ref
     system-session-ref
     loop-session-ref
     output-session-ref
     (agentic-ai-lab-loop-engine-peer-session-refs
      output-session-ref
      output-session-refs)
     (list channel-ref)
     (agentic-ai-lab-loop-engine-symbol-suffix agent-id "model-policy")
     (agentic-ai-lab-loop-engine-symbol-suffix agent-id "prompt-policy")
     (agentic-ai-lab-loop-engine-symbol-suffix agent-id "tool-policy")
     (agentic-ai-lab-loop-engine-symbol-suffix agent-id "hook-tool-policy")
     (agentic-ai-lab-loop-engine-symbol-suffix agent-id "resource-policy")
     (agentic-ai-lab-loop-engine-symbol-suffix agent-id "durable-policy")
     (agentic-ai-lab-loop-engine-tool-refs intent)
     (agentic-ai-lab-loop-engine-memory-store-refs intent)
     sandbox-profile-ref
     role
     (agentic-ai-lab-loop-engine-intent-role-result-contract intent role)
     (list (cons 'source 'loop-engine-session-agent-graph)
           (cons 'use-case use-case-name)
           (cons 'runtime-owner "marlin-agent-core")
           (cons 'runtime-executed #f)))))

;; : (-> Alist [Pair] [Symbol] [PooSessionAgentNode] [PooSessionAgentNode])
(def (agentic-ai-lab-loop-engine-session-agent-nodes/rev intent
                                                   role-refs
                                                   output-session-refs
                                                   agent-nodes)
  (if (null? role-refs)
    agent-nodes
    (agentic-ai-lab-loop-engine-session-agent-nodes/rev
     intent
     (cdr role-refs)
     output-session-refs
     (cons (agentic-ai-lab-loop-engine-session-agent-node
            intent
            (car role-refs)
            output-session-refs)
           agent-nodes))))

;; : (-> Alist [Pair] [Symbol] [PooSessionAgentNode])
(def (agentic-ai-lab-loop-engine-session-agent-nodes intent
                                               role-refs
                                               output-session-refs)
  (reverse
   (agentic-ai-lab-loop-engine-session-agent-nodes/rev
    intent
    role-refs
    output-session-refs
    '())))

;; : (-> Alist Pair PooSessionCommunicationChannelReceipt)
(def (agentic-ai-lab-loop-engine-session-agent-communication-channel-receipt
      intent
      role-ref)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (role (car role-ref))
         (agent-id (cdr role-ref))
         (loop-session-ref
          (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "session"))
         (output-session-ref
          (agentic-ai-lab-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-session")))
         (channel-ref
          (agentic-ai-lab-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-channel")))
         (metadata
          (list (cons 'source 'loop-engine-session-agent-graph)
                (cons 'use-case use-case-name)
                (cons 'role role)
                (cons 'runtime-owner "marlin-agent-core")
                (cons 'runtime-executed #f))))
    (agentic-ai-lab-session-communication-channel-receipt
     'loop-engine/project
     channel-ref
     'parent-child
     loop-session-ref
     output-session-ref
     'loop-engine
     agent-id
     '(request receipt)
     '(declared-channel-only receipt-only)
     metadata)))

;; : (-> Alist [Pair] [PooSessionCommunicationChannelReceipt])
(def (agentic-ai-lab-loop-engine-session-agent-communication-channel-receipts
      intent
      role-refs)
  (map (lambda (role-ref)
         (agentic-ai-lab-loop-engine-session-agent-communication-channel-receipt
          intent
          role-ref))
       role-refs))

;;; Boundary: communication receipt folding keeps graph edges in reverse-build
;;; form until the caller finalizes deterministic receipt order.
;; : (-> Alist Pair [PooSessionCommunicationReceipt])
(def (agentic-ai-lab-loop-engine-session-agent-communication-receipts/rev
      intent
      role-ref
      receipt-values)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (role (car role-ref))
         (agent-id (cdr role-ref))
         (root-session-ref
          (agentic-ai-lab-loop-engine-first-parent-session-ref intent))
         (loop-session-ref
          (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "session"))
         (output-session-ref
          (agentic-ai-lab-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-session")))
         (channel-ref
          (agentic-ai-lab-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-channel")))
         (metadata
          (list (cons 'source 'loop-engine-session-agent-graph)
                (cons 'use-case use-case-name)
                (cons 'role role)
                (cons 'runtime-owner "marlin-agent-core")
                (cons 'runtime-executed #f))))
    (let ((request-receipt
           (agentic-ai-lab-session-communication-receipt
            'loop-engine/project
            'parent-child
            root-session-ref
            root-session-ref
            loop-session-ref
            output-session-ref
            'loop-engine
            agent-id
            channel-ref
            'request
            (list (cons 'operation 'delegate-agent-turn)
                  (cons 'role role))
            'declared-channel-only
            metadata))
          (result-receipt
           (agentic-ai-lab-session-communication-receipt
            'loop-engine/project
            'child-parent
            root-session-ref
            root-session-ref
            output-session-ref
            loop-session-ref
            agent-id
            'loop-engine
            channel-ref
            'receipt
            (list (cons 'operation 'agent-turn-result)
                  (cons 'role role))
            'receipt-only
            metadata)))
      (cons result-receipt
            (cons request-receipt receipt-values)))))

;; : (-> Alist Pair [PooSessionCommunicationReceipt])
(def (agentic-ai-lab-loop-engine-session-agent-communication-receipts intent
                                                               role-ref)
  (reverse
   (agentic-ai-lab-loop-engine-session-agent-communication-receipts/rev
    intent
    role-ref
    '())))

;; : (-> Alist [Pair] [PooSessionCommunicationReceipt])
(def (agentic-ai-lab-loop-engine-session-agent-communication-receipts* intent
                                                                 role-refs)
  (foldr
   (lambda (role-ref receipt-values)
     (foldr cons
            receipt-values
            (agentic-ai-lab-loop-engine-session-agent-communication-receipts
             intent
             role-ref)))
   '()
   role-refs))

;;; Boundary: user intent graph projection materializes parent, child, and peer
;;; session communication ids without starting runtime agents.
;; : (-> Alist Alist)
(def (agentic-ai-lab-loop-engine-root-registry-entry intent session agent-id)
  (agentic-ai-lab-session-registry-entry
   session
   agent-id
   '()
   '((isolation . ((default . root-owned)))
     (context . ((default . root-summary)))
     (sharing . ((default . explicit-grants-only)))
     (resource . ((accounting-owner . root-session))))
  '((source . loop-engine-session-agent-graph)
     (runtime-executed . #f))))

;; : (-> PooSessionAgentNode PooSessionValue Alist)
(def (agentic-ai-lab-loop-engine-session-agent-registry-entry node session)
  (let (node-row (agentic-ai-lab-session-agent-node->alist node))
    (agentic-ai-lab-session-registry-entry
     session
     (agentic-ai-lab-session-alist-ref
      node-row
      'agent-id
      'unknown-agent)
     (agentic-ai-lab-session-alist-ref
      node-row
      'communication-channels
      '())
     (list
      (cons 'context
            (agentic-ai-lab-session-alist-ref
             node-row
             'prompt-policy-ref
             #f))
      (cons 'sharing
            (agentic-ai-lab-session-alist-ref
             node-row
             'resource-sharing-policy-ref
             #f))
      (cons 'resource
            (agentic-ai-lab-session-alist-ref
             node-row
             'resource-sharing-policy-ref
             #f))
      (cons 'durable
            (list
             (cons 'policy-id
                   (agentic-ai-lab-session-alist-ref
                    node-row
                    'durable-policy-ref
                    #f))
             (cons 'source 'loop-engine-session-agent-graph))))
     (list (cons 'source 'loop-engine-session-agent-graph)
           (cons 'runtime-executed #f)))))

;; : (-> Alist [Symbol] [PooSessionValue])
(def (agentic-ai-lab-loop-engine-session-values intent session-refs)
  (map (lambda (session-ref)
         (agentic-ai-lab-loop-engine-session-value intent session-ref))
       session-refs))

;; : (-> Alist PooSessionValue PooSessionValue [PooSessionAgentNode] [PooSessionValue] [Alist])
(def (agentic-ai-lab-loop-engine-session-agent-registry-entries intent
                                                          root-session
                                                          loop-session
                                                          agent-nodes
                                                          agent-sessions)
  (append
   (list (agentic-ai-lab-loop-engine-root-registry-entry
          intent
          root-session
          'project-root)
         (agentic-ai-lab-loop-engine-root-registry-entry
          intent
          loop-session
          'loop-engine))
   (map agentic-ai-lab-loop-engine-session-agent-registry-entry
        agent-nodes
        agent-sessions)))

;;; Boundary: user intent graph projection materializes parent, child, and peer
;;; session communication ids without starting runtime agents.
;; : (-> Alist Alist)
(def (agentic-ai-lab-user-loop-engine-intent-session-agent-graph intent)
  (let* ((use-case-name
          (agentic-ai-lab-user-loop-engine-intent-use-case-name intent))
         (role-refs
          (agentic-ai-lab-loop-engine-intent-agent-profile-refs intent))
         (root-session-ref
          (agentic-ai-lab-loop-engine-first-parent-session-ref intent))
         (loop-session-ref
          (agentic-ai-lab-user-loop-engine-runtime-id use-case-name "session"))
         (output-session-refs
          (agentic-ai-lab-loop-engine-agent-output-session-refs intent))
         (agent-nodes
          (agentic-ai-lab-loop-engine-session-agent-nodes intent
                                                    role-refs
                                                    output-session-refs))
         (communication-receipts
          (agentic-ai-lab-loop-engine-session-agent-communication-receipts*
           intent
           role-refs))
         (communication-channel-receipts
          (agentic-ai-lab-loop-engine-session-agent-communication-channel-receipts
           intent
           role-refs))
         (root-session
          (agentic-ai-lab-loop-engine-session-value intent root-session-ref))
         (loop-session
          (agentic-ai-lab-loop-engine-session-value intent loop-session-ref))
         (agent-sessions
          (agentic-ai-lab-loop-engine-session-values intent output-session-refs))
         (sessions
          (cons root-session (cons loop-session agent-sessions)))
         (registry-entries
          (agentic-ai-lab-loop-engine-session-agent-registry-entries
           intent
           root-session
           loop-session
           agent-nodes
           agent-sessions))
         (registry-receipt
          (agentic-ai-lab-session-registry-receipt
           'loop-engine/project
           (list root-session-ref)
           (cons loop-session-ref output-session-refs)
           loop-session-ref
           registry-entries
           (list (cons 'source 'loop-engine-session-agent-graph)
                 (cons 'use-case use-case-name)
                 (cons 'runtime-owner "marlin-agent-core")
                 (cons 'runtime-executed #f)))))
    (agentic-ai-lab-session-agent-graph->alist
     (agentic-ai-lab-session-agent-graph
      'loop-engine/project
      root-session-ref
      agent-nodes
      sessions
      registry-receipt
      communication-receipts
      (list (cons 'source 'loop-engine-session-agent-graph)
            (cons 'use-case use-case-name)
            (cons 'communication-channel-receipts
                  communication-channel-receipts)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))
