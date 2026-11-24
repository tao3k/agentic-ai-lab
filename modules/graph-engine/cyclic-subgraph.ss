;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Unified Acyclic + Cyclic GraphEngine Topology (`modules/graph-engine/cyclic-subgraph.ss`):
;;; Treats EVERY workflow — acyclic FunFlow DAG, Convergent Tree, OR bounded
;;; cyclic feedback/repair Loop — as a single directed graph partitioned by
;;; Tarjan Strongly Connected Components (SCC) into a Condensation DAG:
;;;
;;; - Trivial SCC (size 1, no self-loop) -> `'acyclic-dag-node`:
;;;   executed deterministically once (0 loop iterations, 0 subagents).
;;; - Non-trivial SCC (size > 1 or self-loop) -> `'cyclic-feedback-scc`:
;;;   1. MUST carry an explicit POO `CycleTerminationContract.` (ungoverned cycles
;;;      are REFUSED fail-closed with `'ungoverned-cycle-forbidden`!).
;;;   2. Enforces exact state-digest repeat & oscillation detection (`visited-digests`
;;;      -> halts immediately fail-closed with `'cycle-oscillation-detected`!).
;;;   3. Enforces hard iteration budget (`max-iterations` -> `'cycle-budget-exhausted`).
;;;   4. Enforces live Cedar grant (`cedar-grant-live?` -> `'cedar-grant-revoked`).
;;;   5. Once its `exit-predicate` discharges, collapses into a single verified
;;;      condensation receipt and releases downstream DAG nodes!

(import (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :std/list/list filter every any)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/funs-scope
                 agentic-ai-lab-ai-agentic-context-digest))

