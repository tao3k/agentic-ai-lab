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
        :poo-flow/modules/module-authoring/module-interface
        :poo-flow/modules/module-authoring/module-descriptor
        :core/module-system/projection/option-objects
        :core/module-system/projection/option-validation)

(export poo-flow-module-option-configs
        poo-flow-module-option-schemas
        poo-flow-module-option-validation-receipts
        poo-flow-module-validation-receipts)

;;; Boundary: option ids use the public slot name form.
;; : (-> OptionSlotName OptionId)
(def (poo-flow-module-option-id slot-name)
  (if (symbol? slot-name)
    (symbol->string slot-name)
    slot-name))

;;; Boundary: schema specs default to String when the interface is concise.
;; : (-> PooModuleSchemaSpec OptionValueType)
(def (poo-flow-module-schema-spec-type schema-spec)
  (poo-flow-module-object-ref/default schema-spec 'type 'String))

;;; Boundary: schema metadata is optional and never required for validation.
;; : (-> PooModuleSchemaSpec SchemaMetadata)
(def (poo-flow-module-schema-spec-metadata schema-spec)
  (poo-flow-module-object-ref/default schema-spec 'metadata '()))

;;; Boundary: one schema spec records required/default/constant/optional rule.
;; : (-> ModuleName OptionId PooModuleSchemaSpec PooModuleOptionSchema)
(def (poo-flow-module-schema-from-spec module-id-value option-id-value schema-spec)
  (let ((value-type (poo-flow-module-schema-spec-type schema-spec))
        (metadata-value (poo-flow-module-schema-spec-metadata schema-spec)))
    (cond
     ((.slot? schema-spec 'policy)
      (make-poo-flow-module-option-schema
       option-id-value
       module-id-value
       value-type
       (.ref schema-spec 'policy)
       (poo-flow-module-object-ref/default schema-spec 'default #f)
       metadata-value))
     ((.slot? schema-spec 'constant)
      (make-poo-flow-module-option-schema
       option-id-value
       module-id-value
       value-type
       'constant
       (.ref schema-spec 'constant)
       metadata-value))
     ((.slot? schema-spec 'default)
      (make-poo-flow-module-option-schema
       option-id-value
       module-id-value
       value-type
       'default
       (.ref schema-spec 'default)
       metadata-value))
     ((poo-flow-module-object-ref/default schema-spec 'optional? #f)
      (make-poo-flow-module-option-schema
       option-id-value
       module-id-value
       value-type
       'optional
       #f
       metadata-value))
     (else
      (make-poo-flow-module-option-schema
       option-id-value
       module-id-value
       value-type
       'required
       #f
       metadata-value)))))

;;; Boundary: config objects become option config receipts at projection time.
;; : (-> ModuleId POOConfigRecord [Symbol] [PooModuleOptionConfig] [PooModuleOptionConfig])
(def (poo-flow-module-object-option-configs/rev
      module-id-value
      option-object
      slot-names
      configs-rev)
  (if (null? slot-names)
    configs-rev
    (poo-flow-module-object-option-configs/rev
     module-id-value
     option-object
     (cdr slot-names)
     (cons (make-poo-flow-module-option-config
            (poo-flow-module-option-id (car slot-names))
            (.ref option-object (car slot-names))
            module-id-value
            '())
           configs-rev))))

;; : (-> ModuleId ModuleOptionAlist [PooModuleOptionConfig] [PooModuleOptionConfig])
(def (poo-flow-module-alist-option-configs/rev
      module-id-value
      options
      configs-rev)
  (if (null? options)
    configs-rev
    (poo-flow-module-alist-option-configs/rev
     module-id-value
     (cdr options)
     (cons (make-poo-flow-module-option-config
            (poo-flow-module-option-id (caar options))
            (cdar options)
            module-id-value
            '())
           configs-rev))))

;; : (-> PooModuleDescriptor [PooModuleOptionConfig])
(def (poo-flow-module-option-configs module)
  (let ((module-id-value (poo-flow-module-name module))
        (option-object (poo-flow-module-config module)))
    (cond
     ((object? option-object)
      (reverse
       (poo-flow-module-object-option-configs/rev
        module-id-value
        option-object
        (.all-slots option-object)
        '())))
     (else
      (reverse
       (poo-flow-module-alist-option-configs/rev
        module-id-value
        (poo-flow-module-options module)
        '()))))))

;;; Boundary: option schemas are projected from interface schema slots.
;; : (-> ModuleId POOConfigRecord [Symbol] [PooModuleOptionSchema] [PooModuleOptionSchema])
(def (poo-flow-module-option-schemas/rev
      module-id-value
      schema-object
      slot-names
      schemas-rev)
  (if (null? slot-names)
    schemas-rev
    (poo-flow-module-option-schemas/rev
     module-id-value
     schema-object
     (cdr slot-names)
     (cons (poo-flow-module-schema-from-spec
            module-id-value
            (poo-flow-module-option-id (car slot-names))
            (.ref schema-object (car slot-names)))
           schemas-rev))))

;; : (-> PooModuleDescriptor [PooModuleOptionSchema])
(def (poo-flow-module-option-schemas module)
  (let ((module-id-value (poo-flow-module-name module))
        (schema-object (poo-flow-module-schemas module)))
    (if (object? schema-object)
      (reverse
       (poo-flow-module-option-schemas/rev
        module-id-value
        schema-object
        (.all-slots schema-object)
        '()))
      '())))

;; : (-> PooModuleDescriptor [PooModuleOptionValidationReceipt])
(def (poo-flow-module-option-validation-receipts module)
  (let* ((interface (poo-flow-module-interface-object module))
         (schema-ref
          (if (poo-flow-module-interface? interface)
            (lambda (option-id)
              (alet (schema-spec
                     (poo-flow-module-interface-schema-spec
                      interface
                      option-id))
                (poo-flow-module-schema-from-spec
                 (poo-flow-module-name module)
                 option-id
                 schema-spec)))
            (let ((schemas (poo-flow-module-option-schemas module))
                  (index (make-hash-table)))
              (for-each
               (lambda (schema)
                 (hash-put! index
                            (poo-flow-module-option-schema-id schema)
                            schema))
               schemas)
              (lambda (option-id) (hash-get index option-id))))))
    (poo-flow-module-options-validate
     schema-ref
     (poo-flow-module-option-configs module))))

;;; Boundary: module validation stays recursive over inline import profiles.
;; : (-> PooModuleDescriptor [PooModuleOptionValidationReceipt])
(def (poo-flow-module-validation-receipts module)
  (append
   (foldr append
          '()
          (map poo-flow-module-validation-receipts
               (poo-flow-module-import-configs (poo-flow-module-imports module))))
   (poo-flow-module-option-validation-receipts module)))
