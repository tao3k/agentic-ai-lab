;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Pure provider-format conversion. Schemas/candidates are JSON wire values;
;;; public results and diagnostics are native POO objects. No process or Loader.
(import :clan/poo/object
        (only-in "./types.ss" OpenTofuConfigContract)
        (only-in :yuanxu/object-types/contracts yuanxu-validation-evidence-accepted?)
        :std/text/pregexp
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :yuanxu/modules/json-schema/functional yuanxu-contract-object-ref yuanxu-contract-key->symbol)
        (only-in :yuanxu/modules/json-schema/json-schema-validation-core
                 yuanxu-json-schema-candidate-rows)
        (only-in :yuanxu/modules/json-schema/json-schema-values yuanxu-json-schema-null?))
(export agentic-ai-lab-opentofu-cty->schema agentic-ai-lab-opentofu-block->schema
        agentic-ai-lab-opentofu-block-normalization agentic-ai-lab-opentofu-block-obligations
        opentofu-service-configuration)

;; Derive demand and input from the final declared configuration. Admission
;; precedes field projection, so malformed names/Types cannot fail as getters
;; or silently become a permissive resource envelope. No process starts here.
(def (opentofu-service-configuration configuration)
  (let (evidence (.call OpenTofuConfigContract .admit configuration #f))
    (unless (yuanxu-validation-evidence-accepted? evidence)
      (error "OpenTofu configuration admission refused" evidence))
    (let* ((checked (.get evidence candidate))
           (settings (.get checked services opentofu Null)))
      ;; Enabled intent still produces demand without a Source. The existing
      ;; Build.prepare boundary must report build-required instead of silently
      ;; treating an enabled service as inactive.
      (and settings
        (.o resource: (.o null_resource:
          (.o hello: (.o triggers: (.o message: (.get settings message))))))))))

(def (ref value key (default #f))
  (yuanxu-contract-object-ref value key default))
(def (nullable schema) `((anyOf . (((type . "null")) ,schema))))
(def (array-schema item declaration)
  (append `((type . "array") (items . ,item))
          (filter-map (lambda (keys)
                        (let (bound (ref declaration (car keys)))
                          (and bound (> bound 0) (cons (cdr keys) bound))))
                      '((min_items . minItems) (max_items . maxItems)))))

;; cty is a different source format, not another JSON Schema evaluator.
(def (agentic-ai-lab-opentofu-cty->schema type)
  (cond
   ((member type '("string" "number" "bool"))
    `((type . ,(if (equal? type "bool") "boolean" type))))
   ((and (list? type) (= (length type) 2))
    (let ((kind (car type)) (child (cadr type)))
      (cond
       ((member kind '("list" "set"))
        `((type . "array") (items . ,(agentic-ai-lab-opentofu-cty->schema child))))
       ((equal? kind "map")
        `((type . "object") (additionalProperties . ,(agentic-ai-lab-opentofu-cty->schema child))))
       ((equal? kind "tuple")
        `((type . "array")
          (items . ,(if (null? child) #f (map agentic-ai-lab-opentofu-cty->schema child)))
          (minItems . ,(length child)) (maxItems . ,(length child))))
       ((equal? kind "object")
        `((type . "object") (additionalProperties . #f)
          (properties . ,(map (lambda (row)
                                (cons (car row) (nullable (agentic-ai-lab-opentofu-cty->schema (cdr row))))) child))))
       (else (error "unsupported cty constructor" type)))))
   (else (error "unsupported cty type" type))))

(def (collection-schema mode schema declaration)
  (cond ((equal? mode "single") schema)
        ((equal? mode "list") (array-schema schema declaration))
        ;; Set bounds apply to normalized cardinality, not raw list length.
        ((equal? mode "set") `((type . "array") (items . ,schema)))
        ((equal? mode "map")
         (when (or (> (ref declaration 'min_items 0) 0) (> (ref declaration 'max_items 0) 0))
           (error "map cardinality conversion unsupported" declaration))
         `((type . "object") (additionalProperties . ,schema)))
        (else (error "unsupported nesting mode" mode))))

(def (input-attribute? attr) (or (ref attr 'required) (ref attr 'optional)))
(def (attribute-schema attr)
  (when (ref attr 'write_only) (error "write-only semantics unsupported" attr))
  (let* ((nested (ref attr 'nested_type))
         (schema (if nested
                   (collection-schema (ref nested 'nesting_mode)
                     (agentic-ai-lab-opentofu-block->schema nested) nested)
                   (agentic-ai-lab-opentofu-cty->schema (ref attr 'type)))))
    (if (ref attr 'required) schema (nullable schema))))

(def (agentic-ai-lab-opentofu-block->schema block)
  (let ((attributes (filter (lambda (row) (input-attribute? (cdr row)))
                            (ref block 'attributes '())))
        (blocks (ref block 'block_types '())))
    `((type . "object") (additionalProperties . #f)
      (required . ,(append
                    (map (lambda (row) (symbol->string (car row)))
                         (filter (lambda (row) (ref (cdr row) 'required)) attributes))
                    (map (lambda (row) (symbol->string (car row)))
                         (filter (lambda (row) (> (ref (cdr row) 'min_items 0) 0)) blocks))))
      (properties . ,(append
        (map (lambda (row) (cons (car row) (attribute-schema (cdr row)))) attributes)
        (map (lambda (row)
               (cons (car row)
                 (collection-schema (ref (cdr row) 'nesting_mode)
                   (agentic-ai-lab-opentofu-block->schema (ref (cdr row) 'block)) (cdr row)))) blocks))))))

(def (issue code location)
  (.o reason: code path: location))
(def (literal-string? value)
  (and (string? value) (not (pregexp-match "[$%][{]" value))))

;; Returns (normalized-wire . diagnostics). It never fabricates provider hash
;; evidence. The generic JSON Schema Contract owns structural validation first.
(def (walk-collection mode child value path declaration (literal-policy? #f) (admission? #f) (verify #f) (normalize #f))
  (cond
   ((equal? mode "single") (child value path))
   ((equal? mode "map")
    (walk-rows value (lambda (key item) (child item (append path (list (yuanxu-contract-key->symbol key)))))))
   ((member mode '("set" "list"))
    (let* ((value (if (vector? value) (vector->list value) value))
           (parts (map (lambda (item index) (child item (append path (list index))))
                       value (iota (length value))))
           (values (map car parts))
           (diagnostics (apply append (cons '() (map cdr parts)))))
      (if (equal? mode "list") (cons values diagnostics)
        (let* ((strings? (and literal-policy? (every literal-string? value)))
               (normalized
                 (if strings?
                   (let (literals (delete-duplicates/hash values from-end?: #t))
                     (if normalize (normalize path literals) literals))
                   values))
               (size (length normalized)))
          (cons normalized
                (append diagnostics
                  (if (equal? values normalized) '()
                    (list (issue 'set-normalization-required path)))
                  (cond
                   ((and strings? (not admission?)) '())
                   (verify
                    (let (reason (verify path values strings?))
                      (if reason (list (issue reason path)) '())))
                   (else (list (issue 'provider-set-identity-unresolved path))))
                  (if (or (not strings?) (and (>= size (ref declaration 'min_items 0))
                           (or (= (ref declaration 'max_items 0) 0)
                               (<= size (ref declaration 'max_items)))))
                    '() (list (issue 'normalized-set-cardinality path)))))))))
   (else (error "unsupported nesting mode" mode))))

(def (walk-rows rows transform)
  (let* ((rows (yuanxu-json-schema-candidate-rows rows))
         (parts (map (lambda (row) (cons (car row) (transform (car row) (cdr row)))) rows)))
    (cons (map (lambda (row) (cons (car row) (cadr row))) parts)
          (apply append (cons '() (map cddr parts))))))

(def (walk-type type value path (admission? #f) (verify #f) (normalize #f))
  (cond
   ((or (string? type) (yuanxu-json-schema-null? value)) (cons value '()))
   (else
    (let ((kind (car type)) (child (cadr type)))
      (cond
       ((member kind '("list" "set" "map"))
        (walk-collection kind (lambda (v p) (walk-type child v p admission? verify normalize))
                         value path '() (equal? child "string") admission? verify normalize))
       ((equal? kind "tuple")
        (let (parts (map (lambda (t v i) (walk-type t v (append path (list i)) admission? verify normalize))
                          child (if (vector? value) (vector->list value) value)
                          (iota (length child))))
          (cons (map car parts) (apply append (cons '() (map cdr parts))))))
       ((equal? kind "object")
        (walk-rows value (lambda (key item) (walk-type (ref child key) item (append path (list (yuanxu-contract-key->symbol key))) admission? verify normalize))))
       (else (error "unsupported cty constructor" type)))))))

(def (walk-block block candidate path (admission? #f) (verify #f) (normalize #f))
  (walk-rows candidate
    (lambda (key value)
      (let ((attr (ref (ref block 'attributes '()) key))
            (nested-block (ref (ref block 'block_types '()) key))
            (child-path (append path (list (yuanxu-contract-key->symbol key)))))
        (cond
         ((yuanxu-json-schema-null? value) (cons value '()))
         (attr
          (let (nested (ref attr 'nested_type))
            (if nested
              (walk-collection (ref nested 'nesting_mode)
                (lambda (v p) (walk-block nested v p admission? verify normalize)) value child-path nested #f admission? verify normalize)
              (walk-type (ref attr 'type) value child-path admission? verify normalize))))
         (nested-block
          (walk-collection (ref nested-block 'nesting_mode)
            (lambda (v p) (walk-block (ref nested-block 'block) v p admission? verify normalize))
            value child-path nested-block #f admission? verify normalize))
         (else (error "shape must be admitted before normalization" child-path)))))))

(def (agentic-ai-lab-opentofu-block-normalization block candidate (normalize #f))
  (let (result (walk-block block candidate '() #f #f normalize))
    (.o value: (car result)
        diagnostics: (filter (lambda (diagnostic)
                               (not (eq? (.get diagnostic reason) 'set-normalization-required)))
                             (cdr result)))))

(def (agentic-ai-lab-opentofu-block-obligations block candidate context (verify #f))
  (cdr (walk-block block candidate '() #t verify)))
