;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox resources prototype contract and projection helpers.
;;; Invariant: resource validation does not import full sandbox profile machinery.

(import :gerbil/core
        (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :clan/poo/mop element?)
        (only-in :yuanxu/module-system/schema/slot-contracts
                 yuanxu-contract-slot
                 yuanxu-contract-slot-name
                 yuanxu-contract-slot-type
                 yuanxu-contract-value-type
                 yuanxu-object-contract
                 yuanxu-object-contract->alist)
        :yuanxu/utilities/final-projection-syntax
        :yuanxu/type-facts/objects)

(export agentic-ai-lab-runtime-filesystem-prototype
        agentic-ai-lab-runtime-volume-filesystem-prototype
        agentic-ai-lab-snapshot-filesystem-prototype
        agentic-ai-lab-runtime-filesystem-resources-prototype
        agentic-ai-lab-runtime-volume-resources-prototype
        agentic-ai-lab-snapshot-resources-prototype
        agentic-ai-lab-runtime-volume-ports-resources-prototype
        AgenticAILabSandboxResourcesPrototypeContract
        agentic-ai-lab-sandbox-resources-prototype-type-contract->alist
        agentic-ai-lab-sandbox-resources-prototype-contract-validation
        agentic-ai-lab-sandbox-resources-prototype-contract-validation?
        agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
        agentic-ai-lab-sandbox-resources-prototype-contract-validation-diagnostics
        agentic-ai-lab-sandbox-resources-prototype-contract-validation->alist
        agentic-ai-lab-require-sandbox-resources-prototype-contract!
        agentic-ai-lab-sandbox-prototype-slot-entry
        agentic-ai-lab-sandbox-filesystem-prototype->resource-entry
        agentic-ai-lab-sandbox-filesystem-prototype->resource-policy
        agentic-ai-lab-sandbox-resources-prototype->resource-policy
        agentic-ai-lab-sandbox-resources-value->resource-policy)

(import :agentic-ai-lab/modules/sandbox-core/resource-prototypes)

;; : PooSandboxResourcesPrototypeContractValidationKind
(def agentic-ai-lab-sandbox-resources-prototype-contract-validation-kind
  "agentic-ai-lab-sandbox-resources-prototype-contract-validation")

;; : PooSandboxResourcesPrototypeContractValidationSchema
(def agentic-ai-lab-sandbox-resources-prototype-contract-validation-schema
  "agentic-ai-lab-sandbox-resources-prototype-contract-validation/v1")

(def AgenticAILabSandboxFilesystemType
  (yuanxu-contract-value-type
   'PooSandboxFilesystemPrototype object? 'PooSandboxFilesystemPrototype))
(def AgenticAILabSandboxNumberType
  (yuanxu-contract-value-type 'Number number? 'Number))
(def AgenticAILabSandboxListType
  (yuanxu-contract-value-type 'List list? 'List))
(def AgenticAILabSandboxStringType
  (yuanxu-contract-value-type 'String string? 'String))

