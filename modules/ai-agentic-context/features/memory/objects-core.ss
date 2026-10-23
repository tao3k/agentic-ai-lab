;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: memory store spec primitives shared by memory-core modules.

(import (only-in :clan/poo/object .o .ref object? object<-alist)
        :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/transform)

(export agentic-ai-lab-memory-field-rows
        agentic-ai-lab-memory-runtime-object
        +agentic-ai-lab-ai-agentic-context-memory-store-spec-kind+
        +agentic-ai-lab-ai-agentic-context-memory-catalog-kind+
        +agentic-ai-lab-ai-agentic-context-memory-handoff-manifest-kind+
        +agentic-ai-lab-ai-agentic-context-memory-policy-validation-receipt-kind+
        +agentic-ai-lab-ai-agentic-context-memory-durable-job-receipt-kind+
        +agentic-ai-lab-memory-durable-job-kinds+
        +agentic-ai-lab-memory-durable-job-states+
        agentic-ai-lab-memory-slot
        agentic-ai-lab-memory-option
        agentic-ai-lab-memory-symbol-list?
        agentic-ai-lab-memory-alist?
        agentic-ai-lab-memory-store-spec
        agentic-ai-lab-memory-store-spec?
        agentic-ai-lab-memory-store-spec-ref
        agentic-ai-lab-memory-store-spec-scopes
        agentic-ai-lab-memory-store-spec-commit-policies
        agentic-ai-lab-memory-store-spec-recall-policies
        agentic-ai-lab-memory-store-spec->alist
        agentic-ai-lab-memory-reverse-onto)

;; agentic-ai-lab-memory-field-rows
;;   : (-> FieldRow... Alist)
;;   | doc m%
;;       `agentic-ai-lab-memory-field-rows` constructs ordered memory object fields.
;;
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-memory-field-rows (kind memory) (schema memory.v1))
;;       ;; => ((kind . memory) (schema . memory.v1))
;;       ```
;;     %
(defrules agentic-ai-lab-memory-field-rows ()
  ((_ (field value) ...)
   (list (cons 'field value) ...)))
(def (agentic-ai-lab-memory-runtime-object fields)
  (object<-alist fields))

;; : Symbol
(def +agentic-ai-lab-ai-agentic-context-memory-store-spec-kind+
  'agentic-ai-lab.memory-core.store-spec)

;; : Symbol
(def +agentic-ai-lab-ai-agentic-context-memory-catalog-kind+
  'agentic-ai-lab.memory-core.catalog)

;; : Symbol
(def +agentic-ai-lab-ai-agentic-context-memory-handoff-manifest-kind+
  'agentic-ai-lab.memory-core.handoff-manifest)

;; : Symbol
(def +agentic-ai-lab-ai-agentic-context-memory-policy-validation-receipt-kind+
  'agentic-ai-lab.memory-core.policy-catalog-validation-receipt)

;; : Symbol
(def +agentic-ai-lab-ai-agentic-context-memory-durable-job-receipt-kind+
  'agentic-ai-lab.memory-core.durable-job-receipt)

;; : [Symbol]
(def +agentic-ai-lab-memory-durable-job-kinds+
  '(recall write consolidation stale-source repair))

;; : [Symbol]
(def +agentic-ai-lab-memory-durable-job-states+
  '(planned claimable claimed completed failed stale repair-required))

;; : (-> POOObject Symbol Object Object)
(def (agentic-ai-lab-memory-slot object key default-value)
  (with-catch
   (lambda (_failure) default-value)
   (lambda ()
     (.ref object key))))

;; : (-> Alist Symbol Object Object)
(def (agentic-ai-lab-memory-option options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-memory-symbol-list? values)
  (and (list? values)
       (agentic-ai-lab-session-every? symbol? values)))

;; : (-> Object Boolean)
(def (agentic-ai-lab-memory-alist? value)
  (list? value))

;; : (-> Symbol Symbol Symbol [Symbol] [Symbol] [Symbol] String Symbol Boolean Symbol [Alist] PooMemoryStoreSpec)
(def (agentic-ai-lab-memory-store-spec store-ref
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
  (agentic-ai-lab-session-require "memory store ref must be a symbol"
                            (symbol? store-ref)
                            store-ref)
  (agentic-ai-lab-session-require "memory store kind must be a symbol"
                            (symbol? store-kind)
                            store-kind)
  (agentic-ai-lab-session-require "memory namespace must be a symbol"
                            (symbol? namespace)
                            namespace)
  (agentic-ai-lab-session-require "memory scopes must be symbols"
                            (agentic-ai-lab-memory-symbol-list? scopes)
                            scopes)
  (agentic-ai-lab-session-require "memory recall policies must be symbols"
                            (agentic-ai-lab-memory-symbol-list? recall-policies)
                            recall-policies)
  (agentic-ai-lab-session-require "memory commit policies must be symbols"
                            (agentic-ai-lab-memory-symbol-list? commit-policies)
                            commit-policies)
  (agentic-ai-lab-session-require "memory runtime owner must be a string"
                            (string? runtime-owner)
                            runtime-owner)
  (agentic-ai-lab-session-require "memory handoff operation must be a symbol"
                            (symbol? handoff-operation)
                            handoff-operation)
  (agentic-ai-lab-session-require "memory durable? must be boolean"
                            (boolean? durable?)
                            durable?)
  (agentic-ai-lab-session-require "memory runtime backend must be a symbol"
                            (symbol? runtime-backend)
                            runtime-backend)
  (object<-alist
   (list
    (cons 'kind +agentic-ai-lab-ai-agentic-context-memory-store-spec-kind+)
    (cons 'schema 'agentic-ai-lab.modules.memory-core.store-spec.v1)
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
(def (agentic-ai-lab-memory-store-spec? value)
  (and (object? value)
       (eq? (agentic-ai-lab-memory-slot value 'kind #f)
            +agentic-ai-lab-ai-agentic-context-memory-store-spec-kind+)))

;; : (-> PooMemoryStoreSpec Symbol)
(def (agentic-ai-lab-memory-store-spec-ref spec)
  (.ref spec 'store-ref))

;; : (-> PooMemoryStoreSpec [Symbol])
(def (agentic-ai-lab-memory-store-spec-scopes spec)
  (.ref spec 'scopes))

;; : (-> PooMemoryStoreSpec [Symbol])
(def (agentic-ai-lab-memory-store-spec-commit-policies spec)
  (.ref spec 'commit-policies))

;; : (-> PooMemoryStoreSpec [Symbol])
(def (agentic-ai-lab-memory-store-spec-recall-policies spec)
  (.ref spec 'recall-policies))

;; : (-> PooMemoryStoreSpec Alist)
(defpoo-final-projection
  agentic-ai-lab-memory-store-spec->alist (spec)
  (bindings ((checked-spec
              (agentic-ai-lab-session-require
               "memory store projection requires a memory store spec"
               (agentic-ai-lab-memory-store-spec? spec)
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
  agentic-ai-lab-memory-store-specs->alists (specs)
  (projector agentic-ai-lab-memory-store-spec->alist)
  (error-message "memory store serialization requires a list"))
(def (agentic-ai-lab-memory-reverse-onto values tail)
  (if (null? values)
    tail
    (agentic-ai-lab-memory-reverse-onto
     (cdr values)
     (cons (car values) tail))))
