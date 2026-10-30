;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Pure Search control decisions; physical execution remains consumer-owned.
(import (only-in :clan/poo/object .ref object?)
        (only-in :std/list/list every filter ormap)
        :yuanxu/object-family/role-syntax
        :agentic-ai-lab/modules/search-engine/funs
        :agentic-ai-lab/modules/search-engine/attempt
        (only-in :agentic-ai-lab/modules/temporal-causality/types agentic-ai-lab-causal-event?)
        (only-in :agentic-ai-lab/modules/temporal-causality/objects
                 agentic-ai-lab-temporal-observation agentic-ai-lab-causal-event)
        (only-in :agentic-ai-lab/modules/temporal-causality/funs agentic-ai-lab-causal-event-graph))
(export agentic-ai-lab-search-engine agentic-ai-lab-search-engine-frontier
        agentic-ai-lab-search-engine-issue agentic-ai-lab-search-engine-complete
        agentic-ai-lab-search-engine-revise agentic-ai-lab-search-engine-node
        agentic-ai-lab-search-engine-cancel
        agentic-ai-lab-search-engine-require-evidence agentic-ai-lab-search-engine-observe
        agentic-ai-lab-search-engine-inputs)

;;; Private lowering protocol; the public engine and nodes are POO objects.
(defstruct lowered (nodes terminals))
(def (lower-search node parents generation configuration source-cut)
  (cond
   ((agentic-ai-lab-search-stage? node)
    (let (name (.ref node 'name))
      (unless (symbol? name) (error "Search stage requires a symbolic identity"))
      (make-lowered
       (list (poo-core-role-object
              (slots ((kind 'search-engine-node) (name name) (stage node)
                      (dependencies (map values parents))
                      (state (agentic-ai-lab-search-attempt-state node generation configuration source-cut))
                      (request #f) (completion #f) (evidence #f))) (supers)))
       (list name))))
   ((agentic-ai-lab-search-composition? node)
    (let ((children (.ref node 'children)) (mode (.ref node 'mode)))
      (unless (and (list? children) (pair? children)
                   (memq mode '(sequential parallel merge)))
        (error "invalid Search composition topology"))
      (if (eq? mode 'parallel)
        (let loop ((remaining children) (nodes '()) (terminals '()))
          (if (null? remaining) (make-lowered nodes terminals)
            (let (part (lower-search (car remaining) parents generation configuration source-cut))
              (loop (cdr remaining) (append nodes (lowered-nodes part))
                    (append terminals (lowered-terminals part))))))
        (let loop ((remaining children) (nodes '()) (previous parents))
          (if (null? remaining) (make-lowered nodes previous)
            (let (part (lower-search (car remaining) previous generation configuration source-cut))
              (loop (cdr remaining) (append nodes (lowered-nodes part))
                    (lowered-terminals part))))))))
   (else (error "expected a Search stage or composition"))))

(def (agentic-ai-lab-search-engine strategy generation configuration source-cut)
  (unless (agentic-ai-lab-search-strategy? strategy) (error "expected Search strategy"))
  (let* ((lowered (lower-search (.ref strategy 'root) '() generation configuration source-cut))
         (nodes (lowered-nodes lowered)))
    ;; Lowering is parent-first. Require unique identities and earlier references.
    (let loop ((remaining nodes) (seen '()))
      (unless (null? remaining)
        (let* ((node (car remaining)) (name (.ref node 'name)))
          (when (or (memq name seen)
                    (not (every (lambda (parent) (memq parent seen)) (.ref node 'dependencies))))
            (error "duplicate Search stage identity or invalid dependency" name))
          (loop (cdr remaining) (cons name seen)))))
    (poo-core-role-object
     (slots ((kind 'search-engine) (strategy strategy) (nodes nodes) (evidence-required? #f) (event-identities '()))) (supers))))

(def (require-engine engine)
  (unless (and (object? engine) (eq? (.ref engine 'kind) 'search-engine))
    (error "expected Search engine")))
(def (agentic-ai-lab-search-engine-node engine name)
  (require-engine engine)
  (or (let loop ((nodes (.ref engine 'nodes)))
        (and (pair? nodes)
             (if (eq? name (.ref (car nodes) 'name)) (car nodes) (loop (cdr nodes)))))
      (error "unknown Search stage" name)))

(def (node-ready? engine node)
  (let* ((state (.ref node 'state))
         (parents (map (lambda (name) (agentic-ai-lab-search-engine-node engine name))
                       (.ref node 'dependencies))))
    (and (not (.ref state 'retired?)) (not (.ref state 'active))
         (not (.ref node 'completion))
         (or (not (.ref engine 'evidence-required?))
             (every (lambda (parent) (.ref parent 'evidence)) parents))
         (agentic-ai-lab-search-attempt-ready? state
           (map (lambda (parent) (.ref parent 'request)) parents)
           (map (lambda (parent) (.ref parent 'completion)) parents)))))

(def (agentic-ai-lab-search-engine-frontier engine)
  (require-engine engine)
  (map (lambda (node) (.ref node 'name))
       (filter (lambda (node) (node-ready? engine node)) (.ref engine 'nodes))))

(def (replace-node engine replacement)
  (poo-core-role-object
   (slots ((nodes (map (lambda (node)
                        (if (eq? (.ref node 'name) (.ref replacement 'name))
                          replacement node)) (.ref engine 'nodes)))))
   (supers engine)))

(def (agentic-ai-lab-search-engine-issue engine name)
  (let (node (agentic-ai-lab-search-engine-node engine name))
    (unless (node-ready? engine node) (error "Search stage is not ready" name))
    (let* ((issued (agentic-ai-lab-search-attempt-issue (.ref node 'state)))
           (request (.ref issued 'request))
           (next (poo-core-role-object
                  (slots ((state (.ref issued 'state)) (request request))) (supers node))))
      (poo-core-role-object
       (slots ((kind 'search-engine-issue) (engine (replace-node engine next))
               (request request))) (supers)))))

(def (complete-node engine name request)
  (let* ((node (agentic-ai-lab-search-engine-node engine name))
         (completion (agentic-ai-lab-search-attempt-complete (.ref node 'state) request))
         (next (poo-core-role-object
                (slots ((state (.ref completion 'state)) (completion completion))) (supers node))))
    (replace-node engine next)))


;;; Select the evidence contract before issuing any work. This is a pure POO refinement.
(def (agentic-ai-lab-search-engine-require-evidence engine)
  (require-engine engine)
  (unless (every (lambda (node) (= (.ref (.ref node 'state) 'next-attempt) 0)) (.ref engine 'nodes))
    (error "Search evidence contract must be selected before execution"))
  (poo-core-role-object (slots ((evidence-required? #t))) (supers engine)))

(def (agentic-ai-lab-search-engine-complete engine name request)
  (when (.ref engine 'evidence-required?)
    (error "Search evidence contract requires an admitted Temporal observation"))
  (complete-node engine name request))

;;; Snapshot text identities so later mutation of caller-owned strings cannot change evidence.
(def (snapshot-event event)
  (let (observation (.ref event 'observation))
    (agentic-ai-lab-causal-event
     (string-copy (.ref event 'identity)) (string-copy (.ref event 'subject))
     (.ref event 'event-kind)
     (agentic-ai-lab-temporal-observation
      (string-copy (.ref observation 'identity)) (.ref observation 'clock-role)
      (.ref observation 'logical-position)
      (string-copy (.ref observation 'provenance-identity)))
     (string-copy (.ref event 'payload-identity))
     (map string-copy (.ref event 'causal-parent-identities))
     (.ref event 'modality) (.ref event 'committed?))))

;;; Read evidence through the owner contract and return detached snapshots.
;;; Consumers must not mutate retained evidence through their input values.
(def (agentic-ai-lab-search-engine-inputs engine name request)
  (let (node (agentic-ai-lab-search-engine-node engine name))
    (unless (and (.ref engine 'evidence-required?)
                 (agentic-ai-lab-search-attempt-current? (.ref node 'state) request))
      (error "Search inputs require a current evidence-bound attempt"))
    (map (lambda (parent)
           (let (event (.ref (agentic-ai-lab-search-engine-node engine parent) 'evidence))
             (unless event (error "missing Search predecessor evidence"))
             (snapshot-event event)))
         (.ref node 'dependencies))))

(def (agentic-ai-lab-search-engine-observe engine name request event)
  (let* ((node (agentic-ai-lab-search-engine-node engine name))
         (state (.ref node 'state))
         (parents (map (lambda (parent) (agentic-ai-lab-search-engine-node engine parent))
                       (.ref node 'dependencies))))
    (unless (and (.ref engine 'evidence-required?)
                 (agentic-ai-lab-search-attempt-current? state request)
                 (agentic-ai-lab-causal-event? event)
                 (not (member (.ref event 'identity) (.ref engine 'event-identities)))
                 (.ref event 'committed?)
                 (memq (.ref event 'modality) '(observed derived))
                 (eq? (.ref event 'event-kind) name)
                 (eq? (.ref (.ref event 'observation) 'clock-role) 'logical-version)
                 (integer? (.ref (.ref event 'observation) 'logical-position))
                 (>= (.ref (.ref event 'observation) 'logical-position) 0)
                 (equal? (.ref event 'subject) (.ref request 'generation))
                 (equal? (.ref (.ref event 'observation) 'provenance-identity)
                         (.ref request 'source-cut))
                 (every (lambda (parent) (.ref parent 'evidence)) parents))
      (error "Search observation does not match the current evidence contract"))
    (let* ((expected (map (lambda (parent) (.ref (.ref parent 'evidence) 'identity)) parents))
           (actual (.ref event 'causal-parent-identities)))
      (unless (and (= (length actual) (length expected))
                   (every (lambda (identity) (member identity expected)) actual))
        (error "Search causal parents must match current predecessor evidence"))
      (let* ((retained (filter values (map (lambda (entry) (.ref entry 'evidence))
                                          (.ref engine 'nodes))))
             (snapshot (snapshot-event event))
             (graph (agentic-ai-lab-causal-event-graph (.ref request 'generation)
                                                (cons snapshot retained))))
        (unless (.ref graph 'complete?)
          (error "Search observation has missing or temporally invalid causal parents"))
        (let* ((completed (complete-node engine name request))
               (next (agentic-ai-lab-search-engine-node completed name)))
          (poo-core-role-object
           (slots ((event-identities (cons (string-copy (.ref snapshot 'identity))
                                          (.ref engine 'event-identities)))))
           (supers (replace-node completed
                     (poo-core-role-object (slots ((evidence snapshot))) (supers next))))))))))

;;; Logical cancellation belongs to the generic engine, not its Rust consumer.
;;; An old request is a no-op; exact cancellation invalidates descendants too.
(def (agentic-ai-lab-search-engine-cancel engine name request)
  (let (node (agentic-ai-lab-search-engine-node engine name))
    (if (agentic-ai-lab-search-attempt-current? (.ref node 'state) request)
      (agentic-ai-lab-search-engine-revise engine (list name) (.ref request 'source-cut))
      engine)))

;;; Same finite reverse-edge propagation as LeanPoo invalidatedNodes:
;;; changed identities plus structural descendants, bounded by node count.
(def (affected-names nodes changed)
  (let loop ((fuel (length nodes)) (affected changed))
    (if (= fuel 0) affected
      (loop (- fuel 1)
        (foldl (lambda (node acc)
                 (let (name (.ref node 'name))
                   (if (or (memq name acc)
                           (not (ormap (lambda (parent) (memq parent affected))
                                       (.ref node 'dependencies))))
                     acc (cons name acc))))
               affected nodes)))))

(def (agentic-ai-lab-search-engine-revise engine changed source-cut)
  (require-engine engine)
  (unless (list? changed) (error "expected changed Search stage identities"))
  (for-each (lambda (name) (agentic-ai-lab-search-engine-node engine name)) changed)
  (let (affected (affected-names (.ref engine 'nodes) changed))
    (poo-core-role-object
     (slots ((nodes
              (map (lambda (node)
                     (if (memq (.ref node 'name) affected)
                       (poo-core-role-object
                        (slots ((state (agentic-ai-lab-search-attempt-revise (.ref node 'state) source-cut))
                                (request #f) (completion #f) (evidence #f))) (supers node))
                       node)) (.ref engine 'nodes)))))
     (supers engine))))
