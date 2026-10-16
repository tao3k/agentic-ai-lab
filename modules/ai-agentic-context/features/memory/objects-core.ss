;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: memory store spec primitives shared by memory-core modules.

(import (only-in :clan/poo/object .o .ref object? object<-alist)
        :core/utilities/final-projection-syntax
        :poo-flow/modules/session/objects
        :poo-flow/modules/session/transform)

(export poo-flow-memory-field-rows
        poo-flow-memory-runtime-object
        +poo-flow-ai-agentic-context-memory-store-spec-kind+
        +poo-flow-ai-agentic-context-memory-catalog-kind+
        +poo-flow-ai-agentic-context-memory-handoff-manifest-kind+
        +poo-flow-ai-agentic-context-memory-policy-validation-receipt-kind+
        +poo-flow-ai-agentic-context-memory-durable-job-receipt-kind+
        +poo-flow-memory-durable-job-kinds+
        +poo-flow-memory-durable-job-states+
        poo-flow-memory-slot
        poo-flow-memory-option
        poo-flow-memory-symbol-list?
        poo-flow-memory-alist?
        poo-flow-memory-store-spec
        poo-flow-memory-store-spec?
        poo-flow-memory-store-spec-ref
        poo-flow-memory-store-spec-scopes
        poo-flow-memory-store-spec-commit-policies
        poo-flow-memory-store-spec-recall-policies
        poo-flow-memory-store-spec->alist
        poo-flow-memory-reverse-onto)

