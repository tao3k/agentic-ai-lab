;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Unified Acyclic + Cyclic GraphEngine Verification (`cyclic-subgraph.ss`):
;;; Proves that Loops are strictly governed cyclic SCC specializations inside
;;; the unified GraphEngine Condensation DAG:
;;;   1. Mixed Graph (`init-dag -> {propose <-> verify} SCC -> seal-release`) converges cleanly
;;;   2. Ungoverned cycles (missing `CycleTerminationContract.`) fail closed immediately
;;;   3. Oscillating cycles (`A -> B -> A`) halt immediately via state-digest detection
;;;   4. Budget-exhausted cycles halt cleanly at `max-iterations`
;;;   5. Revoked Cedar grant blocks graph execution with 0 nodes run

(import :std/test
        (only-in :std/list/list filter)
        (only-in :clan/poo/object .o .ref)
        (only-in :tao3k/agentic-ai-lab/modules/graph-engine/cyclic-subgraph
                 make-graph-node-spec
                 make-cycle-termination-contract
                 condense-graph-sccs
                 execute-unified-graph))

(export graph-engine-cyclic-subgraph-test)

(def (make-mixed-repair-graph)
  (list
   (make-graph-node-spec
    "init-dag"
    depends-on: '()
    execute-fn: (lambda (st) (cons (cons 'init #t) st)))
   (make-graph-node-spec
    "propose-fix"
    depends-on: '("init-dag" "verify-tests"))
   (make-graph-node-spec
    "verify-tests"
    depends-on: '("propose-fix"))
   (make-graph-node-spec
    "seal-release"
    depends-on: '("verify-tests")
    execute-fn: (lambda (st) (cons (cons 'released #t) st)))))

(def graph-engine-cyclic-subgraph-test
  (test-suite "GraphEngine Unified Acyclic DAG + Bounded Cyclic SCC Subgraphs"

    (test-case "Tarjan SCC condenses mixed acyclic/cyclic graph and converges governed repair loop before releasing downstream DAG"
      (let* ((nodes (make-mixed-repair-graph))
             (sccs (condense-graph-sccs nodes))
             (contract (make-cycle-termination-contract
                        '("propose-fix" "verify-tests")
                        max-iterations: 5
                        exit-predicate: (lambda (st)
                                          (let ((p (assoc 'errors st)))
                                            (and p (= (cdr p) 0))))
                        step-fn: (lambda (st _iter)
                                   (let* ((e (cdr (assoc 'errors st))))
                                     (cons (cons 'errors (max 0 (- e 1)))
                                           (filter (lambda (kv) (not (eq? (car kv) 'errors))) st))))))
             (res (execute-unified-graph nodes
                                         '((errors . 3))
                                         cycle-contracts: (list contract))))
        (check (length sccs) => 3)
        (check (.ref (car sccs) 'topology) => 'acyclic-dag-node)
        (check (.ref (cadr sccs) 'topology) => 'cyclic-feedback-scc)
        (check (.ref (caddr sccs) 'topology) => 'acyclic-dag-node)
        (check (.ref res 'admitted?) => #t)
        (check (.ref res 'status) => 'graph-converged)
        (check (.ref res 'acyclic-nodes-executed) => '("init-dag" "seal-release"))
        (check (length (.ref res 'cyclic-sccs-converged)) => 1)
        (check (.ref res 'total-cycle-iterations) => 3)
        (check (cdr (assoc 'released (.ref res 'final-state))) => #t)))

    (test-case "ungoverned cycle without CycleTerminationContract fails closed before downstream DAG"
      (let* ((nodes (make-mixed-repair-graph))
             (res (execute-unified-graph nodes '((errors . 2)) cycle-contracts: '())))
        (check (.ref res 'admitted?) => #f)
        (check (.ref res 'status) => 'halted-ungoverned-cycle)
        (check (.ref res 'reason) => 'ungoverned-cycle-forbidden)
        (check (.ref res 'acyclic-nodes-executed) => '("init-dag"))
        (check (assoc 'released (.ref res 'final-state)) => #f)))

    (test-case "oscillating cycle (A -> B -> A) halts immediately fail-closed via state-digest detection"
      (let* ((nodes (make-mixed-repair-graph))
             (osc-contract (make-cycle-termination-contract
                            '("propose-fix" "verify-tests")
                            max-iterations: 10
                            exit-predicate: (lambda (_st) #f)
                            step-fn: (lambda (st _iter)
                                       (let ((phase (cdr (assoc 'phase st))))
                                         (list (cons 'phase (if (eq? phase 'A) 'B 'A)))))))
             (res (execute-unified-graph nodes
                                         '((phase . A))
                                         cycle-contracts: (list osc-contract))))
        (check (.ref res 'admitted?) => #f)
        (check (.ref res 'status) => 'halted-cycle-oscillation)
        (check (.ref res 'reason) => 'cycle-oscillation-detected)
        ;; A -> B -> A detected immediately via state-digest repeat (long before max-iterations=10!)
        (check (<= (.ref res 'total-cycle-iterations) 3) => #t)))

    (test-case "monotonically drifting non-convergent cycle halts cleanly at max-iterations and revoked Cedar blocks all execution"
      (let* ((nodes (make-mixed-repair-graph))
             (budget-contract (make-cycle-termination-contract
                               '("propose-fix" "verify-tests")
                               max-iterations: 3
                               exit-predicate: (lambda (_st) #f)
                               step-fn: (lambda (st iter) (list (cons 'attempt (+ iter 1))))))
             (res-budget (execute-unified-graph nodes
                                                '((attempt . 0))
                                                cycle-contracts: (list budget-contract)))
             (res-cedar (execute-unified-graph nodes
                                               '((attempt . 0))
                                               cycle-contracts: (list budget-contract)
                                               cedar-grant-live?: #f)))
        (check (.ref res-budget 'admitted?) => #f)
        (check (.ref res-budget 'status) => 'halted-cycle-budget)
        (check (.ref res-budget 'reason) => 'cycle-budget-exhausted)
        (check (.ref res-budget 'total-cycle-iterations) => 3)
        (check (.ref res-cedar 'admitted?) => #f)
        (check (.ref res-cedar 'reason) => 'cedar-grant-revoked)
        (check (.ref res-cedar 'acyclic-nodes-executed) => '())))))
