;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine agent profile and harness projection rows.
;;; Invariant: projections describe Marlin-owned work and never open sessions.

(import (only-in :poo-flow/modules/workflow/control-plane/agent-harness
                 make-poo-flow-agent-harness
                 make-poo-flow-agent-profile
                 poo-flow-agent-harness->alist
                 poo-flow-agent-profile->alist)
        (rename-in "session-agent-graph.ss"
                   (poo-flow-user-loop-engine-intent-session-agent-graph
                    poo-flow-loop-engine-session-agent-graph/projection))
        "core.ss"
        "result-contract.ss"
        "runtime-base.ss")

(export poo-flow-user-loop-engine-intent-session-agent-graph-agent-nodes
        poo-flow-loop-engine-session-agent-node-ref
        poo-flow-user-loop-engine-intent-agent-profile
        poo-flow-user-loop-engine-intent-agent-profile/node
        poo-flow-user-loop-engine-intent-agent-profiles-from-nodes/rev
        poo-flow-user-loop-engine-intent-agent-profiles
        poo-flow-user-loop-engine-intent-agent-harness
        poo-flow-user-loop-engine-intent-agent-harness/node)

;; : (-> Alist [Alist])
(def (poo-flow-user-loop-engine-intent-session-agent-graph-agent-nodes
      intent)
  (poo-flow-user-loop-engine-intent-ref
   (poo-flow-loop-engine-session-agent-graph/projection intent)
   'agent-nodes
   '()))

;; : (-> Alist Symbol Datum Datum)
(def (poo-flow-loop-engine-session-agent-node-ref node key default)
  (poo-flow-user-loop-engine-intent-ref node key default))

;;; Agent profiles are shallow policy rows. They name the selected reviewer or
;;; governor role but leave model choice, tool execution, and sandbox startup to
;;; the runtime handoff.
;; : (-> Alist Pair Alist)
(def (poo-flow-user-loop-engine-intent-agent-profile intent role-ref)
  (let ((role (car role-ref))
        (profile-name (cdr role-ref)))
    (poo-flow-agent-profile->alist
     (make-poo-flow-agent-profile
      profile-name
      'runtime-selected
      (list 'loop-engine role)
      '()
      '(loop-engine)
      (poo-flow-user-loop-engine-intent-primary-sandbox-profile intent)
      (list (cons 'role role)
            (cons 'governor
                  (poo-flow-user-loop-engine-intent-ref intent 'governor '()))
            (cons 'result-contract
                  (poo-flow-user-loop-engine-intent-role-result-contract
                   intent
                   role))
            (cons 'human-audit
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'human-audit
                   '())))
      '()
      (poo-flow-user-loop-engine-intent-ref intent 'budget '())
      (poo-flow-user-loop-engine-intent-ref intent 'observability '())
      (list (cons 'source 'user-config-loop-engine)
            (cons 'profile-role role)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))

;;; The runtime-facing profile view is derived from the shared session-agent
;;; graph node so loop-engine no longer maintains a parallel profile topology.
;; : (-> Alist Alist Alist)
(def (poo-flow-user-loop-engine-intent-agent-profile/node intent node)
  (let ((role (poo-flow-loop-engine-session-agent-node-ref node 'role #f))
        (profile-name
         (poo-flow-loop-engine-session-agent-node-ref
          node
          'agent-id
          'unknown-agent))
        (sandbox-profile-ref
         (poo-flow-loop-engine-session-agent-node-ref
          node
          'sandbox-profile-ref
          (poo-flow-user-loop-engine-intent-primary-sandbox-profile
           intent)))
        (result-contract
         (poo-flow-loop-engine-session-agent-node-ref
          node
          'result-contract
          'poo-flow.loop-governor.node-result.v1)))
    (poo-flow-agent-profile->alist
     (make-poo-flow-agent-profile
      profile-name
      'runtime-selected
      (list 'loop-engine role)
      '()
      '(loop-engine)
      sandbox-profile-ref
      (list (cons 'role role)
            (cons 'governor
                  (poo-flow-user-loop-engine-intent-ref intent 'governor '()))
            (cons 'result-contract result-contract)
            (cons 'human-audit
                  (poo-flow-user-loop-engine-intent-ref
                   intent
                   'human-audit
                   '()))
            (cons 'topology-source 'session-agent-graph))
      '()
      (poo-flow-user-loop-engine-intent-ref intent 'budget '())
      (poo-flow-user-loop-engine-intent-ref intent 'observability '())
      (list (cons 'source 'user-config-loop-engine)
            (cons 'profile-role role)
            (cons 'topology-source 'session-agent-graph)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))

;;; Profile projection preserves user declaration order so presentation output
;;; and runtime manifests can be compared without sorting.
;; : (forall (a) (-> Alist [a] [Alist] [Alist]))
;; : (-> Alist [Alist] [Alist] [Alist])
(def (poo-flow-user-loop-engine-intent-agent-profiles-from-nodes/rev
      intent
      agent-nodes
      profiles-rev)
  (foldl (lambda (node profiles)
           (cons (poo-flow-user-loop-engine-intent-agent-profile/node
                  intent
                  node)
                 profiles))
         profiles-rev
         agent-nodes))

;; : (-> Alist [Alist])
(def (poo-flow-user-loop-engine-intent-agent-profiles intent)
  (reverse
   (poo-flow-user-loop-engine-intent-agent-profiles-from-nodes/rev
    intent
    (poo-flow-user-loop-engine-intent-session-agent-graph-agent-nodes
     intent)
    '())))

;;; Harness rows describe an initialized-agent boundary without constructing
;;; it. They carry runtime intent and sandbox policy references as receipt data.
;; : (-> Alist Pair Alist)
(def (poo-flow-user-loop-engine-intent-agent-harness intent role-ref)
  (let* ((use-case-name
          (poo-flow-user-loop-engine-intent-use-case-name intent))
         (role (car role-ref))
         (profile-name (cdr role-ref))
         (harness-id
          (poo-flow-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-harness"))))
    (poo-flow-agent-harness->alist
     (make-poo-flow-agent-harness
      harness-id
      profile-name
      (poo-flow-user-loop-engine-intent-primary-sandbox-profile intent)
      (poo-flow-user-loop-engine-intent-runtime-intent intent)
      '(execute-agent-operation stream-events read-runtime-snapshot)
      (list 'loop-engine use-case-name role)
      (poo-flow-user-loop-engine-intent-ref intent 'observability '())
      #f
      (list (cons 'source 'user-config-loop-engine)
            (cons 'profile-role role)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))

;;; Harness rows are also graph-derived. The node role still determines the
;;; stable harness id, while the profile ref comes from the graph agent id.
;; : (-> Alist Alist Alist)
(def (poo-flow-user-loop-engine-intent-agent-harness/node intent node)
  (let* ((use-case-name
          (poo-flow-user-loop-engine-intent-use-case-name intent))
         (role
          (poo-flow-loop-engine-session-agent-node-ref node 'role #f))
         (profile-name
          (poo-flow-loop-engine-session-agent-node-ref
           node
           'agent-id
           'unknown-agent))
         (harness-id
          (poo-flow-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-harness")))
         (sandbox-profile-ref
          (poo-flow-loop-engine-session-agent-node-ref
           node
           'sandbox-profile-ref
           (poo-flow-user-loop-engine-intent-primary-sandbox-profile
            intent))))
    (poo-flow-agent-harness->alist
     (make-poo-flow-agent-harness
      harness-id
      profile-name
      sandbox-profile-ref
      (poo-flow-user-loop-engine-intent-runtime-intent intent)
      '(execute-agent-operation stream-events read-runtime-snapshot)
      (list 'loop-engine use-case-name role)
      (poo-flow-user-loop-engine-intent-ref intent 'observability '())
      #f
      (list (cons 'source 'user-config-loop-engine)
            (cons 'profile-role role)
            (cons 'topology-source 'session-agent-graph)
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))
