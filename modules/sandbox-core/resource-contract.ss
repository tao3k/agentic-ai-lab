;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox resources prototype contract and projection helpers.
;;; Invariant: resource validation does not import full sandbox profile machinery.

(import :gerbil/core
        (only-in :clan/poo/object .def .o .ref .slot? object?)
        (only-in :clan/poo/mop element?)
        (only-in :core/module-system/schema/slot-contracts
                 poo-flow-contract-slot
                 poo-flow-contract-slot-name
                 poo-flow-contract-slot-type
                 poo-flow-contract-value-type
                 poo-flow-native-contract
                 poo-flow-native-contract->alist)
        :core/utilities/final-projection-syntax
        :core/type-facts/objects)

(export poo-flow-runtime-filesystem-prototype
        poo-flow-runtime-volume-filesystem-prototype
        poo-flow-snapshot-filesystem-prototype
        poo-flow-runtime-filesystem-resources-prototype
        poo-flow-runtime-volume-resources-prototype
        poo-flow-snapshot-resources-prototype
        poo-flow-runtime-volume-ports-resources-prototype
        PooFlowSandboxResourcesPrototypeContract
        poo-flow-sandbox-resources-prototype-type-contract->alist
        poo-flow-sandbox-resources-prototype-contract-validation
        poo-flow-sandbox-resources-prototype-contract-validation?
        poo-flow-sandbox-resources-prototype-contract-validation-valid?
        poo-flow-sandbox-resources-prototype-contract-validation-diagnostics
        poo-flow-sandbox-resources-prototype-contract-validation->alist
        poo-flow-require-sandbox-resources-prototype-contract!
        poo-flow-sandbox-prototype-slot-entry
        poo-flow-sandbox-filesystem-prototype->resource-entry
        poo-flow-sandbox-filesystem-prototype->resource-policy
        poo-flow-sandbox-resources-prototype->resource-policy
        poo-flow-sandbox-resources-value->resource-policy)

(import :poo-flow/modules/sandbox-core/resource-prototypes)

;; : PooSandboxResourcesPrototypeContractValidationKind
(def poo-flow-sandbox-resources-prototype-contract-validation-kind
  "poo-flow-sandbox-resources-prototype-contract-validation")

;; : PooSandboxResourcesPrototypeContractValidationSchema
(def poo-flow-sandbox-resources-prototype-contract-validation-schema
  "poo-flow-sandbox-resources-prototype-contract-validation/v1")

(def PooFlowSandboxFilesystemType
  (poo-flow-contract-value-type
   'PooSandboxFilesystemPrototype object? 'PooSandboxFilesystemPrototype))
(def PooFlowSandboxNumberType
  (poo-flow-contract-value-type 'Number number? 'Number))
(def PooFlowSandboxListType
  (poo-flow-contract-value-type 'List list? 'List))
(def PooFlowSandboxStringType
  (poo-flow-contract-value-type 'String string? 'String))

