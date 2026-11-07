;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: report-only project/root/child session registry receipts.
;;; Invariant: the registry is a projection, not a live runtime store.

(import (only-in :clan/poo/object .o .ref object?)
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy)

(export agentic-ai-lab-session-registry-entry
        agentic-ai-lab-session-registry-entry?
        agentic-ai-lab-session-registry-entry-session-id
        agentic-ai-lab-session-registry-entry-agent-id
        agentic-ai-lab-session-registry-entry-parent-session-ids
        agentic-ai-lab-session-registry-receipt
        agentic-ai-lab-session-registry-receipt?
        agentic-ai-lab-session-registry-receipt-project-id
        agentic-ai-lab-session-registry-receipt-session-ids
        agentic-ai-lab-session-registry-receipt-entries
        agentic-ai-lab-session-registry-receipt->alist)

;; : (-> Alist Symbol Value Value)
(def (agentic-ai-lab-session-registry-policy-ref summaries key default)
  (let (entry (assoc key summaries))
    (if entry (cdr entry) default)))

;; : (-> Alist Symbol Value Value)
(def (agentic-ai-lab-session-registry-alist-ref row key default)
  (let (entry (and (list? row) (assoc key row)))
    (if entry (cdr entry) default)))

;;; Boundary: registry callers construct explicit field pairs; this function
;;; preserves their order without introducing a syntax-only row language.
;; : (-> (List (Pair Symbol Object)) (List (Pair Symbol Object)))
(def (agentic-ai-lab-session-registry-field-rows . rows)
  rows)