(def AgenticAILabSandboxFilesystemSlot
  (yuanxu-contract-slot
   'sandbox.resources/filesystem 'filesystem AgenticAILabSandboxFilesystemType #t
   '((scope . sandbox-core) (slot . filesystem) (merge . node-extend))))
(def AgenticAILabSandboxCpuSlot
  (yuanxu-contract-slot
   'sandbox.resources/cpu 'cpu AgenticAILabSandboxNumberType #t
   '((scope . sandbox-core) (slot . cpu) (merge . override))))
(def AgenticAILabSandboxPortsSlot
  (yuanxu-contract-slot
   'sandbox.resources/ports 'ports AgenticAILabSandboxListType #f
   '((scope . sandbox-core) (slot . ports) (optional . #t) (merge . override))))
(def AgenticAILabSandboxMemorySlot
  (yuanxu-contract-slot
   'sandbox.resources/memory 'memory AgenticAILabSandboxStringType #t
   '((scope . sandbox-core) (slot . memory) (merge . override))))
(def AgenticAILabSandboxTimeoutSlot
  (yuanxu-contract-slot
   'sandbox.resources/timeout-ms 'timeout-ms AgenticAILabSandboxNumberType #f
   '((scope . sandbox-core) (slot . timeout-ms) (optional . #t) (merge . override))))

(def AgenticAILabSandboxResourceSlotContracts
  (list AgenticAILabSandboxFilesystemSlot
        AgenticAILabSandboxCpuSlot
        AgenticAILabSandboxPortsSlot
        AgenticAILabSandboxMemorySlot
        AgenticAILabSandboxTimeoutSlot))

(def AgenticAILabSandboxResourcesPrototypeContract
  (yuanxu-object-contract
   'sandbox/resources
   'sandbox-core
   'PooSandboxResourcesPrototype
   object?
   AgenticAILabSandboxResourceSlotContracts
   '((scope . sandbox-core) (projection . resource-contract))))

;; : (-> List List List)
(def (agentic-ai-lab-sandbox-resource-rows/tail rows tail)
  (foldr cons tail rows))

;; : (-> [List] List List)
(def (agentic-ai-lab-sandbox-resource-segments/tail segments tail)
  (if (null? segments)
    tail
    (agentic-ai-lab-sandbox-resource-rows/tail
     (car segments)
     (agentic-ai-lab-sandbox-resource-segments/tail (cdr segments) tail))))

;;; Boundary: sandbox resource spec has key predicate is the policy-visible
;;; edge for sandbox, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> AgentSandboxFilesystemResourceSpec Symbol Boolean)
(def (agentic-ai-lab-sandbox-resource-spec-has-key? spec key)
  (cond
   ((null? spec) #f)
   ((not (pair? spec)) #f)
   ((and (pair? (car spec))
         (eq? (caar spec) key))
    #t)
   (else
    (agentic-ai-lab-sandbox-resource-spec-has-key? (cdr spec) key))))

;; : (-> AgentSandboxFilesystemResourceSpec Boolean)
(def (agentic-ai-lab-sandbox-resource-spec-has-anchor? spec)
  (or (agentic-ai-lab-sandbox-resource-spec-has-key? spec 'mounts)
      (agentic-ai-lab-sandbox-resource-spec-has-key? spec 'workspace)
      (agentic-ai-lab-sandbox-resource-spec-has-key? spec 'paths)
      (agentic-ai-lab-sandbox-resource-spec-has-key? spec 'root)
      (agentic-ai-lab-sandbox-resource-spec-has-key? spec 'volume)
      (agentic-ai-lab-sandbox-resource-spec-has-key? spec 'snapshot)))

;; : (-> AgentSandboxResourcePolicyEntry Boolean)
(def (agentic-ai-lab-sandbox-structured-filesystem-entry? resource)
  (and (pair? resource)
       (eq? (car resource) 'filesystem)
       (list? (cdr resource))
       (agentic-ai-lab-sandbox-resource-spec-has-key? (cdr resource) 'scope)
       (agentic-ai-lab-sandbox-resource-spec-has-anchor? (cdr resource))))

;;; Boundary: sandbox resource policy has structured filesystem predicate is
;;; the policy-visible edge for sandbox, core behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> ResourcePolicy Boolean)
(def (agentic-ai-lab-sandbox-resource-policy-has-structured-filesystem?
      resource-policy)
  (cond
   ((null? resource-policy) #f)
   ((not (pair? resource-policy)) #f)
   ((agentic-ai-lab-sandbox-structured-filesystem-entry? (car resource-policy))
    #t)
   (else
    (agentic-ai-lab-sandbox-resource-policy-has-structured-filesystem?
     (cdr resource-policy)))))

;; : (-> Alist)
(def (agentic-ai-lab-sandbox-resources-prototype-type-contract->alist)
  (yuanxu-object-contract->alist AgenticAILabSandboxResourcesPrototypeContract))

;; : (-> Symbol String Dyn POOObject)
(def (agentic-ai-lab-sandbox-resources-prototype-diagnostic code message value)
  (let ((diagnostic-code code)
        (diagnostic-message message)
        (diagnostic-value value))
    (.o code: diagnostic-code
        message: diagnostic-message
        object: 'PooSandboxResourcesPrototype
        value: diagnostic-value)))

(def (agentic-ai-lab-sandbox-resources-prototype-diagnostic->alist diagnostic)
  (list (cons 'code (.ref diagnostic 'code))
        (cons 'message (.ref diagnostic 'message))
        (cons 'object (.ref diagnostic 'object))
        (cons 'value (.ref diagnostic 'value))))

;; : [YuanxuTypeFactContract]
(def +agentic-ai-lab-sandbox-resources-prototype-type-facts+
  (list
   (yuanxu-type-fact
    'sandbox.resources/filesystem-prototype
    'slot-contract
    'PooSandboxResourcesPrototype
    'filesystemPrototype
    'filesystem
    'PooSandboxFilesystemPrototype
    'positive
    '((scope . sandbox-core) (required . #t)))
   (yuanxu-type-fact
    'sandbox.resources/cpu-number
    'slot-contract
    'PooSandboxResourcesPrototype
    'cpuNumber
    'cpu
    'Number
    'positive
    '((scope . sandbox-core) (required . #t)))
   (yuanxu-type-fact
    'sandbox.resources/memory-string
    'slot-contract
    'PooSandboxResourcesPrototype
    'memoryString
    'memory
    'String
    'positive
    '((scope . sandbox-core) (required . #t)))
   (yuanxu-type-fact
    'sandbox.resources/ports-list
    'slot-contract
    'PooSandboxResourcesPrototype
    'portsList
    'ports
    'List
    'optional
    '((scope . sandbox-core) (required . #f)))
   (yuanxu-type-fact
    'sandbox.resources/timeout-number
    'slot-contract
    'PooSandboxResourcesPrototype
    'timeoutNumber
    'timeout-ms
    'Number
    'optional
    '((scope . sandbox-core) (required . #f)))))

;; : [YuanxuLeanFactContract]
(def +agentic-ai-lab-sandbox-resources-prototype-lean-fact-contracts+
  (list
   (yuanxu-lean-fact
    'sandbox.resources/filesystem-structured
    'fact
    'SandboxResources.SandboxResourceFact
    'filesystemStructured
    'filesystem
    'positive
    '((scope . sandbox-core)))
   (yuanxu-lean-fact
    'sandbox.resources/cpu-present
    'fact
    'SandboxResources.SandboxResourceFact
    'cpuPresent
    'cpu
    'positive
    '((scope . sandbox-core)))
   (yuanxu-lean-fact
    'sandbox.resources/memory-present
    'fact
    'SandboxResources.SandboxResourceFact
    'memoryPresent
    'memory
    'positive
    '((scope . sandbox-core)))
   (yuanxu-lean-fact
    'sandbox.resources/runtime-executed-false
    'fact
    'SandboxResources.SandboxResourceFact
    'runtimeExecutedFalse
    'runtime-executed
    'negative
    '((scope . sandbox-core)))))

;;; Boundary: sandbox resources prototype slot readable predicate is the
;;; policy-visible edge for sandbox, core behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype Symbol Boolean)
(def (agentic-ai-lab-sandbox-resources-prototype-slot-readable? resources slot)
  (and (object? resources)
       (.slot? resources slot)
       (with-catch
        (lambda (_failure) #f)
        (lambda ()
          (.ref resources slot)
          #t))))

;;; Boundary: sandbox resources prototype slot readability diagnostics is the
;;; policy-visible edge for sandbox, core behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> Symbol Symbol PooSandboxResourcesPrototype [POOObject])
(def (agentic-ai-lab-sandbox-resources-prototype-slot-readability-diagnostics code
                                                                        slot
                                                                        resources)
  (if (or (not (object? resources))
          (not (.slot? resources slot))
          (agentic-ai-lab-sandbox-resources-prototype-slot-readable? resources slot))
    '()
    (list
     (agentic-ai-lab-sandbox-resources-prototype-diagnostic
      code
      "sandbox resources prototype slot exists but cannot be read through POO slot resolution"
      resources))))

;; : (-> PooSandboxResourcesPrototype YuanxuSlotContract [POOObject])
(def (agentic-ai-lab-sandbox-resources-prototype-slot-contract-diagnostics
      resources
      contract)
  (let (slot (yuanxu-contract-slot-name contract))
    (if (and (object? resources)
             (.slot? resources slot)
             (agentic-ai-lab-sandbox-resources-prototype-slot-readable? resources slot))
      (with-catch
       (lambda (_failure)
         (list
          (agentic-ai-lab-sandbox-resources-prototype-diagnostic
           'slot-contract-failed
           "sandbox resources prototype slot failed structured contract"
           (list (cons 'slot slot)))))
       (lambda ()
         (let (slot-value (.ref resources slot))
           (if (element? (yuanxu-contract-slot-type contract) slot-value)
             '()
             (list
              (agentic-ai-lab-sandbox-resources-prototype-diagnostic
               'slot-contract-failed
               "sandbox resources prototype slot failed structured contract"
               (list (cons 'slot slot)
                     (cons 'value slot-value))))))))
      '())))

;; : (-> PooSandboxResourcesPrototype [POOObject])
(def (agentic-ai-lab-sandbox-resources-prototype-slot-contracts-diagnostics
      resources)
  (agentic-ai-lab-sandbox-resource-segments/tail
   (map
    (lambda (contract)
      (agentic-ai-lab-sandbox-resources-prototype-slot-contract-diagnostics
       resources
       contract))
    AgenticAILabSandboxResourceSlotContracts)
   '()))

;;; Boundary: sandbox resources prototype missing slot diagnostics is the
;;; policy-visible edge for sandbox, core behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype [POOObject])
(def (agentic-ai-lab-sandbox-resources-prototype-missing-slot-diagnostics resources
                                                                    slot
                                                                    code
                                                                    message)
  (if (.slot? resources slot)
    '()
    (list
     (agentic-ai-lab-sandbox-resources-prototype-diagnostic
      code
      message
      resources))))

;;; Boundary: sandbox prototype slot entry is the policy-visible edge for
;;; sandbox, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Object Symbol [Pair])
(def (agentic-ai-lab-sandbox-prototype-slot-entry prototype slot)
  (if (.slot? prototype slot)
    (list (cons slot (.ref prototype slot)))
    '()))

;; : (-> PooSandboxFilesystemPrototype AgentSandboxResourcePolicyEntry)
(def (agentic-ai-lab-sandbox-filesystem-prototype->resource-entry filesystem)
  (cons 'filesystem
        (agentic-ai-lab-sandbox-resource-segments/tail
         (list
          (agentic-ai-lab-sandbox-prototype-slot-entry filesystem 'scope)
          (agentic-ai-lab-sandbox-prototype-slot-entry filesystem 'materialized-by)
          (agentic-ai-lab-sandbox-prototype-slot-entry filesystem 'paths)
          (agentic-ai-lab-sandbox-prototype-slot-entry filesystem 'mounts)
          (agentic-ai-lab-sandbox-prototype-slot-entry filesystem 'access)
          (agentic-ai-lab-sandbox-prototype-slot-entry filesystem 'snapshot))
         (agentic-ai-lab-sandbox-prototype-slot-entry filesystem 'volume))))

;; : (-> PooSandboxFilesystemPrototype ResourcePolicy)
(def (agentic-ai-lab-sandbox-filesystem-prototype->resource-policy filesystem)
  (list (agentic-ai-lab-sandbox-filesystem-prototype->resource-entry filesystem)))

;;; Boundary: sandbox resources prototype to resource policy is the policy-
;;; visible edge for sandbox, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype ResourcePolicy)
(def (agentic-ai-lab-sandbox-resources-prototype->resource-policy resources)
  (agentic-ai-lab-sandbox-resource-segments/tail
   (list
    (if (.slot? resources 'filesystem)
      (list
       (agentic-ai-lab-sandbox-filesystem-prototype->resource-entry
        (.ref resources 'filesystem)))
      '())
    (agentic-ai-lab-sandbox-prototype-slot-entry resources 'mounts)
    (agentic-ai-lab-sandbox-prototype-slot-entry resources 'ports)
    (agentic-ai-lab-sandbox-prototype-slot-entry resources 'cpu)
    (agentic-ai-lab-sandbox-prototype-slot-entry resources 'memory))
   (agentic-ai-lab-sandbox-prototype-slot-entry resources 'timeout-ms)))

;;; Boundary: sandbox resources prototype structured filesystem diagnostics is
;;; the policy-visible edge for sandbox, core behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype [POOObject])
(def (agentic-ai-lab-sandbox-resources-prototype-structured-filesystem-diagnostics
      resources)
  (if (not (agentic-ai-lab-sandbox-resources-prototype-slot-readable?
            resources
            'filesystem))
    '()
    (with-catch
     (lambda (_failure)
       (list
        (agentic-ai-lab-sandbox-resources-prototype-diagnostic
         'filesystem-not-structured
         "sandbox resources filesystem cannot project to a structured resource-policy entry"
         resources)))
     (lambda ()
       (let (resource-policy
             (agentic-ai-lab-sandbox-filesystem-prototype->resource-policy
              (.ref resources 'filesystem)))
         (if (agentic-ai-lab-sandbox-resource-policy-has-structured-filesystem?
              resource-policy)
           '()
           (list
            (agentic-ai-lab-sandbox-resources-prototype-diagnostic
             'filesystem-not-structured
             "sandbox resources filesystem must project to a structured resource-policy entry"
             resource-policy))))))))

;;; Boundary: sandbox resources prototype local diagnostics is the policy-
;;; visible edge for sandbox, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype [POOObject])
(def (agentic-ai-lab-sandbox-resources-prototype-local-diagnostics resources)
  (if (not (object? resources))
    (list
     (agentic-ai-lab-sandbox-resources-prototype-diagnostic
      'resources-prototype-not-object
      "sandbox resources contract expects a POO object"
      resources))
    (agentic-ai-lab-sandbox-resource-segments/tail
     (list
      (agentic-ai-lab-sandbox-resources-prototype-missing-slot-diagnostics
       resources
       'filesystem
       'missing-filesystem-slot
       "sandbox resources prototype must define filesystem")
      (agentic-ai-lab-sandbox-resources-prototype-missing-slot-diagnostics
       resources
       'cpu
       'missing-cpu-slot
       "sandbox resources prototype must define cpu")
      (agentic-ai-lab-sandbox-resources-prototype-missing-slot-diagnostics
       resources
       'memory
       'missing-memory-slot
       "sandbox resources prototype must define memory")
      (agentic-ai-lab-sandbox-resources-prototype-slot-readability-diagnostics
       'unreadable-filesystem-slot
       'filesystem
       resources)
      (agentic-ai-lab-sandbox-resources-prototype-slot-readability-diagnostics
       'unreadable-cpu-slot
       'cpu
       resources)
      (agentic-ai-lab-sandbox-resources-prototype-slot-readability-diagnostics
       'unreadable-memory-slot
       'memory
       resources)
      (agentic-ai-lab-sandbox-resources-prototype-slot-readability-diagnostics
       'unreadable-ports-slot
       'ports
       resources)
      (agentic-ai-lab-sandbox-resources-prototype-slot-readability-diagnostics
       'unreadable-timeout-slot
       'timeout-ms
       resources)
      (agentic-ai-lab-sandbox-resources-prototype-slot-contracts-diagnostics
       resources))
     (agentic-ai-lab-sandbox-resources-prototype-structured-filesystem-diagnostics
      resources))))

;; : (-> PooSandboxResourcesPrototype POOObject)
(def (agentic-ai-lab-sandbox-resources-prototype-contract-validation resources)
  (let* ((local-diagnostics
          (agentic-ai-lab-sandbox-resources-prototype-local-diagnostics resources))
         (native-valid? (null? local-diagnostics)))
    (.o kind: agentic-ai-lab-sandbox-resources-prototype-contract-validation-kind
        schema: agentic-ai-lab-sandbox-resources-prototype-contract-validation-schema
        object: 'PooSandboxResourcesPrototype
        valid: native-valid?
        diagnostics: local-diagnostics
        checked-signals:
        '(native-poo-object-shape native-poo-required-slots
          native-poo-slot-types structured-filesystem-projection
          structured-type-facts lean-fact-contracts)
        type-facts: +agentic-ai-lab-sandbox-resources-prototype-type-facts+
        lean-fact-contracts:
        +agentic-ai-lab-sandbox-resources-prototype-lean-fact-contracts+
        runtime-executed: #f)))

(def (agentic-ai-lab-sandbox-resources-prototype-contract-validation? validation)
  (and (object? validation)
       (andmap
        (lambda (slot)
          (agentic-ai-lab-sandbox-resources-prototype-slot-readable?
           validation slot))
        '(kind schema object valid diagnostics checked-signals
          type-facts lean-fact-contracts runtime-executed))
       (equal? (.ref validation 'kind)
               agentic-ai-lab-sandbox-resources-prototype-contract-validation-kind)
       (equal? (.ref validation 'schema)
               agentic-ai-lab-sandbox-resources-prototype-contract-validation-schema)))

;; : (-> POOObject Boolean)
(def (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
      validation)
  (and (agentic-ai-lab-sandbox-resources-prototype-contract-validation? validation)
       (.ref validation 'valid)))

;; : (-> POOObject [POOObject])
(def (agentic-ai-lab-sandbox-resources-prototype-contract-validation-diagnostics
      validation)
  (.ref validation 'diagnostics))

;; : (-> POOObject Alist)
(defpoo-final-projection
  agentic-ai-lab-sandbox-resources-prototype-contract-validation->alist
  (validation)
  (bindings ((diagnostic-objects (.ref validation 'diagnostics))))
  (fields ((kind (.ref validation 'kind))
           (schema (.ref validation 'schema))
           (object (.ref validation 'object))
           (valid (.ref validation 'valid))
           (diagnostics
            (map agentic-ai-lab-sandbox-resources-prototype-diagnostic->alist
                 diagnostic-objects))
           (diagnostic-count (length diagnostic-objects))
           (checked-signals (.ref validation 'checked-signals))
           (type-facts
            (map yuanxu-type-fact-contract->alist
                 (.ref validation 'type-facts)))
           (lean-fact-contracts
            (map yuanxu-lean-fact-contract->alist
                 (.ref validation 'lean-fact-contracts)))
           (runtime-executed (.ref validation 'runtime-executed)))))

;;; Boundary: require sandbox resources prototype contract! is the policy-
;;; visible edge for sandbox, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype PooSandboxResourcesPrototype)
(def (agentic-ai-lab-require-sandbox-resources-prototype-contract! resources)
  (let (validation
        (agentic-ai-lab-sandbox-resources-prototype-contract-validation resources))
    (if (agentic-ai-lab-sandbox-resources-prototype-contract-validation-valid?
         validation)
      resources
      (error "sandbox resources prototype failed typed contract validation"
             validation))))

;;; Boundary: sandbox resources value to resource policy is the policy-visible
;;; edge for sandbox, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Value ResourcePolicy)
(def (agentic-ai-lab-sandbox-resources-value->resource-policy resources)
  (if (object? resources)
    (agentic-ai-lab-sandbox-resources-prototype->resource-policy
     (agentic-ai-lab-require-sandbox-resources-prototype-contract! resources))
    resources))
