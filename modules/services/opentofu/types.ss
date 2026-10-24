;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :clan/poo/object
        (only-in :std/text/pregexp pregexp-match)
        (only-in :clan/poo/mop define-type Type.)
        (only-in :clan/poo/object-contract ObjectContract.)
        (only-in :clan/poo/type String Symbol OrFalse Union)
        (only-in :agentic-ai-lab/modules/services/types Services)
        (only-in :yuanxu/modules/json-schema/contracts ProjectionContract.)
        (only-in :yuanxu/object-types/contracts YuanxuContract. yuanxu-predicate-contract yuanxu-validation-evidence-accepted?)
        (only-in :agentic-ai-lab/modules/nix/types NixSourceContract NixFlakeSourceContract NixScopeContract)
        (only-in :yuanxu/modules/json-schema/types JsonSchemaScopeContract)
        (only-in :yuanxu/modules/funflow/types FunflowScopeContract)
        (only-in :yuanxu/modules/json-schema/json-schema-contract yuanxu-json-schema->contract))
(export ProviderArtifactContract ProviderTypeIndexContract ProviderSelectionContract ConfigurationEnvelopeContract
        NullContract OpenTofuContract ServicesContract
        execution-admission CollectionAuthorityType CollectionReceiptType OpenTofuConfigContract OpenTofuScopeContract
        NixScopeContract JsonSchemaScopeContract FunflowScopeContract)

