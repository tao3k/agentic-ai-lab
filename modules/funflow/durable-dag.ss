;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Tweag-inspired FunFlow CAS DAG engine with C4-derivable OrchestratorStrategy
;;; prototypes, Tarjan SCC cycle validation, transitive CAS node fingerprinting,
;;; crash-resumable skip planning, epoch-bounded dynamic replanning, and
;;; pluggable Governance/lease frontier admission.

(import (only-in :clan/poo/object .def .o .ref .slot? .call object?)
        (only-in :clan/poo/mop .defgeneric)
        (prefix-in :clan/poo/graph/scc scc.)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every filter find delete-duplicates/hash))

(export OrchestratorStrategy.
        ParallelFrontierStrategy.
        TieredModelStrategy.
        DurableGovernedStrategy.
        strategy-admit-node
        strategy-admit-frontier
        strategy-cas-fingerprint
        strategy-archive-guard
        funflow-dag-node
        funflow-dag-build
        funflow-dag?
        funflow-cas-fingerprint
        funflow-admit-frontier-with
        funflow-resume-plan
        funflow-replan-epoch
        FunflowDurableDagExports)

(.defgeneric (strategy-admit-node strategy node context)
  slot: .admit-node)

(.defgeneric (strategy-admit-frontier strategy frontier context)
  slot: .admit-frontier)

(.defgeneric (strategy-cas-fingerprint strategy node dep-fingerprints)
  slot: .cas-fingerprint)

(.defgeneric (strategy-archive-guard strategy dag resume-plan journal-state)
  slot: .archive-guard)

(def (canonical-sha256 payload)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string (lambda (port) (write payload port))))))))

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (node-id-symbol value)
  (cond
   ((symbol? value) value)
   ((string? value) (string->symbol value))
   (else (error "FunFlow DAG node id must be a symbol or string" value))))