(export GraphNodeSpec.
        CycleTerminationContract.
        CondensedScc.
        UnifiedGraphExecutionReceipt.
        make-graph-node-spec
        make-cycle-termination-contract
        condense-graph-sccs
        execute-unified-graph)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(.def GraphNodeSpec.
  kind: 'agentic-ai-lab.graph-engine.graph-node-spec.v1)

(.def CycleTerminationContract.
  kind: 'agentic-ai-lab.graph-engine.cycle-termination-contract.v1)

(.def CondensedScc.
  kind: 'agentic-ai-lab.graph-engine.condensed-scc.v1)

(.def UnifiedGraphExecutionReceipt.
  kind: 'agentic-ai-lab.graph-engine.unified-graph-execution.v1)

(def (make-graph-node-spec
      node-id
      depends-on: (depends-on '())
      execute-fn: (execute-fn #f))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.graph-engine.graph-node-spec.v1
      node-id: node-id
      depends-on: depends-on
      execute-fn: execute-fn))

(def (make-cycle-termination-contract
      scc-member-ids
      max-iterations: (max-iterations 4)
      exit-predicate: (exit-predicate (lambda (_st) #t))
      step-fn: (step-fn (lambda (st _iter) st))
      state-digest-fn: (state-digest-fn (lambda (st) (digest (list 'scc-state.v1 st)))))
  (.o bind-these: #f
      kind: 'agentic-ai-lab.graph-engine.cycle-termination-contract.v1
      scc-member-ids: scc-member-ids
      max-iterations: (max 1 max-iterations)
      exit-predicate: exit-predicate
      step-fn: step-fn
      state-digest-fn: state-digest-fn))

;;; Pure Tarjan SCC condensation over arbitrary directed graph nodes (`depends-on`
;;; edges: `node` depends on each `dep` in `depends-on`, so DFS walks `dep` first
;;; and Tarjan naturally emits SCCs in dependency-first Condensation DAG order!).
(def (condense-graph-sccs nodes)
  (let ((node-map (make-hash-table))
        (dep-map (make-hash-table))
        (ids (map (lambda (n) (.ref n 'node-id)) nodes))
        (index-counter 0)
        (indices (make-hash-table))
        (lowlinks (make-hash-table))
        (on-stack (make-hash-table))
        (stack '())
        (sccs-rev '()))
    (for-each
     (lambda (n)
       (let ((id (.ref n 'node-id)))
         (hash-put! node-map id n)
         (hash-put! dep-map id (.ref n 'depends-on))))
     nodes)
    (def (strongconnect v)
      (hash-put! indices v index-counter)
      (hash-put! lowlinks v index-counter)
      (set! index-counter (+ index-counter 1))
      (set! stack (cons v stack))
      (hash-put! on-stack v #t)
      (for-each
       (lambda (w)
         (when (hash-key? node-map w)
           (cond
            ((not (hash-key? indices w))
             (strongconnect w)
             (hash-put! lowlinks v (min (hash-ref lowlinks v) (hash-ref lowlinks w))))
            ((hash-get on-stack w)
             (hash-put! lowlinks v (min (hash-ref lowlinks v) (hash-ref indices w)))))))
       (hash-ref dep-map v '()))
      (when (= (hash-ref lowlinks v) (hash-ref indices v))
        (let pop-loop ((comp '()))
          (let ((w (car stack)))
            (set! stack (cdr stack))
            (hash-put! on-stack w #f)
            (let ((next-comp (cons w comp)))
              (if (equal? w v)
                (let* ((self-loop? (and (= (length next-comp) 1)
                                        (and (member v (hash-ref dep-map v '())) #t)))
                       (cyclic? (or (> (length next-comp) 1) self-loop?))
                       (scc-obj (.o bind-these: #f
                                    kind: 'agentic-ai-lab.graph-engine.condensed-scc.v1
                                    scc-id: (string-append "scc:" (car next-comp))
                                    members: next-comp
                                    topology: (if cyclic? 'cyclic-feedback-scc 'acyclic-dag-node)
                                    cyclic?: cyclic?)))
                  (set! sccs-rev (cons scc-obj sccs-rev)))
                (pop-loop next-comp)))))))
    (for-each
     (lambda (v)
       (unless (hash-key? indices v)
         (strongconnect v)))
     ids)
    ;; Because edges point `node -> dep`, Tarjan emits dependencies BEFORE dependents,
    ;; so `(reverse sccs-rev)` is already a valid topological Condensation DAG order!
    (reverse sccs-rev)))

(def (find-contract-for-scc scc contracts)
  (let ((members (.ref scc 'members)))
    (let loop ((cs contracts))
      (cond
       ((null? cs) #f)
       ((let ((cm (.ref (car cs) 'scc-member-ids)))
          (and (= (length cm) (length members))
               (every (lambda (m) (and (member m cm) #t)) members)))
        (car cs))
       (else (loop (cdr cs)))))))

;;; Execute ANY unified graph (acyclic DAG, tree, OR cyclic feedback subgraphs)
;;; over its Tarjan SCC Condensation DAG with strict fail-closed termination guards.
(def (execute-unified-graph
      nodes
      initial-state
      cycle-contracts: (cycle-contracts '())
      cedar-grant-live?: (cedar-grant-live? #t))
  (let ((sccs (condense-graph-sccs nodes))
        (node-map (make-hash-table)))
    (for-each (lambda (n) (hash-put! node-map (.ref n 'node-id) n)) nodes)
    (if (not cedar-grant-live?)
      (.o bind-these: #f
          kind: 'agentic-ai-lab.graph-engine.unified-graph-execution.v1
          admitted?: #f
          status: 'blocked-on-governance
          reason: 'cedar-grant-revoked
          condensation-sccs: sccs
          acyclic-nodes-executed: '()
          cyclic-sccs-converged: '()
          total-cycle-iterations: 0
          final-state: initial-state
          halted-scc-id: #f
          action-authorized?: #f)
      (let loop-sccs ((rest sccs)
                      (cur-state initial-state)
                      (acyclic-rev '())
                      (cyclic-rev '())
                      (cycle-iters 0))
        (if (null? rest)
          (.o bind-these: #f
              kind: 'agentic-ai-lab.graph-engine.unified-graph-execution.v1
              admitted?: #t
              status: 'graph-converged
              reason: 'unified-graph-condensation-completed
              condensation-sccs: sccs
              acyclic-nodes-executed: (reverse acyclic-rev)
              cyclic-sccs-converged: (reverse cyclic-rev)
              total-cycle-iterations: cycle-iters
              final-state: cur-state
              halted-scc-id: #f
              action-authorized?: #f)
          (let* ((scc (car rest))
                 (scc-id (.ref scc 'scc-id)))
            (if (not (.ref scc 'cyclic?))
              ;; Trivial SCC: execute deterministically once as an acyclic DAG node
              (let* ((nid (car (.ref scc 'members)))
                     (node (hash-ref node-map nid))
                     (fn (.ref node 'execute-fn))
                     (next-st (if (procedure? fn) (fn cur-state) cur-state)))
                (loop-sccs (cdr rest)
                           next-st
                           (cons nid acyclic-rev)
                           cyclic-rev
                           cycle-iters))
              ;; Non-trivial SCC: Bounded Cyclic Feedback Subgraph!
              (let ((contract (find-contract-for-scc scc cycle-contracts)))
                (if (not contract)
                  (.o bind-these: #f
                      kind: 'agentic-ai-lab.graph-engine.unified-graph-execution.v1
                      admitted?: #f
                      status: 'halted-ungoverned-cycle
                      reason: 'ungoverned-cycle-forbidden
                      condensation-sccs: sccs
                      acyclic-nodes-executed: (reverse acyclic-rev)
                      cyclic-sccs-converged: (reverse cyclic-rev)
                      total-cycle-iterations: cycle-iters
                      final-state: cur-state
                      halted-scc-id: scc-id
                      action-authorized?: #f)
                  (let ((max-it (.ref contract 'max-iterations))
                        (exit? (.ref contract 'exit-predicate))
                        (step-fn (.ref contract 'step-fn))
                        (dig-fn (.ref contract 'state-digest-fn)))
                    (let loop-cycle ((iter 0) (st cur-state) (visited '()))
                      (let ((sd (dig-fn st)))
                        (cond
                         ((member sd visited)
                          (.o bind-these: #f
                              kind: 'agentic-ai-lab.graph-engine.unified-graph-execution.v1
                              admitted?: #f
                              status: 'halted-cycle-oscillation
                              reason: 'cycle-oscillation-detected
                              condensation-sccs: sccs
                              acyclic-nodes-executed: (reverse acyclic-rev)
                              cyclic-sccs-converged: (reverse cyclic-rev)
                              total-cycle-iterations: (+ cycle-iters iter)
                              final-state: st
                              halted-scc-id: scc-id
                              action-authorized?: #f))
                         ((exit? st)
                          ;; Converged SCC collapses into a single condensation receipt!
                          (loop-sccs (cdr rest)
                                     st
                                     acyclic-rev
                                     (cons scc-id cyclic-rev)
                                     (+ cycle-iters iter)))
                         ((>= iter max-it)
                          (.o bind-these: #f
                              kind: 'agentic-ai-lab.graph-engine.unified-graph-execution.v1
                              admitted?: #f
                              status: 'halted-cycle-budget
                              reason: 'cycle-budget-exhausted
                              condensation-sccs: sccs
                              acyclic-nodes-executed: (reverse acyclic-rev)
                              cyclic-sccs-converged: (reverse cyclic-rev)
                              total-cycle-iterations: (+ cycle-iters iter)
                              final-state: st
                              halted-scc-id: scc-id
                              action-authorized?: #f))
                         (else
                          (loop-cycle (+ iter 1)
                                      (step-fn st iter)
                                      (cons sd visited))))))))))))))))
