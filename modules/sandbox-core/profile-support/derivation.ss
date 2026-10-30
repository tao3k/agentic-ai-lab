;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox profile derivation metadata and validated row input.

(import (only-in :std/list/list any fold)
        :gerbil/core
        (only-in :clan/poo/object .def .o .ref .slot? object?)
        :yuanxu/graph/interface
        :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/sandbox-core/shared-object
        :agentic-ai-lab/modules/agent-sandbox/config
        (only-in :agentic-ai-lab/modules/agent-sandbox/profile-validation
                 agent-sandbox-profile-resource-policy-filesystem-entry?
                 agent-sandbox-profile-resource-policy-filesystem-diagnostics)
        :agentic-ai-lab/modules/sandbox-core/resource-contract
        :agentic-ai-lab/modules/sandbox-core/profile-support/prototype
        :agentic-ai-lab/modules/sandbox-core/profile-support/projection-syntax
        :agentic-ai-lab/modules/sandbox-core/profile-support/authoring)

(export agentic-ai-lab-sandbox-profile-object-option
        agentic-ai-lab-sandbox-profile-object-metadata-key?
        agentic-ai-lab-sandbox-profile-object-metadata-without
        agentic-ai-lab-sandbox-profile-object-derivation-path
        agentic-ai-lab-sandbox-profile-object-derivation-step
        agentic-ai-lab-sandbox-profile-object-derived-metadata
        agentic-ai-lab-sandbox-profile-object-unsafe-filesystem-resource?
        agentic-ai-lab-sandbox-profile-object-field-value-safe?
        agentic-ai-lab-sandbox-profile-object-validate-row
        agentic-ai-lab-sandbox-profile-object-validate-rows)