(def (funflow-dag-node id
                       needs: (needs '())
                       after-start: (after-start #f)
                       source-cut: (source-cut "cut-0")
                       input-digest: (input-digest "")
                       contract-digest: (contract-digest "")
                       policy-digest: (policy-digest "")
                       status: (status 'todo)
                       checklists-done?: (checklists-done? #t)
                       span: (span #f)
                       scope: (scope #f)
                       model-tier: (model-tier 'builder)
                       disclosure-depth: (disclosure-depth 2)
                       facets: (facets '())
                       metadata: (metadata '()))
  (let ((id-sym (node-id-symbol id))
        (needs-syms (map node-id-symbol needs))
        (after-sym (and after-start (node-id-symbol after-start)))
        (cut-val (if (string? source-cut) (string-copy source-cut) (object->string source-cut)))
        (in-dig (if (string? input-digest) (string-copy input-digest) ""))
        (con-dig (if (string? contract-digest) (string-copy contract-digest) ""))
        (pol-dig (if (string? policy-digest) (string-copy policy-digest) ""))
        (st-val status)
        (chk-val (and checklists-done? #t))
        (span-val span)
        (scope-val scope)
        (tier-val model-tier)
        (depth-val disclosure-depth)
        (facets-val facets)
        (meta-val metadata))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.funflow.dag-node.v1
        id: id-sym
        needs: needs-syms
        after-start: after-sym
        source-cut: cut-val
        input-digest: in-dig
        contract-digest: con-dig
        policy-digest: pol-dig
        status: st-val
        checklists-done?: chk-val
        span: span-val
        scope: scope-val
        model-tier: tier-val
        disclosure-depth: depth-val
        facets: facets-val
        metadata: meta-val)))

(def (funflow-cas-fingerprint node dep-fingerprints)
  (let ((sorted-deps
         (list-sort (lambda (a b) (string<? (car a) (car b)))
                    (map (lambda (pair)
                           (cons (symbol->string (car pair)) (cdr pair)))
                         dep-fingerprints))))
    (canonical-sha256
     (list 'agentic-ai-lab.funflow.cas-node.v1
           (symbol->string (.ref node 'id))
           (.ref node 'source-cut)
           (.ref node 'input-digest)
           (.ref node 'contract-digest)
           (.ref node 'policy-digest)
           (if (.ref node 'after-start)
             (symbol->string (.ref node 'after-start))
             #f)
           sorted-deps))))

(def (spans-disjoint? a b)
  (let ((sa (opt-ref a 'span #f))
        (sb (opt-ref b 'span #f)))
    (cond
     ((or (not sa) (not sb)) #t)
     ((and (pair? sa) (pair? sb)
           (exact-integer? (car sa)) (exact-integer? (cdr sa))
           (exact-integer? (car sb)) (exact-integer? (cdr sb)))
      (or (<= (cdr sa) (car sb)) (<= (cdr sb) (car sa))))
     (else #t))))

(def (funflow-admit-frontier-with frontier node-admit? pair-compatible? max-concurrency)
  (let ((admitted-candidates
         (filter (lambda (node) (and (node-admit? node) #t)) frontier)))
    (let loop ((rest admitted-candidates) (selected '()) (deferred '()))
      (cond
       ((null? rest)
        (let ((sel (reverse selected))
              (def-list (reverse deferred)))
          (.o kind: 'agentic-ai-lab.funflow.frontier-admission.v1
              selected: sel
              deferred: def-list)))
       ((and max-concurrency (>= (length selected) max-concurrency))
        (loop (cdr rest) selected (cons (car rest) deferred)))
       (else
        (let ((candidate (car rest)))
          (if (every (lambda (chosen) (pair-compatible? chosen candidate)) selected)
            (loop (cdr rest) (cons candidate selected) deferred)
            (loop (cdr rest) selected (cons candidate deferred)))))))))

;;; C4-derivable POO OrchestratorStrategy hierarchy.
(def OrchestratorStrategy.
  (.o (:: self)
      kind: 'agentic-ai-lab.funflow.orchestrator-strategy.v1
      name: 'base-orchestrator
      max-concurrency: 1
      cache-policy: 'cas-journal
      failure-policy: 'fail-closed
      focused-tab-archive: 'on-blur
      scratch-promotion: 'on-plan
      reopen-mode: 'peek-until-edit
      require-sod-reviewer: #f
      .cas-fingerprint: (lambda (node dep-fingerprints)
                          (funflow-cas-fingerprint node dep-fingerprints))
      .admit-node: (lambda (node context)
                     (let ((pred (opt-ref context 'node-admit? #f)))
                       (if (procedure? pred)
                         (and (pred node) #t)
                         #t)))
      .admit-frontier: (lambda (frontier context)
                         (let ((max-c (.ref self 'max-concurrency))
                               (pair-ok? (or (opt-ref context 'pair-compatible? #f)
                                             spans-disjoint?)))
                           (funflow-admit-frontier-with
                            frontier
                            (lambda (node) (strategy-admit-node self node context))
                            pair-ok?
                            max-c)))
      .archive-guard: (lambda (dag resume-plan journal-state)
                        (let ((in-flight (opt-ref journal-state 'in-flight-ids '()))
                              (pending-effects (opt-ref journal-state 'pending-effects '())))
                          (and (.ref dag 'valid?)
                               (.ref resume-plan 'complete?)
                               (null? (.ref resume-plan 'pending-finalizers))
                               (null? in-flight)
                               (null? pending-effects))))))

(def ParallelFrontierStrategy.
  (.o (:: @ OrchestratorStrategy.)
      name: 'parallel-frontier
      max-concurrency: 4))

(def TieredModelStrategy.
  (.o (:: self ParallelFrontierStrategy.)
      name: 'tiered-model
      model-tiers: (.o architect: 'frontier builder: 'mid flash: 'fast)
      .route-node: (lambda (node)
                     (let ((facets (opt-ref node 'facets '()))
                           (explicit (opt-ref node 'model-tier #f)))
                       (cond
                        ((or (memq 'invariant-section facets)
                             (memq 'competing-hypotheses facets))
                         'architect)
                        ((and (null? facets) (eq? explicit 'flash))
                         'flash)
                        (explicit explicit)
                        (else 'builder))))))

(def DurableGovernedStrategy.
  (.o (:: self TieredModelStrategy.)
      name: 'durable-governed
      (.admit-node =>
        (lambda (base-admit)
          (lambda (node context)
            (let ((base-ok? (base-admit node context))
                  (gov-ok? (opt-ref context 'governance-admit? #f))
                  (need-sod? (.ref self 'require-sod-reviewer)))
              (and base-ok?
                   (if (procedure? gov-ok?) (and (gov-ok? node) #t) #t)
                   (if need-sod?
                     (let ((scope (opt-ref node 'scope #f)))
                       (and (object? scope)
                            (opt-ref scope 'reviewer-id #f)
                            (not (equal? (opt-ref scope 'actor #f)
                                         (opt-ref scope 'reviewer-id #f)))))
                     #t))))))
      (.archive-guard =>
        (lambda (base-guard)
          (lambda (dag resume-plan journal-state)
            (and (base-guard dag resume-plan journal-state)
                 (not (opt-ref journal-state 'recovery-required? #f))))))))

(def (funflow-dag? value)
  (and (object? value)
       (.slot? value 'kind)
       (eq? (.ref value 'kind) 'agentic-ai-lab.funflow.dag.v1)))

(def (topological-order names dep-map)
  (let ((indeg (make-hash-table-eq))
        (dependents (make-hash-table-eq)))
    (for-each (lambda (n) (hash-put! indeg n 0)) names)
    (for-each
     (lambda (n)
       (for-each
        (lambda (dep)
          (when (hash-key? indeg dep)
            (hash-put! indeg n (+ 1 (hash-ref indeg n 0)))
            (hash-put! dependents dep (cons n (hash-ref dependents dep '())))))
        (hash-ref dep-map n '())))
     names)
    (let loop ((ready (filter (lambda (n) (= (hash-ref indeg n 0) 0)) names))
               (acc '()))
      (if (null? ready)
        (reverse acc)
        (let* ((curr (car ready))
               (rest (cdr ready))
               (unlocked
                (filter
                 (lambda (child)
                   (let ((next (- (hash-ref indeg child 0) 1)))
                     (hash-put! indeg child next)
                     (= next 0)))
                 (reverse (hash-ref dependents curr '())))))
          (loop (append rest unlocked) (cons curr acc)))))))

(def (funflow-dag-build nodes strategy: (strategy DurableGovernedStrategy.))
  (let* ((node-list (if (list? nodes) nodes (error "funflow-dag-build expects node list" nodes)))
         (id-list (map (lambda (n) (.ref n 'id)) node-list))
         (unique-ids (delete-duplicates/hash id-list))
         (duplicate-ids
          (if (= (length id-list) (length unique-ids))
            '()
            (let ((seen (make-hash-table-eq)) (dups '()))
              (for-each (lambda (id)
                          (if (hash-key? seen id)
                            (set! dups (cons id dups))
                            (hash-put! seen id #t)))
                        id-list)
              (delete-duplicates/hash (reverse dups)))))
         (node-map (make-hash-table-eq))
         (dep-map (make-hash-table-eq)))
    (for-each (lambda (n)
                (let ((id (.ref n 'id)))
                  (unless (hash-key? node-map id)
                    (hash-put! node-map id n)
                    (hash-put! dep-map id (.ref n 'needs)))))
              node-list)
    (let* ((unresolved-edges
            (let ((missing '()))
              (for-each
               (lambda (n)
                 (let ((id (.ref n 'id)))
                   (for-each
                    (lambda (dep)
                      (unless (hash-key? node-map dep)
                        (set! missing (cons (cons id dep) missing))))
                    (.ref n 'needs))
                   (let ((trig (.ref n 'after-start)))
                     (when (and trig (not (hash-key? node-map trig)))
                       (set! missing (cons (cons id trig) missing))))))
               node-list)
              (reverse missing)))
           (invalid-finalizers
            (filter
             (lambda (n)
               (and (.ref n 'after-start) (pair? (.ref n 'needs))))
             node-list))
           (partition
            (scc.partition
             (.o keys: unique-ids
                 .code: (lambda (name)
                          (let ((deps (filter (lambda (d) (hash-key? node-map d))
                                              (hash-ref dep-map name '()))))
                            (and (pair? deps) (.o reads: deps)))))))
           (reads (scc.partition-reads partition))
           (cycle-nodes
            (filter
             (lambda (name)
               (or (> (scc.partition-group-size partition name) 1)
                   (memq name (reads name))))
             unique-ids))
           (valid? (and (null? duplicate-ids)
                        (null? unresolved-edges)
                        (null? invalid-finalizers)
                        (null? cycle-nodes)))
           (topo (if valid? (topological-order unique-ids dep-map) '()))
           (fingerprints (make-hash-table-eq)))
      (when valid?
        (for-each
         (lambda (id)
           (let* ((node (hash-ref node-map id))
                  (dep-fps
                   (map (lambda (dep) (cons dep (hash-ref fingerprints dep "")))
                        (.ref node 'needs)))
                  (fp (strategy-cas-fingerprint strategy node dep-fps)))
             (hash-put! fingerprints id fp)))
         topo))
      (let* ((fp-alist
              (map (lambda (id) (cons id (hash-ref fingerprints id ""))) topo))
             (dag-digest (canonical-sha256 (list 'agentic-ai-lab.funflow.dag.v1 fp-alist)))
             (nodes-val node-list)
             (ids-val unique-ids)
             (topo-val topo)
             (valid-val valid?)
             (dups-val duplicate-ids)
             (unres-val unresolved-edges)
             (inv-fin-val (map (lambda (n) (.ref n 'id)) invalid-finalizers))
             (cyc-val cycle-nodes))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.funflow.dag.v1
            valid?: valid-val
            nodes: nodes-val
            node-ids: ids-val
            node-map: node-map
            topological-order: topo-val
            fingerprints: fp-alist
            fingerprint-table: fingerprints
            dag-digest: dag-digest
            duplicate-nodes: dups-val
            unresolved-edges: unres-val
            invalid-finalizers: inv-fin-val
            cycle-nodes: cyc-val)))))

(def (cas-hit? node fp completed-cas-table)
  (and completed-cas-table
       (let ((id (.ref node 'id)))
         (cond
          ((hash-table? completed-cas-table)
           (or (equal? (hash-get completed-cas-table id) fp)
               (and (hash-get completed-cas-table fp) #t)))
          ((list? completed-cas-table)
           (let ((entry (assq id completed-cas-table)))
             (and entry (equal? (cdr entry) fp))))
          (else #f)))))

(def (node-settled? node fp completed-cas-table)
  (or (and (eq? (.ref node 'status) 'done)
           (.ref node 'checklists-done?))
      (cas-hit? node fp completed-cas-table)))

(def (funflow-resume-plan dag
                          completed-cas-table: (completed-cas-table #f)
                          in-flight-ids: (in-flight-ids '())
                          strategy: (strategy DurableGovernedStrategy.)
                          context: (context (.o)))
  (unless (funflow-dag? dag)
    (error "Expected FunFlow DAG" dag))
  (let* ((node-map (.ref dag 'node-map))
         (fp-table (.ref dag 'fingerprint-table))
         (valid? (.ref dag 'valid?))
         (in-flight-syms (map node-id-symbol in-flight-ids))
         (settled-set (make-hash-table-eq))
         (failed-set (make-hash-table-eq))
         (skipped-rev '())
         (done-rev '())
         (failed-rev '())
         (in-flight-rev '())
         (raw-ready-rev '())
         (blocked-rev '())
         (pending-fin-rev '()))
    (when valid?
      (for-each
       (lambda (id)
         (let* ((node (hash-ref node-map id))
                (fp (hash-ref fp-table id ""))
                (st (.ref node 'status))
                (fin-trigger (.ref node 'after-start)))
           (cond
            (fin-trigger
             (when (and (hash-key? failed-set fin-trigger)
                        (not (node-settled? node fp completed-cas-table)))
               (set! pending-fin-rev (cons id pending-fin-rev))))
            ((memq id in-flight-syms)
             (set! in-flight-rev (cons id in-flight-rev)))
            ((memq st '(failed cancelled))
             (hash-put! failed-set id #t)
             (set! failed-rev (cons id failed-rev)))
            ((cas-hit? node fp completed-cas-table)
             (hash-put! settled-set id #t)
             (set! skipped-rev (cons id skipped-rev)))
            ((and (eq? st 'done) (.ref node 'checklists-done?))
             (hash-put! settled-set id #t)
             (set! done-rev (cons id done-rev)))
            (else
             (if (every (lambda (dep) (hash-key? settled-set dep)) (.ref node 'needs))
               (set! raw-ready-rev (cons node raw-ready-rev))
               (set! blocked-rev (cons id blocked-rev)))))))
       (.ref dag 'topological-order)))
    (let* ((raw-ready (reverse raw-ready-rev))
           (admission (strategy-admit-frontier strategy raw-ready context))
           (selected-nodes (.ref admission 'selected))
           (deferred-nodes (.ref admission 'deferred))
           (selected-ids (map (lambda (n) (.ref n 'id)) selected-nodes))
           (deferred-ids (map (lambda (n) (.ref n 'id)) deferred-nodes))
           (skipped (reverse skipped-rev))
           (done-ids (reverse done-rev))
           (failed (reverse failed-rev))
           (in-flight (reverse in-flight-rev))
           (blocked (reverse blocked-rev))
           (pending-fin (reverse pending-fin-rev))
           (complete? (and valid?
                           (null? selected-ids)
                           (null? deferred-ids)
                           (null? blocked)
                           (null? failed)
                           (null? in-flight)
                           (null? pending-fin))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.funflow.resume-plan.v1
          valid?: valid?
          dag-digest: (.ref dag 'dag-digest)
          skipped-nodes: skipped
          done-nodes: done-ids
          ready-frontier: selected-ids
          ready-frontier-nodes: selected-nodes
          deferred-frontier: deferred-ids
          in-flight-nodes: in-flight
          blocked-nodes: blocked
          failed-nodes: failed
          pending-finalizers: pending-fin
          complete?: complete?))))

(def (funflow-replan-epoch prior-dag
                           next-dag
                           completed-cas-table: (completed-cas-table #f)
                           in-flight-ids: (in-flight-ids '())
                           strategy: (strategy DurableGovernedStrategy.)
                           context: (context (.o)))
  (let* ((prior-fps (if (funflow-dag? prior-dag) (.ref prior-dag 'fingerprint-table) (make-hash-table-eq)))
         (next-fps (.ref next-dag 'fingerprint-table))
         (preserved-rev '())
         (invalidated-rev '())
         (added-rev '()))
    (when (.ref next-dag 'valid?)
      (for-each
       (lambda (id)
         (let ((new-fp (hash-ref next-fps id ""))
               (old-fp (hash-get prior-fps id))
               (node (hash-ref (.ref next-dag 'node-map) id)))
           (cond
            ((not old-fp)
             (set! added-rev (cons id added-rev)))
            ((and (equal? old-fp new-fp) (cas-hit? node new-fp completed-cas-table))
             (set! preserved-rev (cons id preserved-rev)))
            ((not (equal? old-fp new-fp))
             (set! invalidated-rev (cons id invalidated-rev)))
            (else (void)))))
       (.ref next-dag 'topological-order)))
    (let ((plan (funflow-resume-plan next-dag
                                     completed-cas-table: completed-cas-table
                                     in-flight-ids: in-flight-ids
                                     strategy: strategy
                                     context: context))
          (preserved (reverse preserved-rev))
          (invalidated (reverse invalidated-rev))
          (added (reverse added-rev)))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.funflow.epoch-replan.v1
          valid?: (.ref next-dag 'valid?)
          prior-dag-digest: (if (funflow-dag? prior-dag) (.ref prior-dag 'dag-digest) #f)
          next-dag-digest: (.ref next-dag 'dag-digest)
          preserved-cas-nodes: preserved
          invalidated-nodes: invalidated
          added-nodes: added
          resume-plan: plan))))

(def FunflowDurableDagExports
  (.o bind-these: #f
      OrchestratorStrategy: OrchestratorStrategy.
      ParallelFrontierStrategy: ParallelFrontierStrategy.
      TieredModelStrategy: TieredModelStrategy.
      DurableGovernedStrategy: DurableGovernedStrategy.
      admit-node: strategy-admit-node
      admit-frontier: strategy-admit-frontier
      cas-fingerprint: strategy-cas-fingerprint
      archive-guard: strategy-archive-guard
      dag-node: funflow-dag-node
      dag-build: funflow-dag-build
      dag?: funflow-dag?
      node-cas-fingerprint: funflow-cas-fingerprint
      admit-frontier-with: funflow-admit-frontier-with
      resume-plan: funflow-resume-plan
      replan-epoch: funflow-replan-epoch))