;; Only the OpenTofu configuration envelope belongs here. Field constraints
;; come from each demanded Provider Contract, not a second maintained table.
(def ConfigurationEnvelopeContract
  (let ((object-input '((type . "object")))
        (instances '((type . "object") (additionalProperties . ((type . "object"))))))
    (yuanxu-json-schema->contract 'opentofu/configuration-envelope
      `((type . "object") (additionalProperties . #f)
        (properties .
          ((provider . ((type . "object")
                        (additionalProperties . ((type . "array") (items . ,object-input)))))
           (resource . ((type . "object") (additionalProperties . ,instances)))
           (data . ((type . "object") (additionalProperties . ,instances)))))))))

(def ProviderSelectionContract
  (yuanxu-json-schema->contract 'opentofu/provider-selection
    '((type . "object") (additionalProperties . #f)
      (required . ("provider" "version"))
      (properties .
        ((provider . ((type . "string") (minLength . 1)))
         (version . ((type . "string")
                     (pattern . "^[0-9]+[.][0-9]+[.][0-9]+$"))))))))

;; Shape of a package-produced manifest, not an independent package lock.
(def digest-schema '((type . "string") (pattern . "^[0-9a-f]{64}$")))
(def ProviderArtifactContract
  (yuanxu-json-schema->contract 'opentofu/provider-artifact
    `((type . "object") (additionalProperties . #f)
      (required . ("format" "provider" "version" "schema-sha256" "indexes"))
      (properties .
        ((format . ((type . "string") (pattern . "^yuanxu/provider-schema-v2$")))
         (provider . ((type . "string") (minLength . 1)))
         (version . ((type . "string") (minLength . 1)))
         (schema-sha256 . ,digest-schema)
         (indexes . ((type . "object") (additionalProperties . #f)
                     (required . ("provider" "resource" "data"))
                     (properties . ((provider . ,digest-schema)
                                    (resource . ,digest-schema)
                                    (data . ,digest-schema))))))))))

(def ProviderTypeIndexContract
  (yuanxu-json-schema->contract 'opentofu/provider-type-index
    `((type . "object") (additionalProperties . #f)
      (required . ("provider" "version" "schema-sha256" "kind" "entries"))
      (properties .
        ((provider . ((type . "string") (minLength . 1)))
         (version . ((type . "string") (minLength . 1)))
         (schema-sha256 . ,digest-schema)
         (kind . ((enum . ("provider" "resource" "data"))))
         (entries . ((type . "object") (additionalProperties . ,digest-schema))))))))

(def (slots-satisfy? value requirements)
  (and (object? value)
       (every (lambda (row)
                (and (.slot? value (car row)) ((cdr row) (.ref value (car row)))))
              requirements)))

(define-type (CollectionAuthorityType @ Type.)
  .element?:
  (lambda (value)
    (slots-satisfy? value
      (list (cons 'provider string?) (cons 'version string?) (cons 'schema string?)
            (cons '.matches? procedure?) (cons '.issue procedure?) (cons '.verify procedure?)))))

;; Shape only. This Type deliberately does not authenticate a receipt.
(define-type (CollectionReceiptType @ Type.)
  .element?:
  (lambda (value)
    (slots-satisfy? value
      (list (cons 'provider string?) (cons 'version string?) (cons 'schema string?)
            (cons 'field list?) (cons 'candidate-digest string?) (cons 'expires real?)))))

;; Scope publication checks shape without demanding artifacts or activating Build.
(def OpenTofuScopeContract
  (yuanxu-predicate-contract 'opentofu/scope
    (lambda (value)
      (and (object? value)
           (every (cut .slot? value <>) '(config modules types prototypes schema .build-inputs))
           (object? (.get value config))
           (.slot? (.get value types) 'configuration)
           (every (cut .slot? (.get value types) <>) '(config Services OpenTofu))
           (eq? (.get value types config) OpenTofuConfigContract)
           (eq? (.get value types Services) ServicesContract)
           (eq? (.get value types OpenTofu) OpenTofuContract)))
    (lambda (_value _context) '())))
(def OpenTofuSourceContract
  (yuanxu-predicate-contract 'opentofu/config
    (lambda (value)
      (and (object? value) (.slot? value 'artifact) (.slot? value 'source)
           (or (not (.get value artifact)) (string? (.get value artifact)))
           (or (not (.slot? value 'selection-input)) (not (.get value selection-input))
               (and (symbol? (.get value selection-input))
                    (pregexp-match "^[A-Za-z][A-Za-z0-9_-]*$"
                                   (symbol->string (.get value selection-input)))))
           (let (source (.get value source))
             (or (not source)
                 (and (object? source) (.slot? source '.prepare)
                      (procedure? (.get source .prepare))
                      (.slot? source 'source-inputs)
                      (or (yuanxu-validation-evidence-accepted? (.call NixFlakeSourceContract .admit source #f))
                          (yuanxu-validation-evidence-accepted? (.call NixSourceContract .admit source #f))))))))
    (lambda (_value _context) '())))

;; These declarations precede every configuration instance and remain strict
;; after POO inheritance, scalar override and recursive object refinement.
(.def (NullContract @ ObjectContract.)
  identity: 'opentofu/Null
  responsibilities: (.o message: String))
(.def (OpenTofuContract @ ObjectContract.)
  identity: 'opentofu
  responsibilities: (.o Null: (OrFalse NullContract)))
(.def (ServicesContract @ Services)
  responsibilities: =>.+ (.o opentofu: OpenTofuContract))

;; Package inputs and user configuration have explicit Types. The source
;; protocol constraint retains preparation/observation checks from the existing
;; implementation; ObjectContract owns unknown-field and nested-value checks.
(.def (OpenTofuConfigContract @ YuanxuContract.)
  identity: 'opentofu/config
  value-contract:
  (.o (:: @ ObjectContract.)
    identity: 'opentofu/config
    responsibilities:
    (.o source: (OrFalse (Union NixSourceContract NixFlakeSourceContract))
        selection-input: (OrFalse Symbol)
        artifact: (OrFalse String)
        services: ServicesContract)
    constraints: (list OpenTofuSourceContract)))

;; Reuse the selected resource's projection Type and exact Schema observations.
;; The publication checks the final execution receiver, never a parent receipt.
(def (execution-admission resource-contract)
  (.cc (yuanxu-predicate-contract 'opentofu/execution object? (lambda (_v _c) '()))
    'source-inputs (.get resource-contract source-inputs)
    'value-contract
    (.cc ProjectionContract.
      'constraint (.cc ObjectContract. 'responsibilities
                    (.o config: NullContract resource: (.get resource-contract value-type)))
      'project (lambda (execution)
                 (.o config: (.o message: (.get execution message))
                     resource: (.get execution resource))))))