;;; Option lookup is scoped to derivation/config helper options. User profile
;;; rows still pass through field-contract validation before POO extension.
;; : (-> Alist Symbol Value Value)
(def (agentic-ai-lab-sandbox-profile-object-option options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;;; Metadata removal is deliberately key based so derivations can replace
;;; lineage/runtime facts without dropping backend-provided metadata rows.
;; : (-> Symbol [Symbol] Boolean)
(def (agentic-ai-lab-sandbox-profile-object-metadata-key? key keys)
  (and (member key keys) #t))

;;; Metadata pruning is used only while deriving child profiles. It removes
;;; fields that must be recomputed for the child, while leaving unrelated
;;; policy annotations untouched.
;; : (-> Alist [Symbol] Alist Alist)
(def (agentic-ai-lab-sandbox-profile-object-metadata-without/rev metadata
                                                           keys
                                                           result-rev)
  (fold
   (lambda (entry result)
     (if (and (pair? entry)
              (agentic-ai-lab-sandbox-profile-object-metadata-key?
               (car entry)
               keys))
       result
       (cons entry result)))
   result-rev
   metadata))

;; : (-> Alist [Symbol] Alist)
(def (agentic-ai-lab-sandbox-profile-object-metadata-without metadata keys)
  (reverse
   (agentic-ai-lab-sandbox-profile-object-metadata-without/rev
    metadata
    keys
    '())))

;;; Parent profiles that do not carry lineage remain valid roots; they simply
;;; start the derivation path at the first child profile.
;; : (-> Alist [Alist])
(def (agentic-ai-lab-sandbox-profile-object-derivation-path metadata)
  (let (entry (assoc 'derivation-path metadata))
    (if (and entry (list? (cdr entry))) (cdr entry) '())))

;;; Each derivation step is an audit row, not runtime metadata. The child
;;; profile name is recorded separately from the parent so composition lineage
;;; can be inspected after multiple project/session/task hops.
;; : (-> Symbol Symbol Symbol Value Alist)
(def (agentic-ai-lab-sandbox-profile-object-derivation-step name-value
                                                      parent-name
                                                      scope
                                                      scope-ref)
  (agentic-ai-lab-sandbox-profile-field-rows/tail
   (if scope-ref
     (agentic-ai-lab-sandbox-profile-field-rows (scope-ref scope-ref))
     '())
   (profile name-value)
   (parent-profile parent-name)
   (scope scope)
   (derived-by 'agentic-ai-lab-sandbox-profile-object-derive)))

;;; Derived metadata replaces lineage/runtime facts while preserving ordinary
;;; parent metadata. This keeps inheritance visible without letting stale
;;; `runtime-executed` state leak into child profiles.
;; : (-> PooSandboxProfile Symbol Alist Alist)
(def (agentic-ai-lab-sandbox-profile-object-derived-metadata parent-profile
                                                       name-value
                                                       options)
  (let* ((parent-metadata (agentic-ai-lab-sandbox-profile-metadata parent-profile))
         (scope
          (agentic-ai-lab-sandbox-profile-object-option options 'scope 'profile))
         (scope-ref
          (agentic-ai-lab-sandbox-profile-object-option options 'scope-ref #f))
         (lineage
          (agentic-ai-lab-sandbox-profile-rows/tail
           (agentic-ai-lab-sandbox-profile-object-derivation-path parent-metadata)
           (list
            (agentic-ai-lab-sandbox-profile-object-derivation-step
             name-value
             (agentic-ai-lab-sandbox-profile-name parent-profile)
             scope
             scope-ref)))))
    (agentic-ai-lab-sandbox-profile-rows/tail
     (agentic-ai-lab-sandbox-profile-object-metadata-without
      parent-metadata
      '(derivation-path runtime-executed))
     (agentic-ai-lab-sandbox-profile-field-rows/tail
      (agentic-ai-lab-sandbox-profile-object-option options 'metadata '())
      (derivation-path lineage)
      (runtime-executed #f)))))


;;; Validation rejects malformed rows before POO extension, keeping bad user
;;; fragments from becoming partial profiles. The recursive scan is
;;; deliberately narrow: only filesystem resource rows can fail the extra
;;; project-workspace/path safety checks.
;; : (-> [AgentSandboxResourcePolicyEntry] Boolean)
(def (agentic-ai-lab-sandbox-profile-object-unsafe-filesystem-resource? resources)
  (and (list? resources)
       (if (any
            (lambda (resource)
              (and (agent-sandbox-profile-resource-policy-filesystem-entry?
                    resource)
                   (not (null?
                         (agent-sandbox-profile-resource-policy-filesystem-diagnostics
                          resources)))))
            resources)
         #t
         #f)))

;;; Resource-policy rows get an extra semantic safety check after the structural
;;; field contract accepts the list shape. Other fields are already fully
;;; covered by their POO field contract.
;; : (-> PooModuleFieldContract [Value] Boolean)
(def (agentic-ai-lab-sandbox-profile-object-field-value-safe? field value)
  (if (eq? (yuanxu-module-field-contract-identity field) 'resource-policy)
    (not (agentic-ai-lab-sandbox-profile-object-unsafe-filesystem-resource? value))
    #t))

;;; Row validation is the last user-interface gate before profile rows extend
;;; the POO prototype, so backend inheritance and unsafe filesystem policy
;;; are rejected here with the original row preserved in the diagnostic.
;; : (-> PooModuleObject SandboxProfileForm SandboxProfileForm)
(def (agentic-ai-lab-sandbox-profile-object-validate-row profile-object row)
  (cond
   ((not (pair? row))
    (error "sandbox profile config rows must be lists"))
   ((agentic-ai-lab-sandbox-profile-object-backend-row? row)
    (error "sandbox profile config inherits backend from use-module"))
   (else
    (let (field (agentic-ai-lab-sandbox-profile-object-row-field
                 profile-object
                 row))
      (if (and field
               (yuanxu-module-field-contract-accepts?
                field
                (agentic-ai-lab-sandbox-profile-object-row-value row))
               (agentic-ai-lab-sandbox-profile-object-field-value-safe?
                field
                (agentic-ai-lab-sandbox-profile-object-row-value row)))
        row
        (error "sandbox profile config row is not in backend profile object"
               (agentic-ai-lab-sandbox-profile-field-rows
                (row row)
                (slot (and field
                           (yuanxu-module-field-contract-identity
                            field)))
                (value
                 (agentic-ai-lab-sandbox-profile-object-row-value row))
                (accepted?
                 (and field
                      (yuanxu-module-field-contract-accepts?
                       field
                       (agentic-ai-lab-sandbox-profile-object-row-value
                        row))))
                (safe?
                 (and field
                      (agentic-ai-lab-sandbox-profile-object-field-value-safe?
                       field
                       (agentic-ai-lab-sandbox-profile-object-row-value
                        row)))))))))))

;;; Batch validation preserves declaration order for the POO extension fold
;;; after all rows have passed the contract gate.
;; : (-> PooModuleObject [SandboxProfileForm] [SandboxProfileForm])
(def (agentic-ai-lab-sandbox-profile-object-validate-rows profile-object forms)
  (for-each (lambda (row)
              (agentic-ai-lab-sandbox-profile-object-validate-row
               profile-object
               row))
            forms)
  forms)

;;; Slot reads are strict after merge because missing slots indicate a broken
;;; backend object contract, not optional user configuration.
;; : (-> YuanxuGraph Symbol Value)
