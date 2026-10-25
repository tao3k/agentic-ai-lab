;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: product descriptor to Core option/schema value projection.
;;; Invariant: option projection returns inspectable POO values only.
;; | PooModuleOptionConfigCandidate = Value
;; | PooModuleOptionSchemaCandidate = Value
;; | PooModuleOptionValidationReceiptCandidate = Value

(import (only-in :clan/poo/object .all-slots .ref .slot?)
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

;;; Effective native Slot descriptors own Type, presence, defaults and constants.
;;; The receipt adds only the contributing module and diagnostic metadata.
(def (agentic-ai-lab-module-schema-from-spec module-id-value option-id-value field)
  (make-yuanxu-module-option-schema option-id-value module-id-value field
    (yuanxu-module-object-ref/default field 'metadata '())))

;;; Project final POO fields in their native order; receipts add source identity.
(def (agentic-ai-lab-module-option-configs module)
  (def owner (agentic-ai-lab-module-name module))
  (def config (agentic-ai-lab-module-config module))
  (map (lambda (entry)
         (make-yuanxu-module-option-config
           (agentic-ai-lab-module-option-id (car entry)) (cdr entry) owner '()))
       (if (object? config) (yuanxu-module-object->alist config)
           (agentic-ai-lab-module-options module))))

(def (agentic-ai-lab-module-option-schemas module)
  (def declaration (agentic-ai-lab-module-schemas module))
  ;; A legacy descriptor without an Interface has no declaration, not an
  ;; implicit String contract. Actual declarations must be native Records.
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
  (let* ((interface (agentic-ai-lab-module-interface-object module))
         (schema-ref
          (if (yuanxu-module-interface? interface)
            (lambda (option-id)
              (alet (schema-spec
                     (yuanxu-module-interface-schema-spec
                      interface
                      option-id))
                (agentic-ai-lab-module-schema-from-spec
                 (agentic-ai-lab-module-name module)
                 option-id
                 schema-spec)))
            (let ((schemas (agentic-ai-lab-module-option-schemas module))
                  (index (make-hash-table)))
              (for-each
               (lambda (schema)
                 (hash-put! index
                            (yuanxu-module-option-schema-id schema)
                            schema))
               schemas)
              (lambda (option-id) (hash-get index option-id))))))
    (yuanxu-module-options-validate
     schema-ref
     (agentic-ai-lab-module-option-configs module))))

;;; Boundary: module validation stays recursive over inline import profiles.
;; : (-> PooModuleDescriptor [PooModuleOptionValidationReceipt])
(def (agentic-ai-lab-module-validation-receipts module)
  (append
   (foldr append
          '()
          (map agentic-ai-lab-module-validation-receipts
               (agentic-ai-lab-module-import-configs (yuanxu-module-imports module))))
   (agentic-ai-lab-module-option-validation-receipts module)))