;; : (-> Alist MaybeSymbol)
(def (agentic-ai-lab-session-registry-durable-policy-ref policy-summaries)
  (let (durable-summary
        (agentic-ai-lab-session-registry-policy-ref
         policy-summaries
         'durable
         '()))
    (agentic-ai-lab-session-registry-alist-ref
     durable-summary
     'policy-id
     #f)))

;; : (-> [PooSessionRegistryEntry] SessionRegistryEntrySummary)
(def (agentic-ai-lab-session-registry-entry-summary entries)
  (list
   (map agentic-ai-lab-session-registry-entry-session-id entries)
   (filter-map
    (lambda (entry)
      (agentic-ai-lab-session-alist-ref entry 'durable-policy-ref #f))
    entries)))

;;; Boundary: registry entries preserve parent/child session identity and
;;; allowed communication refs for later lookup policy.
;; : (-> PooSession Symbol [Symbol] Alist [Alist] PooSessionRegistryEntry)
(def (agentic-ai-lab-session-registry-entry session
                                      agent-id
                                      communication-channels
                                      policy-summaries
                                      . maybe-metadata)
  (agentic-ai-lab-session-require "session registry entry requires a session"
                            (agentic-ai-lab-session? session)
                            session)
  (agentic-ai-lab-session-require "session registry agent id must be a symbol"
                            (symbol? agent-id)
                            agent-id)
  (agentic-ai-lab-session-require "session registry channels must be symbols"
                            (agentic-ai-lab-session-every?
                             symbol?
                             communication-channels)
                            communication-channels)
  (agentic-ai-lab-session-require "session registry policies must be an alist"
                            (list? policy-summaries)
                            policy-summaries)
  (let* ((session-id-value (agentic-ai-lab-session-id session))
         (lineage-value (agentic-ai-lab-session-value-lineage session))
         (placement-value (agentic-ai-lab-session-value-placement session)))
    (agentic-ai-lab-session-registry-field-rows
     (cons 'kind 'agentic-ai-lab.session.registry-entry)
     (cons 'schema 'agentic-ai-lab.modules.session.registry-entry.v1)
     (cons 'session-id session-id-value)
     (cons 'parent-session-ids
      (agentic-ai-lab-session-lineage-parent-session-ids lineage-value))
     (cons 'agent-id agent-id)
     (cons 'placement-profile-ref
      (agentic-ai-lab-session-placement-profile-ref placement-value))
     (cons 'placement-resolved?
      (agentic-ai-lab-session-placement-resolved? placement-value))
     (cons 'communication-channels communication-channels)
     (cons 'isolation-policy-summary
      (agentic-ai-lab-session-registry-policy-ref
       policy-summaries
       'isolation
       '()))
     (cons 'sandbox-policy-summary
      (agentic-ai-lab-session-registry-policy-ref
       policy-summaries
       'sandbox
       '()))
     (cons 'context-policy-summary
      (agentic-ai-lab-session-registry-policy-ref
       policy-summaries
       'context
       '()))
     (cons 'history-policy-summary
      (agentic-ai-lab-session-registry-policy-ref
       policy-summaries
       'history
       '()))
     (cons 'sharing-policy-summary
      (agentic-ai-lab-session-registry-policy-ref
       policy-summaries
       'sharing
       '()))
     (cons 'resource-policy-summary
      (agentic-ai-lab-session-registry-policy-ref
       policy-summaries
       'resource
       '()))
     (cons 'durable-policy-summary
      (agentic-ai-lab-session-registry-policy-ref
       policy-summaries
       'durable
       '()))
     (cons 'durable-policy-ref
      (agentic-ai-lab-session-registry-durable-policy-ref policy-summaries))
     (cons 'materialization-state 'declared)
     (cons 'runtime-owner "marlin-agent-core")
     (cons 'runtime-executed #f)
     (cons 'metadata (if (null? maybe-metadata)
                 '()
                 (car maybe-metadata))))))

;; : (-> Datum Boolean)
(def (agentic-ai-lab-session-registry-entry? value)
  (and (list? value)
       (eq? (agentic-ai-lab-session-alist-ref value 'kind #f)
            'agentic-ai-lab.session.registry-entry)))

;; : (-> PooSessionRegistryEntry Symbol)
(def (agentic-ai-lab-session-registry-entry-session-id entry)
  (agentic-ai-lab-session-alist-ref entry 'session-id #f))

;; : (-> PooSessionRegistryEntry Symbol)
(def (agentic-ai-lab-session-registry-entry-agent-id entry)
  (agentic-ai-lab-session-alist-ref entry 'agent-id #f))

;; : (-> PooSessionRegistryEntry [Symbol])
(def (agentic-ai-lab-session-registry-entry-parent-session-ids entry)
  (agentic-ai-lab-session-alist-ref entry 'parent-session-ids '()))

;; : (-> Symbol [Symbol] [Symbol] Symbol [PooSessionRegistryEntry] [Alist] PooSessionRegistryReceipt)
(def (agentic-ai-lab-session-registry-receipt project-id
                                        root-session-ids
                                        child-session-ids
                                        active-session-ref
                                        entries
                                        . maybe-metadata)
  (agentic-ai-lab-session-require "session registry project id must be a symbol"
                            (symbol? project-id)
                            project-id)
  (agentic-ai-lab-session-require "session registry roots must be symbols"
                            (agentic-ai-lab-session-every?
                             symbol?
                             root-session-ids)
                            root-session-ids)
  (agentic-ai-lab-session-require "session registry children must be symbols"
                            (agentic-ai-lab-session-every?
                             symbol?
                             child-session-ids)
                            child-session-ids)
  (agentic-ai-lab-session-require "session registry active ref must be a symbol"
                            (symbol? active-session-ref)
                            active-session-ref)
  (agentic-ai-lab-session-require "session registry entries must be entries"
                            (agentic-ai-lab-session-every?
                             agentic-ai-lab-session-registry-entry?
                             entries)
                            entries)
  ;; `.o` slot bodies treat a bare identifier matching the slot name as
  ;; self-dispatch. Capture constructor inputs under distinct lexical names so
  ;; receipt reads cannot turn into recursive project-id/session-id lookups.
  (let* ((project-id-value project-id)
         (root-session-id-values root-session-ids)
         (child-session-id-values child-session-ids)
         (active-session-ref-value active-session-ref)
         (entry-values entries)
         (metadata-value
          (if (null? maybe-metadata) '() (car maybe-metadata)))
         (entry-summary
          (agentic-ai-lab-session-registry-entry-summary entry-values))
         (session-id-values (car entry-summary))
         (durable-policy-ref-values (cadr entry-summary)))
    (.o (kind 'agentic-ai-lab.session.registry-receipt)
        (schema 'agentic-ai-lab.modules.session.registry-receipt.v1)
        (project-id project-id-value)
        (root-session-ids root-session-id-values)
        (child-session-ids child-session-id-values)
        (session-ids session-id-values)
        (active-session-ref active-session-ref-value)
        (durable-policy-refs durable-policy-ref-values)
        (entry-count (length entry-values))
        (entries entry-values)
        (runtime-owner "marlin-agent-core")
        (runtime-executed #f)
        (metadata metadata-value))))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-session-registry-receipt? value)
  (and (object? value)
       (eq? (.ref value 'kind)
            'agentic-ai-lab.session.registry-receipt)))

;; : (-> PooSessionRegistryReceipt Symbol)
(def (agentic-ai-lab-session-registry-receipt-project-id receipt)
  (.ref receipt 'project-id))

;; : (-> PooSessionRegistryReceipt [Symbol])
(def (agentic-ai-lab-session-registry-receipt-session-ids receipt)
  (.ref receipt 'session-ids))

;; : (-> PooSessionRegistryReceipt [PooSessionRegistryEntry])
(def (agentic-ai-lab-session-registry-receipt-entries receipt)
  (.ref receipt 'entries))

;; : (-> PooSessionRegistryReceipt Alist)
(def (agentic-ai-lab-session-registry-receipt->alist receipt)
  (agentic-ai-lab-session-require
   "session registry projection requires a receipt"
   (agentic-ai-lab-session-registry-receipt? receipt)
   receipt)
  (list
   (cons 'kind (.ref receipt 'kind))
   (cons 'schema (.ref receipt 'schema))
   (cons 'project-id (.ref receipt 'project-id))
   (cons 'root-session-ids (.ref receipt 'root-session-ids))
   (cons 'child-session-ids (.ref receipt 'child-session-ids))
   (cons 'session-ids (.ref receipt 'session-ids))
   (cons 'active-session-ref (.ref receipt 'active-session-ref))
   (cons 'durable-policy-refs (.ref receipt 'durable-policy-refs))
   (cons 'entry-count (.ref receipt 'entry-count))
   (cons 'entries (.ref receipt 'entries))
   (cons 'runtime-owner (.ref receipt 'runtime-owner))
   (cons 'runtime-executed (.ref receipt 'runtime-executed))
   (cons 'metadata (.ref receipt 'metadata))))