(def PooFlowSandboxFilesystemSlot
  (poo-flow-contract-slot
   'sandbox.resources/filesystem 'filesystem PooFlowSandboxFilesystemType #t
   '((scope . sandbox-core) (slot . filesystem) (merge . node-extend))))
(def PooFlowSandboxCpuSlot
  (poo-flow-contract-slot
   'sandbox.resources/cpu 'cpu PooFlowSandboxNumberType #t
   '((scope . sandbox-core) (slot . cpu) (merge . override))))
(def PooFlowSandboxPortsSlot
  (poo-flow-contract-slot
   'sandbox.resources/ports 'ports PooFlowSandboxListType #f
   '((scope . sandbox-core) (slot . ports) (optional . #t) (merge . override))))
(def PooFlowSandboxMemorySlot
  (poo-flow-contract-slot
   'sandbox.resources/memory 'memory PooFlowSandboxStringType #t
   '((scope . sandbox-core) (slot . memory) (merge . override))))
(def PooFlowSandboxTimeoutSlot
  (poo-flow-contract-slot
   'sandbox.resources/timeout-ms 'timeout-ms PooFlowSandboxNumberType #f
   '((scope . sandbox-core) (slot . timeout-ms) (optional . #t) (merge . override))))

(def PooFlowSandboxResourceSlotContracts
  (list PooFlowSandboxFilesystemSlot
        PooFlowSandboxCpuSlot
        PooFlowSandboxPortsSlot
        PooFlowSandboxMemorySlot
        PooFlowSandboxTimeoutSlot))

(def PooFlowSandboxResourcesPrototypeContract
  (poo-flow-native-contract
   'sandbox/resources
   'sandbox-core
   'PooSandboxResourcesPrototype
   object?
   PooFlowSandboxResourceSlotContracts
   (lambda (resources slot) (and (object? resources) (.slot? resources slot)))
   (lambda (resources slot) (.ref resources slot))
   '((scope . sandbox-core) (projection . resource-contract))))

;; : (-> List List List)
(def (poo-flow-sandbox-resource-rows/tail rows tail)
  (foldr cons tail rows))

;; : (-> [List] List List)
(def (poo-flow-sandbox-resource-segments/tail segments tail)
  (if (null? segments)
    tail
    (poo-flow-sandbox-resource-rows/tail
     (car segments)
     (poo-flow-sandbox-resource-segments/tail (cdr segments) tail))))

;;; Boundary: sandbox resource spec has key predicate is the policy-visible
;;; edge for sandbox, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> AgentSandboxFilesystemResourceSpec Symbol Boolean)
(def (poo-flow-sandbox-resource-spec-has-key? spec key)
  (cond
   ((null? spec) #f)
   ((not (pair? spec)) #f)
   ((and (pair? (car spec))
         (eq? (caar spec) key))
    #t)
   (else
    (poo-flow-sandbox-resource-spec-has-key? (cdr spec) key))))

;; : (-> AgentSandboxFilesystemResourceSpec Boolean)
(def (poo-flow-sandbox-resource-spec-has-anchor? spec)
  (or (poo-flow-sandbox-resource-spec-has-key? spec 'mounts)
      (poo-flow-sandbox-resource-spec-has-key? spec 'workspace)
      (poo-flow-sandbox-resource-spec-has-key? spec 'paths)
      (poo-flow-sandbox-resource-spec-has-key? spec 'root)
      (poo-flow-sandbox-resource-spec-has-key? spec 'volume)
      (poo-flow-sandbox-resource-spec-has-key? spec 'snapshot)))

;; : (-> AgentSandboxResourcePolicyEntry Boolean)
(def (poo-flow-sandbox-structured-filesystem-entry? resource)
  (and (pair? resource)
       (eq? (car resource) 'filesystem)
       (list? (cdr resource))
       (poo-flow-sandbox-resource-spec-has-key? (cdr resource) 'scope)
       (poo-flow-sandbox-resource-spec-has-anchor? (cdr resource))))

;;; Boundary: sandbox resource policy has structured filesystem predicate is
;;; the policy-visible edge for sandbox, core behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> ResourcePolicy Boolean)
(def (poo-flow-sandbox-resource-policy-has-structured-filesystem?
      resource-policy)
  (cond
   ((null? resource-policy) #f)
   ((not (pair? resource-policy)) #f)
   ((poo-flow-sandbox-structured-filesystem-entry? (car resource-policy))
    #t)
   (else
    (poo-flow-sandbox-resource-policy-has-structured-filesystem?
     (cdr resource-policy)))))

;; : (-> Alist)
(def (poo-flow-sandbox-resources-prototype-type-contract->alist)
  (poo-flow-native-contract->alist PooFlowSandboxResourcesPrototypeContract))

;; : (-> Symbol String Dyn POOObject)
(def (poo-flow-sandbox-resources-prototype-diagnostic code message value)
  (let ((diagnostic-code code)
        (diagnostic-message message)
        (diagnostic-value value))
    (.o code: diagnostic-code
        message: diagnostic-message
        object: 'PooSandboxResourcesPrototype
        value: diagnostic-value)))

(def (poo-flow-sandbox-resources-prototype-diagnostic->alist diagnostic)
  (list (cons 'code (.ref diagnostic 'code))
        (cons 'message (.ref diagnostic 'message))
        (cons 'object (.ref diagnostic 'object))
        (cons 'value (.ref diagnostic 'value))))

;; : [PooFlowTypeFactContract]
(def +poo-flow-sandbox-resources-prototype-type-facts+
  (list
   (poo-flow-type-fact
    'sandbox.resources/filesystem-prototype
    'slot-contract
    'PooSandboxResourcesPrototype
    'filesystemPrototype
    'filesystem
    'PooSandboxFilesystemPrototype
    'positive
    '((scope . sandbox-core) (required . #t)))
   (poo-flow-type-fact
    'sandbox.resources/cpu-number
    'slot-contract
    'PooSandboxResourcesPrototype
    'cpuNumber
    'cpu
    'Number
    'positive
    '((scope . sandbox-core) (required . #t)))
   (poo-flow-type-fact
    'sandbox.resources/memory-string
    'slot-contract
    'PooSandboxResourcesPrototype
    'memoryString
    'memory
    'String
    'positive
    '((scope . sandbox-core) (required . #t)))
   (poo-flow-type-fact
    'sandbox.resources/ports-list
    'slot-contract
    'PooSandboxResourcesPrototype
    'portsList
    'ports
    'List
    'optional
    '((scope . sandbox-core) (required . #f)))
   (poo-flow-type-fact
    'sandbox.resources/timeout-number
    'slot-contract
    'PooSandboxResourcesPrototype
    'timeoutNumber
    'timeout-ms
    'Number
    'optional
    '((scope . sandbox-core) (required . #f)))))

;; : [PooFlowLeanFactContract]
(def +poo-flow-sandbox-resources-prototype-lean-fact-contracts+
  (list
   (poo-flow-lean-fact
    'sandbox.resources/filesystem-structured
    'fact
    'SandboxResources.SandboxResourceFact
    'filesystemStructured
    'filesystem
    'positive
    '((scope . sandbox-core)))
   (poo-flow-lean-fact
    'sandbox.resources/cpu-present
    'fact
    'SandboxResources.SandboxResourceFact
    'cpuPresent
    'cpu
    'positive
    '((scope . sandbox-core)))
   (poo-flow-lean-fact
    'sandbox.resources/memory-present
    'fact
    'SandboxResources.SandboxResourceFact
    'memoryPresent
    'memory
    'positive
    '((scope . sandbox-core)))
   (poo-flow-lean-fact
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
(def (poo-flow-sandbox-resources-prototype-slot-readable? resources slot)
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
(def (poo-flow-sandbox-resources-prototype-slot-readability-diagnostics code
                                                                        slot
                                                                        resources)
  (if (or (not (object? resources))
          (not (.slot? resources slot))
          (poo-flow-sandbox-resources-prototype-slot-readable? resources slot))
    '()
    (list
     (poo-flow-sandbox-resources-prototype-diagnostic
      code
      "sandbox resources prototype slot exists but cannot be read through POO slot resolution"
      resources))))

;; : (-> PooSandboxResourcesPrototype PooFlowSlotContract [POOObject])
(def (poo-flow-sandbox-resources-prototype-slot-contract-diagnostics
      resources
      contract)
  (let (slot (poo-flow-contract-slot-name contract))
    (if (and (object? resources)
             (.slot? resources slot)
             (poo-flow-sandbox-resources-prototype-slot-readable? resources slot))
      (with-catch
       (lambda (_failure)
         (list
          (poo-flow-sandbox-resources-prototype-diagnostic
           'slot-contract-failed
           "sandbox resources prototype slot failed structured contract"
           (list (cons 'slot slot)))))
       (lambda ()
         (let (slot-value (.ref resources slot))
           (if (element? (poo-flow-contract-slot-type contract) slot-value)
             '()
             (list
              (poo-flow-sandbox-resources-prototype-diagnostic
               'slot-contract-failed
               "sandbox resources prototype slot failed structured contract"
               (list (cons 'slot slot)
                     (cons 'value slot-value))))))))
      '())))

;; : (-> PooSandboxResourcesPrototype [POOObject])
(def (poo-flow-sandbox-resources-prototype-slot-contracts-diagnostics
      resources)
  (poo-flow-sandbox-resource-segments/tail
   (map
    (lambda (contract)
      (poo-flow-sandbox-resources-prototype-slot-contract-diagnostics
       resources
       contract))
    PooFlowSandboxResourceSlotContracts)
   '()))

;;; Boundary: sandbox resources prototype missing slot diagnostics is the
;;; policy-visible edge for sandbox, core behavior, keeping validation, lookup,
;;; or projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype [POOObject])
(def (poo-flow-sandbox-resources-prototype-missing-slot-diagnostics resources
                                                                    slot
                                                                    code
                                                                    message)
  (if (.slot? resources slot)
    '()
    (list
     (poo-flow-sandbox-resources-prototype-diagnostic
      code
      message
      resources))))

;;; Boundary: sandbox prototype slot entry is the policy-visible edge for
;;; sandbox, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Object Symbol [Pair])
(def (poo-flow-sandbox-prototype-slot-entry prototype slot)
  (if (.slot? prototype slot)
    (list (cons slot (.ref prototype slot)))
    '()))

;; : (-> PooSandboxFilesystemPrototype AgentSandboxResourcePolicyEntry)
(def (poo-flow-sandbox-filesystem-prototype->resource-entry filesystem)
  (cons 'filesystem
        (poo-flow-sandbox-resource-segments/tail
         (list
          (poo-flow-sandbox-prototype-slot-entry filesystem 'scope)
          (poo-flow-sandbox-prototype-slot-entry filesystem 'materialized-by)
          (poo-flow-sandbox-prototype-slot-entry filesystem 'paths)
          (poo-flow-sandbox-prototype-slot-entry filesystem 'mounts)
          (poo-flow-sandbox-prototype-slot-entry filesystem 'access)
          (poo-flow-sandbox-prototype-slot-entry filesystem 'snapshot))
         (poo-flow-sandbox-prototype-slot-entry filesystem 'volume))))

;; : (-> PooSandboxFilesystemPrototype ResourcePolicy)
(def (poo-flow-sandbox-filesystem-prototype->resource-policy filesystem)
  (list (poo-flow-sandbox-filesystem-prototype->resource-entry filesystem)))

;;; Boundary: sandbox resources prototype to resource policy is the policy-
;;; visible edge for sandbox, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype ResourcePolicy)
(def (poo-flow-sandbox-resources-prototype->resource-policy resources)
  (poo-flow-sandbox-resource-segments/tail
   (list
    (if (.slot? resources 'filesystem)
      (list
       (poo-flow-sandbox-filesystem-prototype->resource-entry
        (.ref resources 'filesystem)))
      '())
    (poo-flow-sandbox-prototype-slot-entry resources 'mounts)
    (poo-flow-sandbox-prototype-slot-entry resources 'ports)
    (poo-flow-sandbox-prototype-slot-entry resources 'cpu)
    (poo-flow-sandbox-prototype-slot-entry resources 'memory))
   (poo-flow-sandbox-prototype-slot-entry resources 'timeout-ms)))

;;; Boundary: sandbox resources prototype structured filesystem diagnostics is
;;; the policy-visible edge for sandbox, core behavior, keeping validation,
;;; lookup, or projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype [POOObject])
(def (poo-flow-sandbox-resources-prototype-structured-filesystem-diagnostics
      resources)
  (if (not (poo-flow-sandbox-resources-prototype-slot-readable?
            resources
            'filesystem))
    '()
    (with-catch
     (lambda (_failure)
       (list
        (poo-flow-sandbox-resources-prototype-diagnostic
         'filesystem-not-structured
         "sandbox resources filesystem cannot project to a structured resource-policy entry"
         resources)))
     (lambda ()
       (let (resource-policy
             (poo-flow-sandbox-filesystem-prototype->resource-policy
              (.ref resources 'filesystem)))
         (if (poo-flow-sandbox-resource-policy-has-structured-filesystem?
              resource-policy)
           '()
           (list
            (poo-flow-sandbox-resources-prototype-diagnostic
             'filesystem-not-structured
             "sandbox resources filesystem must project to a structured resource-policy entry"
             resource-policy))))))))

;;; Boundary: sandbox resources prototype local diagnostics is the policy-
;;; visible edge for sandbox, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype [POOObject])
(def (poo-flow-sandbox-resources-prototype-local-diagnostics resources)
  (if (not (object? resources))
    (list
     (poo-flow-sandbox-resources-prototype-diagnostic
      'resources-prototype-not-object
      "sandbox resources contract expects a POO object"
      resources))
    (poo-flow-sandbox-resource-segments/tail
     (list
      (poo-flow-sandbox-resources-prototype-missing-slot-diagnostics
       resources
       'filesystem
       'missing-filesystem-slot
       "sandbox resources prototype must define filesystem")
      (poo-flow-sandbox-resources-prototype-missing-slot-diagnostics
       resources
       'cpu
       'missing-cpu-slot
       "sandbox resources prototype must define cpu")
      (poo-flow-sandbox-resources-prototype-missing-slot-diagnostics
       resources
       'memory
       'missing-memory-slot
       "sandbox resources prototype must define memory")
      (poo-flow-sandbox-resources-prototype-slot-readability-diagnostics
       'unreadable-filesystem-slot
       'filesystem
       resources)
      (poo-flow-sandbox-resources-prototype-slot-readability-diagnostics
       'unreadable-cpu-slot
       'cpu
       resources)
      (poo-flow-sandbox-resources-prototype-slot-readability-diagnostics
       'unreadable-memory-slot
       'memory
       resources)
      (poo-flow-sandbox-resources-prototype-slot-readability-diagnostics
       'unreadable-ports-slot
       'ports
       resources)
      (poo-flow-sandbox-resources-prototype-slot-readability-diagnostics
       'unreadable-timeout-slot
       'timeout-ms
       resources)
      (poo-flow-sandbox-resources-prototype-slot-contracts-diagnostics
       resources))
     (poo-flow-sandbox-resources-prototype-structured-filesystem-diagnostics
      resources))))

;; : (-> PooSandboxResourcesPrototype POOObject)
(def (poo-flow-sandbox-resources-prototype-contract-validation resources)
  (let* ((local-diagnostics
          (poo-flow-sandbox-resources-prototype-local-diagnostics resources))
         (native-valid? (null? local-diagnostics)))
    (.o kind: poo-flow-sandbox-resources-prototype-contract-validation-kind
        schema: poo-flow-sandbox-resources-prototype-contract-validation-schema
        object: 'PooSandboxResourcesPrototype
        valid: native-valid?
        diagnostics: local-diagnostics
        checked-signals:
        '(native-poo-object-shape native-poo-required-slots
          native-poo-slot-types structured-filesystem-projection
          structured-type-facts lean-fact-contracts)
        type-facts: +poo-flow-sandbox-resources-prototype-type-facts+
        lean-fact-contracts:
        +poo-flow-sandbox-resources-prototype-lean-fact-contracts+
        runtime-executed: #f)))

(def (poo-flow-sandbox-resources-prototype-contract-validation? validation)
  (and (object? validation)
       (andmap
        (lambda (slot)
          (poo-flow-sandbox-resources-prototype-slot-readable?
           validation slot))
        '(kind schema object valid diagnostics checked-signals
          type-facts lean-fact-contracts runtime-executed))
       (equal? (.ref validation 'kind)
               poo-flow-sandbox-resources-prototype-contract-validation-kind)
       (equal? (.ref validation 'schema)
               poo-flow-sandbox-resources-prototype-contract-validation-schema)))

;; : (-> POOObject Boolean)
(def (poo-flow-sandbox-resources-prototype-contract-validation-valid?
      validation)
  (and (poo-flow-sandbox-resources-prototype-contract-validation? validation)
       (.ref validation 'valid)))

;; : (-> POOObject [POOObject])
(def (poo-flow-sandbox-resources-prototype-contract-validation-diagnostics
      validation)
  (.ref validation 'diagnostics))

;; : (-> POOObject Alist)
(defpoo-final-projection
  poo-flow-sandbox-resources-prototype-contract-validation->alist
  (validation)
  (bindings ((diagnostic-objects (.ref validation 'diagnostics))))
  (fields ((kind (.ref validation 'kind))
           (schema (.ref validation 'schema))
           (object (.ref validation 'object))
           (valid (.ref validation 'valid))
           (diagnostics
            (map poo-flow-sandbox-resources-prototype-diagnostic->alist
                 diagnostic-objects))
           (diagnostic-count (length diagnostic-objects))
           (checked-signals (.ref validation 'checked-signals))
           (type-facts
            (map poo-flow-type-fact-contract->alist
                 (.ref validation 'type-facts)))
           (lean-fact-contracts
            (map poo-flow-lean-fact-contract->alist
                 (.ref validation 'lean-fact-contracts)))
           (runtime-executed (.ref validation 'runtime-executed)))))

;;; Boundary: require sandbox resources prototype contract! is the policy-
;;; visible edge for sandbox, core behavior, keeping validation, lookup, or
;;; projection responsibilities centralized for callers.
;; : (-> PooSandboxResourcesPrototype PooSandboxResourcesPrototype)
(def (poo-flow-require-sandbox-resources-prototype-contract! resources)
  (let (validation
        (poo-flow-sandbox-resources-prototype-contract-validation resources))
    (if (poo-flow-sandbox-resources-prototype-contract-validation-valid?
         validation)
      resources
      (error "sandbox resources prototype failed typed contract validation"
             validation))))

;;; Boundary: sandbox resources value to resource policy is the policy-visible
;;; edge for sandbox, core behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> Value ResourcePolicy)
(def (poo-flow-sandbox-resources-value->resource-policy resources)
  (if (object? resources)
    (poo-flow-sandbox-resources-prototype->resource-policy
     (poo-flow-require-sandbox-resources-prototype-contract! resources))
    resources))
