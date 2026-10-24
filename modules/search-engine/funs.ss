;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Search composition is declarative; execution remains consumer-owned.
(import (only-in :clan/poo/object .ref object?)
        (only-in :clan/poo/mop Function)
        :yuanxu/object-family/role-syntax
        :agentic-ai-lab/modules/search-engine/objects
        (only-in :yuanxu/modules/funflow/control-plane/flow
                 external-flow flow-fanout flow-input-contract
                 flow-output-contract flow-then)
        (only-in :yuanxu/modules/funflow/control-plane/graph flow->dag-receipt)
        (only-in :agentic-ai-lab/modules/temporal-causality/objects
                 agentic-ai-lab-causal-event agentic-ai-lab-temporal-observation))

(export agentic-ai-lab-search-stage
        agentic-ai-lab-search-chain
        agentic-ai-lab-search-parallel
        agentic-ai-lab-search-merge
        agentic-ai-lab-search-strategy
        agentic-ai-lab-search-factor-observation
        agentic-ai-lab-search-stage?
        agentic-ai-lab-search-composition?
        agentic-ai-lab-search-strategy?
        agentic-ai-lab-search-node-input-domain
        agentic-ai-lab-search-node-output-domain
        agentic-ai-lab-search-node-flow)

(def (agentic-ai-lab-search-kind? value expected)
  (and (object? value)
       (with-catch
        (lambda (_) #f)
        (lambda () (eq? (.ref value 'kind) expected)))))

(def (agentic-ai-lab-search-stage? value)
  (agentic-ai-lab-search-kind? value 'search-stage))

(def (agentic-ai-lab-search-composition? value)
  (agentic-ai-lab-search-kind? value 'search-composition))

(def (agentic-ai-lab-search-strategy? value)
  (agentic-ai-lab-search-kind? value 'search-strategy))

(def (agentic-ai-lab-search-node? value)
  (or (agentic-ai-lab-search-stage? value) (agentic-ai-lab-search-composition? value)))

(def (agentic-ai-lab-search-node-input-domain node)
  (unless (agentic-ai-lab-search-node? node)
    (error "expected a POO Search node" node))
  (.ref node 'input-domain))

(def (agentic-ai-lab-search-node-output-domain node)
  (unless (agentic-ai-lab-search-node? node)
    (error "expected a POO Search node" node))
  (.ref node 'output-domain))

(def (agentic-ai-lab-search-node-flow node)
  (unless (agentic-ai-lab-search-node? node)
    (error "expected a POO Search node" node))
  (.ref node 'flow))

(def (agentic-ai-lab-valid-search-stage-role? role)
  (and (object? role)
       (with-catch
        (lambda (_) #f)
        (lambda () (memq (.ref role 'search/stage-role)
                         '(acquisition refinement reasoning projection))))))

(def (agentic-ai-lab-search-stage name operation arguments input-domain output-domain role
                        . maybe-metadata)
  (unless (and (symbol? name)
               (symbol? operation)
               (list? arguments)
               input-domain
               output-domain
               (agentic-ai-lab-valid-search-stage-role? role)
               (or (null? maybe-metadata)
                   (and (null? (cdr maybe-metadata))
                        (list? (car maybe-metadata)))))
    (error "invalid POO Search stage" name operation input-domain output-domain))
  (let (flow (external-flow name operation arguments
                           (Function (list output-domain) (list input-domain))))
    (poo-core-role-object
     (slots ((name name)
             (operation operation)
             (arguments arguments)
             (input-domain input-domain)
             (output-domain output-domain)
             (flow flow)
             (metadata (if (null? maybe-metadata) '() (car maybe-metadata)))))
     (supers role agentic-ai-lab-search-stage-prototype))))

(def (agentic-ai-lab-search-composition name mode children flow metadata)
  (poo-core-role-object
   (slots ((name name)
           (mode mode)
           (children children)
           (input-domain (flow-input-contract flow))
           (output-domain (flow-output-contract flow))
           (flow flow)
           (metadata metadata)))
   (supers agentic-ai-lab-search-composition-prototype)))

(def (agentic-ai-lab-search-chain name children . maybe-metadata)
  (unless (and (symbol? name) (pair? children))
    (error "Search chain requires a name and at least one node" name children))
  (let loop ((remaining children) (combined #f))
    (if (null? remaining)
      (agentic-ai-lab-search-composition
       name 'sequential children combined
       (if (null? maybe-metadata) '() (car maybe-metadata)))
      (let (node (car remaining))
        (unless (agentic-ai-lab-search-node? node)
          (error "Search chain child is not a POO Search node" node))
        (loop (cdr remaining)
              (if combined
                (flow-then name combined (agentic-ai-lab-search-node-flow node))
                (agentic-ai-lab-search-node-flow node)))))))

(def (agentic-ai-lab-search-parallel name children . maybe-metadata)
  (unless (and (symbol? name) (pair? children) (pair? (cdr children)))
    (error "Search parallel composition requires at least two nodes" name children))
  (let ((input-domain (agentic-ai-lab-search-node-input-domain (car children))))
    (let loop ((remaining children) (combined #f))
      (if (null? remaining)
        (agentic-ai-lab-search-composition
         name 'parallel children combined
         (if (null? maybe-metadata) '() (car maybe-metadata)))
        (let (node (car remaining))
          (unless (and (agentic-ai-lab-search-node? node)
                       (equal? input-domain (agentic-ai-lab-search-node-input-domain node)))
            (error "Search parallel branch domain mismatch" node input-domain))
          (loop (cdr remaining)
                (if combined
                  (flow-fanout name combined (agentic-ai-lab-search-node-flow node))
                  (agentic-ai-lab-search-node-flow node))))))))

(def (agentic-ai-lab-search-merge name parallel merge-stage . maybe-metadata)
  (unless (and (agentic-ai-lab-search-composition? parallel)
               (eq? (.ref parallel 'mode) 'parallel)
               (agentic-ai-lab-search-stage? merge-stage)
               (equal? (agentic-ai-lab-search-node-output-domain parallel)
                       (agentic-ai-lab-search-node-input-domain merge-stage)))
    (error "Search merge requires a compatible parallel composition and stage"
           parallel merge-stage))
  (agentic-ai-lab-search-composition
   name 'merge (list parallel merge-stage)
   (flow-then name (agentic-ai-lab-search-node-flow parallel) (agentic-ai-lab-search-node-flow merge-stage))
   (if (null? maybe-metadata) '() (car maybe-metadata))))

(def (agentic-ai-lab-search-strategy name root policy . maybe-metadata)
  (unless (and (symbol? name) (agentic-ai-lab-search-node? root) (list? policy))
    (error "invalid POO Search strategy" name root policy))
  (poo-core-role-object
   (slots ((name name)
           (root root)
           (policy policy)
           (dag-receipt (flow->dag-receipt (agentic-ai-lab-search-node-flow root)))
           (metadata (if (null? maybe-metadata) '() (car maybe-metadata)))))
   (supers agentic-ai-lab-search-strategy-prototype)))

;;; Search observations reuse Agentic AI Lab's temporal-causality authority.  The
;;; factor name is the event kind; the candidate identity is the payload.
(def (agentic-ai-lab-search-factor-observation
      identity subject factor candidate-identity logical-position
      provenance-identity causal-parent-identities modality committed?)
  (unless (agentic-ai-lab-search-stage? factor)
    (error "Search factor observation requires a POO Search stage" factor))
  (let (observation
        (agentic-ai-lab-temporal-observation
         (string-append identity ":observation")
         'logical-version
         logical-position
         provenance-identity))
    (agentic-ai-lab-causal-event
     identity
     subject
     (.ref factor 'name)
     observation
     candidate-identity
     causal-parent-identities
     modality
     committed?)))
