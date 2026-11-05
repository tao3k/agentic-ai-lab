;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: product descriptor to Core option/schema value projection.
;;; Invariant: option projection returns inspectable POO values only.
;; | PooModuleOptionConfigCandidate = Value
;; | PooModuleOptionSchemaCandidate = Value
;; | PooModuleOptionValidationReceiptCandidate = Value

(import (only-in :clan/poo/mop make-instance)
        (only-in :clan/poo/object .o .all-slots .ref .slot?)
        :agentic-ai-lab/modules/module-authoring/module-interface
        :agentic-ai-lab/modules/module-authoring/module-descriptor
        :yuanxu/module-system/projection/option-objects
        :yuanxu/module-system/projection/option-validation)

(export agentic-ai-lab-module-option-configs
        agentic-ai-lab-module-option-schemas
        agentic-ai-lab-module-option-validation-receipts
        agentic-ai-lab-module-validation-receipts)

;;; Boundary: option ids use the public slot name form.
;; : (-> OptionSlotName OptionId)
(def (agentic-ai-lab-module-option-id slot-name)
  (if (symbol? slot-name)
    (symbol->string slot-name)
    slot-name))

;;; Effective runtime Slot descriptors own Type, presence, defaults and constants.
;;; The projection adds module identity; diagnostic metadata stays on the Slot.
(def (agentic-ai-lab-module-schema-from-spec module-id-value option-id-value field)
  (make-instance ModuleOptionSchema
    id: option-id-value source-module: module-id-value field: field))

;;; Project final POO fields in their runtime order; receipts add source identity.
(def (agentic-ai-lab-module-option-configs module)
  (def owner (agentic-ai-lab-module-name module))
  (def config (agentic-ai-lab-module-config module))
  (if (object? config)
    (map (lambda (name)
           (.o id: (agentic-ai-lab-module-option-id name)
               value: (.ref config name)
               source-module: owner
               metadata: '()))
         (.all-slots config))
    ;; Keep legacy row order/duplicates; do not coerce rows through a new object.
    (map (lambda (entry)
           (.o id: (agentic-ai-lab-module-option-id (car entry))
               value: (cdr entry)
               source-module: owner
               metadata: '()))
         (agentic-ai-lab-module-options module))))

(def (agentic-ai-lab-module-option-schemas module)
  (def declaration (agentic-ai-lab-module-schemas module))
  ;; A legacy descriptor without an Interface has no declaration, not an
  ;; implicit String contract. Actual declarations must be runtime Records.
  (if (object? declaration)
    (let ((owner (agentic-ai-lab-module-name module))
          (slots (.ref declaration 'effective-slots)))
      (map (lambda (name)
             (agentic-ai-lab-module-schema-from-spec
               owner (agentic-ai-lab-module-option-id name) (.ref slots name)))
           (.all-slots slots)))
    '()))

;; : (-> PooModuleDescriptor [PooModuleOptionValidationReceipt])
(def (agentic-ai-lab-module-option-validation-receipts module)
  (let* ((declaration (agentic-ai-lab-module-schemas module))
         (config (agentic-ai-lab-module-config module))
         (owner (agentic-ai-lab-module-name module))
         (fields (and (object? declaration) (.ref declaration 'effective-slots)))
         (field-ref
          (lambda (id)
            (and fields (string? id)
              (let (name (string->symbol id))
                (and (.slot? fields name) (.ref fields name)))))))
    (if (and (object? declaration)
             (or (object? config)
                 (yuanxu-module-interface? (agentic-ai-lab-module-interface-object module))))
      (yuanxu-module-config-validation-receipts declaration field-ref config owner)
      (yuanxu-module-options-validate
        (lambda (id)
          (alet (field (field-ref id))
            (agentic-ai-lab-module-schema-from-spec owner id field)))
        (agentic-ai-lab-module-option-configs module)))))

;;; Boundary: module validation stays recursive over inline import profiles.
;; : (-> PooModuleDescriptor [PooModuleOptionValidationReceipt])
(def (agentic-ai-lab-module-validation-receipts module)
  (append
   (foldr append
          '()
          (map agentic-ai-lab-module-validation-receipts
               (agentic-ai-lab-module-import-configs (yuanxu-module-imports module))))
   (agentic-ai-lab-module-option-validation-receipts module)))
