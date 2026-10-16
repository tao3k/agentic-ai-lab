;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine agent session and harness collection projection rows.
;;; Invariant: projections describe Marlin-owned work and never open sessions.

(import (only-in :poo-flow/modules/workflow/control-plane/agent-harness
                 make-poo-flow-agent-session
                 poo-flow-agent-session->alist)
        (rename-in "session-agent-graph.ss"
                   (poo-flow-user-loop-engine-intent-session-agent-graph
                    poo-flow-loop-engine-session-agent-graph/projection))
        "core.ss"
        "result-contract.ss"
        "runtime-agent-profile-harness.ss"
        "runtime-base.ss")

(export poo-flow-user-loop-engine-intent-agent-harnesses
        poo-flow-user-loop-engine-intent-agent-session
        poo-flow-user-loop-engine-intent-agent-session/node
        poo-flow-user-loop-engine-intent-agent-sessions
        poo-flow-user-loop-engine-intent-session-agent-graph)

;;; Harness projection is one row per named profile so multi-agent governor
;;; configurations remain explicit in the handoff packet.
;; : (forall (a) (-> Alist [a]))
;; : (-> Alist [Alist])
(def (poo-flow-user-loop-engine-intent-agent-harnesses intent)
  (map (lambda (node)
         (poo-flow-user-loop-engine-intent-agent-harness/node intent node))
       (poo-flow-user-loop-engine-intent-session-agent-graph-agent-nodes
        intent)))

;;; Session rows keep delegated work separate from workflow runs. The active
;;; operation ref points at the control-plane operation, not an executed turn.
;; : (-> Alist Pair Alist)
(def (poo-flow-user-loop-engine-intent-agent-session intent role-ref)
  (let* ((use-case-name
          (poo-flow-user-loop-engine-intent-use-case-name intent))
         (role (car role-ref))
         (session-name
          (poo-flow-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-session")))
         (harness-id
          (poo-flow-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-harness")))
         (operation-id
          (poo-flow-user-loop-engine-runtime-id use-case-name "operation")))
    (poo-flow-agent-session->alist
     (make-poo-flow-agent-session
      session-name
      harness-id
      (poo-flow-user-loop-engine-intent-status intent)
      operation-id
      (list 'loop-engine-conversation use-case-name role)
      '((retention . parent-owned))
      (list operation-id)
      (list (cons 'source 'user-config-loop-engine)
            (cons 'profile-role role)
            (cons 'workflow-run-ref
                  (poo-flow-user-loop-engine-runtime-id
                   use-case-name
                   "workflow-run"))
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))

;;; Agent sessions now derive their session name from the graph node's
;;; `output-session-ref`, making the session-agent graph the address owner.
;; : (-> Alist Alist Alist)
(def (poo-flow-user-loop-engine-intent-agent-session/node intent node)
  (let* ((use-case-name
          (poo-flow-user-loop-engine-intent-use-case-name intent))
         (role
          (poo-flow-loop-engine-session-agent-node-ref node 'role #f))
         (session-name
          (poo-flow-loop-engine-session-agent-node-ref
           node
           'output-session-ref
           (poo-flow-user-loop-engine-runtime-id
            use-case-name
            (string-append (symbol->string role) "-session"))))
         (harness-id
          (poo-flow-user-loop-engine-runtime-id
           use-case-name
           (string-append (symbol->string role) "-harness")))
         (operation-id
          (poo-flow-user-loop-engine-runtime-id use-case-name "operation")))
    (poo-flow-agent-session->alist
     (make-poo-flow-agent-session
      session-name
      harness-id
      (poo-flow-user-loop-engine-intent-status intent)
      operation-id
      (list 'loop-engine-conversation use-case-name role)
      '((retention . parent-owned))
      (list operation-id)
      (list (cons 'source 'user-config-loop-engine)
            (cons 'profile-role role)
            (cons 'topology-source 'session-agent-graph)
            (cons 'workflow-run-ref
                  (poo-flow-user-loop-engine-runtime-id
                   use-case-name
                   "workflow-run"))
            (cons 'runtime-owner "marlin-agent-core")
            (cons 'runtime-executed #f))))))

;;; Session projection gives every named profile a stable namespace that agents
;;; can audit before a backend opens durable conversation state.
;; : (forall (a) (-> Alist [a]))
;; : (-> Alist [Alist])
(def (poo-flow-user-loop-engine-intent-agent-sessions intent)
  (map (lambda (node)
         (poo-flow-user-loop-engine-intent-agent-session/node intent node))
       (poo-flow-user-loop-engine-intent-session-agent-graph-agent-nodes
        intent)))

;; : (-> Alist Alist)
(def (poo-flow-user-loop-engine-intent-session-agent-graph intent)
  (poo-flow-loop-engine-session-agent-graph/projection intent))
