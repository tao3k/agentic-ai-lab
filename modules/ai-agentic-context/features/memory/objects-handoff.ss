;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: memory handoff manifest objects and projections.

(import (only-in :clan/poo/object .o .ref object? object<-alist)
        :core/utilities/final-projection-syntax
        :poo-flow/modules/session/objects
        :poo-flow/modules/session/transform
        :poo-flow/modules/ai-agentic-context/features/memory/objects-core)

(export poo-flow-memory-handoff-manifest-receipt
        make-poo-flow-memory-handoff-manifest-receipt
        poo-flow-memory-handoff-manifest-receipt?
        poo-flow-memory-handoff-manifest
        poo-flow-memory-handoff-manifest?
        poo-flow-memory-handoff-manifest->alist)

(defstruct poo-flow-memory-handoff-manifest-receipt
  (kind
   schema
   request-id
   store-ref
   store-kind
   namespace
   scopes
   recall-policies
   commit-policies
   operation
   runtime-owner
   runtime-backend
   durable?
   handoff-ready?
   diagnostic-count
   diagnostics
   runtime-executed
   metadata)
  transparent: #t)
;; : (-> Symbol PooMemoryStoreSpec [Alist] PooMemoryHandoffManifest)
(def (poo-flow-memory-handoff-manifest request-id spec . maybe-metadata)
  (poo-flow-session-require "memory handoff request id must be a symbol"
                            (symbol? request-id)
                            request-id)
  (poo-flow-session-require "memory handoff requires a store spec"
                            (poo-flow-memory-store-spec? spec)
                            spec)
  (poo-flow-memory-runtime-object
   (list
    (cons 'kind +poo-flow-ai-agentic-context-memory-handoff-manifest-kind+)
    (cons 'schema 'poo-flow.modules.memory-core.handoff-manifest.v1)
    (cons 'request-id request-id)
    (cons 'store-ref (poo-flow-memory-store-spec-ref spec))
    (cons 'store-kind (.ref spec 'store-kind))
    (cons 'namespace (.ref spec 'namespace))
    (cons 'scopes (.ref spec 'scopes))
    (cons 'recall-policies (.ref spec 'recall-policies))
    (cons 'commit-policies (.ref spec 'commit-policies))
    (cons 'operation (.ref spec 'handoff-operation))
    (cons 'runtime-owner (.ref spec 'runtime-owner))
    (cons 'runtime-backend (.ref spec 'runtime-backend))
    (cons 'durable? (.ref spec 'durable?))
    (cons 'handoff-ready? #t)
    (cons 'diagnostic-count 0)
    (cons 'diagnostics '())
    (cons 'runtime-executed #f)
    (cons 'metadata (if (null? maybe-metadata)
                      '()
                      (car maybe-metadata))))))

;; : (-> POOObject Boolean)
(def (poo-flow-memory-handoff-manifest? value)
  (or (poo-flow-memory-handoff-manifest-receipt? value)
      (and (object? value)
           (eq? (poo-flow-memory-slot value 'kind #f)
                +poo-flow-ai-agentic-context-memory-handoff-manifest-kind+))))

;;; Boundary: handoff manifest serialization is the bounded ABI between memory
;;; policy objects and Marlin/runtime transfer.
;; : (-> PooMemoryHandoffManifest Alist)
(def (poo-flow-memory-handoff-manifest->alist manifest)
  (let (checked-manifest
        (poo-flow-session-require
         "memory handoff projection requires a memory handoff manifest"
         (poo-flow-memory-handoff-manifest? manifest)
         manifest))
    (if (poo-flow-memory-handoff-manifest-receipt? checked-manifest)
      (list
       (cons 'kind
             (poo-flow-memory-handoff-manifest-receipt-kind checked-manifest))
       (cons 'schema
             (poo-flow-memory-handoff-manifest-receipt-schema checked-manifest))
       (cons 'request-id
             (poo-flow-memory-handoff-manifest-receipt-request-id checked-manifest))
       (cons 'store-ref
             (poo-flow-memory-handoff-manifest-receipt-store-ref checked-manifest))
       (cons 'store-kind
             (poo-flow-memory-handoff-manifest-receipt-store-kind checked-manifest))
       (cons 'namespace
             (poo-flow-memory-handoff-manifest-receipt-namespace checked-manifest))
       (cons 'scopes
             (poo-flow-memory-handoff-manifest-receipt-scopes checked-manifest))
       (cons 'recall-policies
             (poo-flow-memory-handoff-manifest-receipt-recall-policies checked-manifest))
       (cons 'commit-policies
             (poo-flow-memory-handoff-manifest-receipt-commit-policies checked-manifest))
       (cons 'operation
             (poo-flow-memory-handoff-manifest-receipt-operation checked-manifest))
       (cons 'runtime-owner
             (poo-flow-memory-handoff-manifest-receipt-runtime-owner checked-manifest))
       (cons 'runtime-backend
             (poo-flow-memory-handoff-manifest-receipt-runtime-backend checked-manifest))
       (cons 'durable?
             (poo-flow-memory-handoff-manifest-receipt-durable? checked-manifest))
       (cons 'handoff-ready?
             (poo-flow-memory-handoff-manifest-receipt-handoff-ready? checked-manifest))
       (cons 'diagnostic-count
             (poo-flow-memory-handoff-manifest-receipt-diagnostic-count checked-manifest))
       (cons 'diagnostics
             (poo-flow-memory-handoff-manifest-receipt-diagnostics checked-manifest))
       (cons 'runtime-executed
             (poo-flow-memory-handoff-manifest-receipt-runtime-executed checked-manifest))
       (cons 'metadata
             (poo-flow-memory-handoff-manifest-receipt-metadata checked-manifest)))
      (list
       (cons 'kind (.ref checked-manifest 'kind))
       (cons 'schema (.ref checked-manifest 'schema))
       (cons 'request-id (.ref checked-manifest 'request-id))
       (cons 'store-ref (.ref checked-manifest 'store-ref))
       (cons 'store-kind (.ref checked-manifest 'store-kind))
       (cons 'namespace (.ref checked-manifest 'namespace))
       (cons 'scopes (.ref checked-manifest 'scopes))
       (cons 'recall-policies (.ref checked-manifest 'recall-policies))
       (cons 'commit-policies (.ref checked-manifest 'commit-policies))
       (cons 'operation (.ref checked-manifest 'operation))
       (cons 'runtime-owner (.ref checked-manifest 'runtime-owner))
       (cons 'runtime-backend (.ref checked-manifest 'runtime-backend))
       (cons 'durable? (.ref checked-manifest 'durable?))
       (cons 'handoff-ready? (.ref checked-manifest 'handoff-ready?))
       (cons 'diagnostic-count (.ref checked-manifest 'diagnostic-count))
       (cons 'diagnostics (.ref checked-manifest 'diagnostics))
       (cons 'runtime-executed (.ref checked-manifest 'runtime-executed))
       (cons 'metadata (.ref checked-manifest 'metadata))))))
