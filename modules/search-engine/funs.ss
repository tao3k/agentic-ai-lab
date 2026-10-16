;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Search composition is declarative; execution remains consumer-owned.
(import (only-in :clan/poo/object .ref object?)
        :core/object-family/role-syntax
        :poo-flow/modules/search-engine/objects
        (only-in :poo-flow/modules/workflow/control-plane/flow
                 external-flow flow-fanout flow-input-contract
                 flow-output-contract flow-then)
        (only-in :poo-flow/modules/workflow/control-plane/plan flow->dag-receipt)
        (only-in :poo-flow/modules/temporal-causality/objects
                 poo-flow-causal-event poo-flow-temporal-observation))

(export poo-flow-search-stage
        poo-flow-search-chain
        poo-flow-search-parallel
        poo-flow-search-merge
        poo-flow-search-strategy
        poo-flow-search-factor-observation
        poo-flow-search-stage?
        poo-flow-search-composition?
        poo-flow-search-strategy?
        poo-flow-search-node-input-domain
        poo-flow-search-node-output-domain
        poo-flow-search-node-flow)

(def (poo-flow-search-kind? value expected)
  (and (object? value)
       (with-catch
        (lambda (_) #f)
        (lambda () (eq? (.ref value 'kind) expected)))))

(def (poo-flow-search-stage? value)
  (poo-flow-search-kind? value 'search-stage))

(def (poo-flow-search-composition? value)
  (poo-flow-search-kind? value 'search-composition))

(def (poo-flow-search-strategy? value)
  (poo-flow-search-kind? value 'search-strategy))

(def (poo-flow-search-node? value)
  (or (poo-flow-search-stage? value) (poo-flow-search-composition? value)))

(def (poo-flow-search-node-input-domain node)
  (unless (poo-flow-search-node? node)
    (error "expected a POO Search node" node))
  (.ref node 'input-domain))

(def (poo-flow-search-node-output-domain node)
  (unless (poo-flow-search-node? node)
    (error "expected a POO Search node" node))
  (.ref node 'output-domain))

(def (poo-flow-search-node-flow node)
  (unless (poo-flow-search-node? node)
    (error "expected a POO Search node" node))
  (.ref node 'flow))

(def (poo-flow-valid-search-stage-role? role)
  (and (object? role)
       (with-catch
        (lambda (_) #f)
        (lambda () (memq (.ref role 'search/stage-role)
                         '(acquisition refinement reasoning projection))))))

(def (poo-flow-search-stage name operation arguments input-domain output-domain role
                        . maybe-metadata)
  (unless (and (symbol? name)
               (symbol? operation)
               (list? arguments)
               input-domain
               output-domain
               (poo-flow-valid-search-stage-role? role)
               (or (null? maybe-metadata)
                   (and (null? (cdr maybe-metadata))
                        (list? (car maybe-metadata)))))
    (error "invalid POO Search stage" name operation input-domain output-domain))
  (let (flow (external-flow name operation arguments input-domain output-domain))
    (poo-core-role-object
     (slots ((name name)
             (operation operation)
             (arguments arguments)
             (input-domain input-domain)
             (output-domain output-domain)
             (flow flow)
             (metadata (if (null? maybe-metadata) '() (car maybe-metadata)))))
     (supers role poo-flow-search-stage-prototype))))

(def (poo-flow-search-composition name mode children flow metadata)
  (poo-core-role-object
   (slots ((name name)
           (mode mode)
           (children children)
           (input-domain (flow-input-contract flow))
           (output-domain (flow-output-contract flow))
           (flow flow)
           (metadata metadata)))
   (supers poo-flow-search-composition-prototype)))

(def (poo-flow-search-chain name children . maybe-metadata)
  (unless (and (symbol? name) (pair? children))
    (error "Search chain requires a name and at least one node" name children))
  (let loop ((remaining children) (combined #f) (previous #f))
    (if (null? remaining)
      (poo-flow-search-composition
       name 'sequential children combined
       (if (null? maybe-metadata) '() (car maybe-metadata)))
      (let (node (car remaining))
        (unless (poo-flow-search-node? node)
          (error "Search chain child is not a POO Search node" node))
        (when (and previous
                   (not (equal? (poo-flow-search-node-output-domain previous)
                                (poo-flow-search-node-input-domain node))))
          (error "Search chain domain mismatch"
                 (poo-flow-search-node-output-domain previous)
                 (poo-flow-search-node-input-domain node)))
        (loop (cdr remaining)
              (if combined
                (flow-then name combined (poo-flow-search-node-flow node))
                (poo-flow-search-node-flow node))
              node)))))

(def (poo-flow-search-parallel name children . maybe-metadata)
  (unless (and (symbol? name) (pair? children) (pair? (cdr children)))
    (error "Search parallel composition requires at least two nodes" name children))
  (let ((input-domain (poo-flow-search-node-input-domain (car children))))
    (let loop ((remaining children) (combined #f))
      (if (null? remaining)
        (poo-flow-search-composition
         name 'parallel children combined
         (if (null? maybe-metadata) '() (car maybe-metadata)))
        (let (node (car remaining))
          (unless (and (poo-flow-search-node? node)
                       (equal? input-domain (poo-flow-search-node-input-domain node)))
            (error "Search parallel branch domain mismatch" node input-domain))
          (loop (cdr remaining)
                (if combined
                  (flow-fanout name combined (poo-flow-search-node-flow node))
                  (poo-flow-search-node-flow node))))))))

(def (poo-flow-search-merge name parallel merge-stage . maybe-metadata)
  (unless (and (poo-flow-search-composition? parallel)
               (eq? (.ref parallel 'mode) 'parallel)
               (poo-flow-search-stage? merge-stage)
               (equal? (poo-flow-search-node-output-domain parallel)
                       (poo-flow-search-node-input-domain merge-stage)))
    (error "Search merge requires a compatible parallel composition and stage"
           parallel merge-stage))
  (poo-flow-search-composition
   name 'merge (list parallel merge-stage)
   (flow-then name (poo-flow-search-node-flow parallel) (poo-flow-search-node-flow merge-stage))
   (if (null? maybe-metadata) '() (car maybe-metadata))))

(def (poo-flow-search-strategy name root policy . maybe-metadata)
  (unless (and (symbol? name) (poo-flow-search-node? root) (list? policy))
    (error "invalid POO Search strategy" name root policy))
  (poo-core-role-object
   (slots ((name name)
           (root root)
           (policy policy)
           (dag-receipt (flow->dag-receipt (poo-flow-search-node-flow root)))
           (metadata (if (null? maybe-metadata) '() (car maybe-metadata)))))
   (supers poo-flow-search-strategy-prototype)))

;;; Search observations reuse POO Flow's temporal-causality authority.  The
;;; factor name is the event kind; the candidate identity is the payload.
(def (poo-flow-search-factor-observation
      identity subject factor candidate-identity logical-position
      provenance-identity causal-parent-identities modality committed?)
  (unless (poo-flow-search-stage? factor)
    (error "Search factor observation requires a POO Search stage" factor))
  (let (observation
        (poo-flow-temporal-observation
         (string-append identity ":observation")
         'logical-version
         logical-position
         provenance-identity))
    (poo-flow-causal-event
     identity
     subject
     (.ref factor 'name)
     observation
     candidate-identity
     causal-parent-identities
     modality
     committed?)))
