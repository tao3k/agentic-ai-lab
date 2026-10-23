;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: session graph predicates and presentation receipts.
;;; Invariant: graph helpers inspect report-only session objects.

(import (only-in :clan/poo/object object<-alist)
        :agentic-ai-lab/modules/session/objects-core)

(export agentic-ai-lab-session-by-id
        agentic-ai-lab-session-lineage-edge-pairs
        agentic-ai-lab-session-graph-edge-pairs
        agentic-ai-lab-session-graph-acyclic?
        agenticAiLabSessionGraphPresentation)

;;; Boundary: session by id is the policy-visible edge for object behavior,
;;; keeping validation, lookup, or projection responsibilities centralized for
;;; callers.
;; : (-> [PooSession] Symbol MaybePooSession)
(def (agentic-ai-lab-session-by-id sessions session-id)
  (cond
   ((null? sessions) #f)
   ((eq? (agentic-ai-lab-session-id (car sessions)) session-id) (car sessions))
   (else
    (agentic-ai-lab-session-by-id (cdr sessions) session-id))))

;;; Boundary: session lineage edge pairs is the policy-visible edge for object
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> PooSession [Pair])
(def (agentic-ai-lab-session-lineage-edge-pairs session)
  (reverse (agentic-ai-lab-session-lineage-edge-pairs/rev session '())))

;; : (-> PooSession [Pair] [Pair])
(def (agentic-ai-lab-session-lineage-edge-pairs/rev session edge-pairs)
  (let ((session-id (agentic-ai-lab-session-id session))
        (parent-session-ids
         (agentic-ai-lab-session-lineage-parent-session-ids
          (agentic-ai-lab-session-value-lineage session))))
    (foldl (lambda (parent-session-id edge-pair-values)
             (cons (cons parent-session-id session-id) edge-pair-values))
           edge-pairs
           parent-session-ids)))

;;; Boundary: session graph edge pairs is the policy-visible edge for object
;;; behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [PooSession] [Pair])
(def (agentic-ai-lab-session-graph-edge-pairs sessions)
  (reverse
   (foldl (lambda (session edge-pair-values)
            (agentic-ai-lab-session-lineage-edge-pairs/rev
             session
             edge-pair-values))
          '()
          sessions)))

;;; Boundary: session index is the policy-visible edge for object behavior,
;;; keeping validation, lookup, or projection responsibilities centralized for
;;; callers.
;; : (-> [PooSession] HashTable)
(def (agentic-ai-lab-session-index sessions)
  (let (index (make-hash-table))
    (for-each
     (lambda (session)
       (hash-put! index (agentic-ai-lab-session-id session) session))
     sessions)
    index))

;;; Cycle detection walks parent links by session id only. Missing parents are
;;; treated as external roots so partial user-interface cases remain inspectable.
;; : (-> [PooSession] Symbol [Symbol] Boolean)
(def (agentic-ai-lab-session-graph-acyclic-from? sessions session-id path)
  (cond
   ((memq session-id path) #f)
   (else
    (let (session (agentic-ai-lab-session-by-id sessions session-id))
      (if session
        (agentic-ai-lab-session-every?
         (lambda (parent-id)
           (agentic-ai-lab-session-graph-acyclic-from?
            sessions
            parent-id
            (cons session-id path)))
          (agentic-ai-lab-session-lineage-parent-session-ids
           (agentic-ai-lab-session-value-lineage session)))
        #t)))))

;;; Boundary: session graph acyclic from index predicate is the policy-visible
;;; edge for object behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> HashTable HashTable Symbol Boolean)
(def (agentic-ai-lab-session-graph-acyclic-from-index? session-index visit-states session-id)
  (let (state (hash-get visit-states session-id))
    (cond
     ((eq? state 'visiting) #f)
     ((eq? state 'done) #t)
     (else
      (let (session (hash-get session-index session-id))
        (if session
          (begin
            (hash-put! visit-states session-id 'visiting)
            (let (acyclic?
                  (agentic-ai-lab-session-every?
                   (lambda (parent-id)
                     (agentic-ai-lab-session-graph-acyclic-from-index?
                      session-index
                      visit-states
                      parent-id))
                   (agentic-ai-lab-session-lineage-parent-session-ids
                    (agentic-ai-lab-session-value-lineage session))))
              (if acyclic?
                (hash-put! visit-states session-id 'done)
                #f)
              acyclic?))
          #t))))))

;;; Boundary: session graph acyclic predicate is the policy-visible edge for
;;; object behavior, keeping validation, lookup, or projection responsibilities
;;; centralized for callers.
;; : (-> [PooSession] Boolean)
(def (agentic-ai-lab-session-graph-acyclic? sessions)
  (let ((session-index (agentic-ai-lab-session-index sessions))
        (visit-states (make-hash-table)))
    (agentic-ai-lab-session-every?
     (lambda (session)
       (agentic-ai-lab-session-graph-acyclic-from-index?
        session-index
        visit-states
        (agentic-ai-lab-session-id session)))
     sessions)))

;;; The graph presentation is intentionally compact. It exposes ids, edges,
;;; placement refs, and runtime flags without embedding the full session object
;;; graph in downstream receipts.
;; : (-> [PooSession] List)
(def (agentic-ai-lab-session-graph-presentation-summary sessions)
  (foldl (lambda (session summary)
           (let* ((session-count-value (car summary))
                  (session-id-values (cadr summary))
                  (chunk-count-value (caddr summary))
                  (lineage-edge-pair-values (cadddr summary))
                  (placement-summary-values (cddddr summary))
                  (placement-profile-ref-values (car placement-summary-values))
                  (placement-resolved-values (cadr placement-summary-values))
                  (placement-diagnostic-values (caddr placement-summary-values))
                  (placement (agentic-ai-lab-session-value-placement session)))
             (list
              (+ session-count-value 1)
              (cons (agentic-ai-lab-session-id session) session-id-values)
              (+ chunk-count-value (length (agentic-ai-lab-session-chunks session)))
              (agentic-ai-lab-session-lineage-edge-pairs/rev
               session
               lineage-edge-pair-values)
              (cons (agentic-ai-lab-session-placement-profile-ref placement)
                    placement-profile-ref-values)
              (cons (agentic-ai-lab-session-placement-resolved? placement)
                    placement-resolved-values)
              (cons (agentic-ai-lab-session-placement-diagnostics placement)
                    placement-diagnostic-values))))
         '(0 () 0 () () () ())
         sessions))

;; : (-> [PooSession] PooSessionGraphPresentation)
(def (agenticAiLabSessionGraphPresentation sessions)
  (agentic-ai-lab-session-require "session graph presentation requires sessions"
                            (list? sessions)
                            sessions)
  (agentic-ai-lab-session-require
   "session graph presentation entries must be sessions"
   (agentic-ai-lab-session-every? agentic-ai-lab-session? sessions)
   sessions)
  (let* ((summary (agentic-ai-lab-session-graph-presentation-summary sessions))
         (session-count-value (car summary))
         (session-id-values (reverse (cadr summary)))
         (chunk-count-value (caddr summary))
         (lineage-edge-pair-values (reverse (cadddr summary)))
         (placement-summary-values (cddddr summary))
         (placement-profile-ref-values (reverse (car placement-summary-values)))
         (placement-resolved-values (reverse (cadr placement-summary-values)))
         (placement-diagnostic-values (reverse (caddr placement-summary-values))))
    (object<-alist
     (list
      (cons 'kind 'agentic-ai-lab.session.graph.presentation)
      (cons 'schema 'agentic-ai-lab.modules.session.graph-presentation.v1)
      (cons 'session-count session-count-value)
      (cons 'session-ids session-id-values)
      (cons 'chunk-count chunk-count-value)
      (cons 'lineage-edge-pairs lineage-edge-pair-values)
      (cons 'acyclic? (agentic-ai-lab-session-graph-acyclic? sessions))
      (cons 'placement-profile-refs placement-profile-ref-values)
      (cons 'placement-resolved? placement-resolved-values)
      (cons 'placement-diagnostics placement-diagnostic-values)
      (cons 'runtime-owner "marlin-agent-core")
      (cons 'runtime-executed #f)
      (cons 'descriptor-realized? #f)
      (cons 'replayable #t)))))