;; poo-flow-memory-field-rows
;;   : (-> FieldRow... Alist)
;;   | doc m%
;;       `poo-flow-memory-field-rows` constructs ordered memory object fields.
;;
;;       # Examples
;;
;;       ```scheme
;;       (poo-flow-memory-field-rows (kind memory) (schema memory.v1))
;;       ;; => ((kind . memory) (schema . memory.v1))
;;       ```
;;     %
(defrules poo-flow-memory-field-rows ()
  ((_ (field value) ...)
   (list (cons 'field value) ...)))
(def (poo-flow-memory-runtime-object fields)
  (object<-alist fields))

;; : Symbol
(def +poo-flow-ai-agentic-context-memory-store-spec-kind+
  'poo-flow.memory-core.store-spec)

;; : Symbol
(def +poo-flow-ai-agentic-context-memory-catalog-kind+
  'poo-flow.memory-core.catalog)

;; : Symbol
(def +poo-flow-ai-agentic-context-memory-handoff-manifest-kind+
  'poo-flow.memory-core.handoff-manifest)

;; : Symbol
(def +poo-flow-ai-agentic-context-memory-policy-validation-receipt-kind+
  'poo-flow.memory-core.policy-catalog-validation-receipt)

;; : Symbol
(def +poo-flow-ai-agentic-context-memory-durable-job-receipt-kind+
  'poo-flow.memory-core.durable-job-receipt)

;; : [Symbol]
(def +poo-flow-memory-durable-job-kinds+
  '(recall write consolidation stale-source repair))

;; : [Symbol]
(def +poo-flow-memory-durable-job-states+
  '(planned claimable claimed completed failed stale repair-required))

;; : (-> POOObject Symbol Object Object)
(def (poo-flow-memory-slot object key default-value)
  (with-catch
   (lambda (_failure) default-value)
   (lambda ()
     (.ref object key))))

;; : (-> Alist Symbol Object Object)
(def (poo-flow-memory-option options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; : (-> Object Boolean)
(def (poo-flow-memory-symbol-list? values)
  (and (list? values)
       (poo-flow-session-every? symbol? values)))

;; : (-> Object Boolean)
(def (poo-flow-memory-alist? value)
  (list? value))

;; : (-> Symbol Symbol Symbol [Symbol] [Symbol] [Symbol] String Symbol Boolean Symbol [Alist] PooMemoryStoreSpec)
(def (poo-flow-memory-store-spec store-ref
                                 store-kind
                                 namespace
                                 scopes
                                 recall-policies
                                 commit-policies
                                 runtime-owner
                                 handoff-operation
                                 durable?
                                 runtime-backend
                                 . maybe-metadata)
  (poo-flow-session-require "memory store ref must be a symbol"
                            (symbol? store-ref)
                            store-ref)
  (poo-flow-session-require "memory store kind must be a symbol"
                            (symbol? store-kind)
                            store-kind)
  (poo-flow-session-require "memory namespace must be a symbol"
                            (symbol? namespace)
                            namespace)
  (poo-flow-session-require "memory scopes must be symbols"
                            (poo-flow-memory-symbol-list? scopes)
                            scopes)
  (poo-flow-session-require "memory recall policies must be symbols"
                            (poo-flow-memory-symbol-list? recall-policies)
                            recall-policies)
  (poo-flow-session-require "memory commit policies must be symbols"
                            (poo-flow-memory-symbol-list? commit-policies)
                            commit-policies)
  (poo-flow-session-require "memory runtime owner must be a string"
                            (string? runtime-owner)
                            runtime-owner)
  (poo-flow-session-require "memory handoff operation must be a symbol"
                            (symbol? handoff-operation)
                            handoff-operation)
  (poo-flow-session-require "memory durable? must be boolean"
                            (boolean? durable?)
                            durable?)
  (poo-flow-session-require "memory runtime backend must be a symbol"
                            (symbol? runtime-backend)
                            runtime-backend)
  (object<-alist
   (list
    (cons 'kind +poo-flow-ai-agentic-context-memory-store-spec-kind+)
    (cons 'schema 'poo-flow.modules.memory-core.store-spec.v1)
    (cons 'store-ref store-ref)
    (cons 'store-kind store-kind)
    (cons 'namespace namespace)
    (cons 'scopes scopes)
    (cons 'recall-policies recall-policies)
    (cons 'commit-policies commit-policies)
    (cons 'runtime-owner runtime-owner)
    (cons 'handoff-operation handoff-operation)
    (cons 'durable? durable?)
    (cons 'runtime-backend runtime-backend)
    (cons 'runtime-executed #f)
    (cons 'metadata (if (null? maybe-metadata)
                      '()
                      (car maybe-metadata))))))

;; : (-> POOObject Boolean)
(def (poo-flow-memory-store-spec? value)
  (and (object? value)
       (eq? (poo-flow-memory-slot value 'kind #f)
            +poo-flow-ai-agentic-context-memory-store-spec-kind+)))

;; : (-> PooMemoryStoreSpec Symbol)
(def (poo-flow-memory-store-spec-ref spec)
  (.ref spec 'store-ref))

;; : (-> PooMemoryStoreSpec [Symbol])
(def (poo-flow-memory-store-spec-scopes spec)
  (.ref spec 'scopes))

;; : (-> PooMemoryStoreSpec [Symbol])
(def (poo-flow-memory-store-spec-commit-policies spec)
  (.ref spec 'commit-policies))

;; : (-> PooMemoryStoreSpec [Symbol])
(def (poo-flow-memory-store-spec-recall-policies spec)
  (.ref spec 'recall-policies))

;; : (-> PooMemoryStoreSpec Alist)
(defpoo-final-projection
  poo-flow-memory-store-spec->alist (spec)
  (bindings ((checked-spec
              (poo-flow-session-require
               "memory store projection requires a memory store spec"
               (poo-flow-memory-store-spec? spec)
               spec))))
  (fields ((kind (.ref checked-spec 'kind))
           (schema (.ref checked-spec 'schema))
           (store-ref (.ref checked-spec 'store-ref))
           (store-kind (.ref checked-spec 'store-kind))
           (namespace (.ref checked-spec 'namespace))
           (scopes (.ref checked-spec 'scopes))
           (recall-policies (.ref checked-spec 'recall-policies))
           (commit-policies (.ref checked-spec 'commit-policies))
           (runtime-owner (.ref checked-spec 'runtime-owner))
           (handoff-operation (.ref checked-spec 'handoff-operation))
           (durable? (.ref checked-spec 'durable?))
           (runtime-backend (.ref checked-spec 'runtime-backend))
           (runtime-executed (.ref checked-spec 'runtime-executed))
           (metadata (.ref checked-spec 'metadata)))))

;; : (-> [PooMemoryStoreSpec] [Alist])
(defpoo-final-projection-batch
  poo-flow-memory-store-specs->alists (specs)
  (projector poo-flow-memory-store-spec->alist)
  (error-message "memory store serialization requires a list"))
(def (poo-flow-memory-reverse-onto values tail)
  (if (null? values)
    tail
    (poo-flow-memory-reverse-onto
     (cdr values)
     (cons (car values) tail))))
