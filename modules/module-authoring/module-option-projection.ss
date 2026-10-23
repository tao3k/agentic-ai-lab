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

;;; Boundary: schema specs default to String when the interface is concise.
;; : (-> PooModuleSchemaSpec OptionValueType)
(def (agentic-ai-lab-module-schema-spec-type schema-spec)
  (yuanxu-module-object-ref/default schema-spec 'type 'String))

;;; Boundary: schema metadata is optional and never required for validation.
;; : (-> PooModuleSchemaSpec SchemaMetadata)
(def (agentic-ai-lab-module-schema-spec-metadata schema-spec)
  (yuanxu-module-object-ref/default schema-spec 'metadata '()))

;;; Boundary: one schema spec records required/default/constant/optional rule.
;; : (-> ModuleName OptionId PooModuleSchemaSpec PooModuleOptionSchema)
(def (agentic-ai-lab-module-schema-from-spec module-id-value option-id-value schema-spec)
  (let ((value-type (agentic-ai-lab-module-schema-spec-type schema-spec))
        (metadata-value (agentic-ai-lab-module-schema-spec-metadata schema-spec)))
    (cond
     ((.slot? schema-spec 'policy)
      (make-yuanxu-module-option-schema
       option-id-value
       module-id-value
       value-type
       (.ref schema-spec 'policy)
       (yuanxu-module-object-ref/default schema-spec 'default #f)
       metadata-value))
     ((.slot? schema-spec 'constant)
      (make-yuanxu-module-option-schema
       option-id-value
       module-id-value
       value-type
       'constant
       (.ref schema-spec 'constant)
       metadata-value))
     ((.slot? schema-spec 'default)
      (make-yuanxu-module-option-schema
       option-id-value
       module-id-value
       value-type
       'default
       (.ref schema-spec 'default)
       metadata-value))
     ((yuanxu-module-object-ref/default schema-spec 'optional? #f)
      (make-yuanxu-module-option-schema
       option-id-value
       module-id-value
       value-type
       'optional
       #f
       metadata-value))
     (else
      (make-yuanxu-module-option-schema
       option-id-value
       module-id-value
       value-type
       'required
       #f
       metadata-value)))))

;;; Boundary: config objects become option config receipts at projection time.
;; : (-> ModuleId POOConfigRecord [Symbol] [PooModuleOptionConfig] [PooModuleOptionConfig])
(def (agentic-ai-lab-module-object-option-configs/rev
      module-id-value
      option-object
      slot-names
      configs-rev)
  (if (null? slot-names)
    configs-rev
    (agentic-ai-lab-module-object-option-configs/rev
     module-id-value
     option-object
     (cdr slot-names)
     (cons (make-yuanxu-module-option-config
            (agentic-ai-lab-module-option-id (car slot-names))
            (.ref option-object (car slot-names))
            module-id-value
            '())
           configs-rev))))

;; : (-> ModuleId ModuleOptionAlist [PooModuleOptionConfig] [PooModuleOptionConfig])
(def (agentic-ai-lab-module-alist-option-configs/rev
      module-id-value
      options
      configs-rev)
  (if (null? options)
    configs-rev
    (agentic-ai-lab-module-alist-option-configs/rev
     module-id-value
     (cdr options)
     (cons (make-yuanxu-module-option-config
            (agentic-ai-lab-module-option-id (caar options))
            (cdar options)
            module-id-value
            '())
           configs-rev))))

;; : (-> PooModuleDescriptor [PooModuleOptionConfig])
(def (agentic-ai-lab-module-option-configs module)
  (let ((module-id-value (agentic-ai-lab-module-name module))
        (option-object (agentic-ai-lab-module-config module)))
    (cond
     ((object? option-object)
      (reverse
       (agentic-ai-lab-module-object-option-configs/rev
        module-id-value
        option-object
        (.all-slots option-object)
        '())))
     (else
      (reverse
       (agentic-ai-lab-module-alist-option-configs/rev
        module-id-value
        (agentic-ai-lab-module-options module)
        '()))))))

;;; Boundary: option schemas are projected from interface schema slots.
;; : (-> ModuleId POOConfigRecord [Symbol] [PooModuleOptionSchema] [PooModuleOptionSchema])
(def (agentic-ai-lab-module-option-schemas/rev
      module-id-value
      schema-object
      slot-names
      schemas-rev)
  (if (null? slot-names)
    schemas-rev
    (agentic-ai-lab-module-option-schemas/rev
     module-id-value
     schema-object
     (cdr slot-names)
     (cons (agentic-ai-lab-module-schema-from-spec
            module-id-value
            (agentic-ai-lab-module-option-id (car slot-names))
            (.ref schema-object (car slot-names)))
           schemas-rev))))

;; : (-> PooModuleDescriptor [PooModuleOptionSchema])
(def (agentic-ai-lab-module-option-schemas module)
  (let ((module-id-value (agentic-ai-lab-module-name module))
        (schema-object (agentic-ai-lab-module-schemas module)))
    (if (object? schema-object)
      (reverse
       (agentic-ai-lab-module-option-schemas/rev
        module-id-value
        schema-object
        (.all-slots schema-object)
        '()))
      '())))

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
