;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :clan/poo/object
        (only-in :std/list/list-builder with-list-builder)
        (only-in "./execution.ss" OpenTofuExecution. NullExecution. opentofu-execution)
        (only-in :yuanxu/object-types/contracts YuanxuContract. yuanxu-classification-evidence
                 yuanxu-classification-evidence-accepted? yuanxu-validation-evidence-accepted?)
        (only-in :std/text/pregexp pregexp-match)
        (only-in :yuanxu/modules/json-schema/json-schema-contract yuanxu-json-schema->contract)
        "./func.ss" "./collections.ss" "./types.ss" "./config.ss" "./source.ss"
        (only-in :yuanxu/module-system/source/objects make-yuanxu-module-source-ref)
        (only-in :clan/poo/mop element?)
        (only-in :yuanxu/modules/json-schema/functional yuanxu-contract-object-ref
                 yuanxu-contract-key->symbol yuanxu-contract-json-array->list)
        (only-in :yuanxu/modules/json-schema/json-schema-diagnostics
                 make-yuanxu-json-schema-validation-diagnostic
                 yuanxu-json-schema-validation-diagnostic-severity
                 yuanxu-json-schema-validation-diagnostic-reason
                 yuanxu-json-schema-validation-diagnostic-message
                 yuanxu-json-schema-validation-diagnostic-value
                 yuanxu-json-schema-validation-diagnostic-contract
                 yuanxu-json-schema-validation-diagnostic-metadata)
        (only-in :yuanxu/modules/json-schema/json-schema-validation-core
                 yuanxu-json-schema-candidate-rows yuanxu-json-schema-path->symbol
                 yuanxu-json-schema-candidate-slot))
(export agentic-ai-lab-opentofu-block-contract agentic-ai-lab-opentofu-configuration-contract
        agentic-ai-lab-opentofu-configuration-from-types
        agentic-ai-lab-opentofu-normalize-block
        OpenTofuModule. OpenTofuScope. OpenTofuConfiguration.
        agentic-ai-lab-opentofu-provider-from-directory)

;; Configuration admission is structural. Provider collection identity belongs
;; to the explicit collection-contract, never a prerequisite for configuration.
;; Only provider semantics live here. Classification and path diagnostics are
;; supplied by the shared JSON Schema -> native admission adapter.
(def (collection-step binding candidate context issue? lifetime emit path values literal?)
  (cond
   ((not binding) 'provider-set-identity-unresolved)
   ((not issue?)
    (.call (car binding) .verify candidate path values literal? context (cdr binding)))
   (else
    (let (receipt (.call (car binding) .issue candidate path values literal? lifetime (cdr binding)))
      (cond (receipt (emit receipt) #f)
            (else 'provider-set-identity-unresolved))))))

(def (contract-with-collections identity block authority-for)
  (let (shape-contract (yuanxu-json-schema->contract identity
                         (agentic-ai-lab-opentofu-block->schema block)))
    (def (walk candidate context issue? lifetime)
      (let (diagnostics '())
        (let (receipts
               (with-list-builder (emit)
                 (set! diagnostics
                   (agentic-ai-lab-opentofu-block-obligations block candidate context
                     (lambda (path values literal?)
                       (collection-step (authority-for path) candidate context
                         issue? lifetime emit path values literal?))))))
          (.cc (.o) 'receipts receipts 'diagnostics diagnostics))))
    (.cc shape-contract
         'collection-contract
         (.cc shape-contract '.obligations
           (lambda (candidate context) (.get (walk candidate context #f 0) diagnostics)))
         '.prove
         (lambda (candidate (lifetime 300))
           (let (shape (.call shape-contract .classify candidate #f))
             (if (yuanxu-classification-evidence-accepted? shape)
               (walk candidate #f #t lifetime)
               (.o receipts: '() diagnostics: (.get shape diagnostics)))))
         '.normalize
         (lambda (candidate)
           (let (evidence (.call shape-contract .classify candidate #f))
             (if (yuanxu-classification-evidence-accepted? evidence)
               (agentic-ai-lab-opentofu-block-normalization block candidate
                 (lambda (path values)
                   (let (binding (authority-for path))
                     (if (and binding (.has? (car binding) .normalize-values))
                       (.call (car binding) .normalize-values values)
                       values))))
               (.o value: candidate diagnostics: (.get evidence diagnostics))))))))

(def (checked-authority authority block field)
  (and authority (element? CollectionAuthorityType authority)
       (.call authority .matches? block)
       (cons authority field)))

(def (agentic-ai-lab-opentofu-block-contract identity block (authority #f))
  (when (and authority (not (checked-authority authority block '())))
    (error "collection authority Schema does not match block" identity))
  (contract-with-collections identity block
    (lambda (path) (checked-authority authority block path))))

(def (agentic-ai-lab-opentofu-normalize-block block candidate)
  (.call (agentic-ai-lab-opentofu-block-contract 'opentofu/normalization block)
         .normalize candidate))

;; A selected configuration is just another block shape. Selection is explicit
;; and inert; provider acquisition, lock verification and publication are not here.
(def (agentic-ai-lab-opentofu-configuration-contract providers resources data (authorities #f))
  (let (instance-block
         (lambda (members mode)
           `((attributes . ())
             (block_types . ,(map (lambda (row)
                                   (cons (car row)
                                     `((nesting_mode . ,mode)
                                       (block . ,(cdr row))))) members)))))
    (contract-with-collections 'opentofu/configuration
      `((block_types .
          ((provider . ((nesting_mode . "single") (block . ,(instance-block providers "list"))))
           (resource . ((nesting_mode . "single") (block . ,(instance-block resources "map"))))
           (data . ((nesting_mode . "single") (block . ,(instance-block data "map")))))))
      (lambda (path)
        (and (>= (length path) 4)
             (let* ((kind (car path)) (name (cadr path))
                    (members (cond ((eq? kind 'provider) providers)
                                   ((eq? kind 'resource) resources)
                                   ((eq? kind 'data) data) (else '())))
                    (block-row (assoc name members))
                    (authority (yuanxu-contract-object-ref
                                 (yuanxu-json-schema-candidate-rows
                                   (yuanxu-contract-object-ref
                                     (yuanxu-json-schema-candidate-rows authorities) kind #f)) name #f)))
               (and block-row
                    (checked-authority authority (cdr block-row) (cdddr path)))))))))

;; Compose selected generated input schemas, not raw provider exports. The
;; selected native Contracts remain attached for provenance/inspection. This
;; structural boundary does not discharge collection identity or Provider RPC.
(def (agentic-ai-lab-opentofu-configuration-from-types selected)
  (def (rows value) (yuanxu-json-schema-candidate-rows value))
  (def (object-schema properties)
    `((type . "object") (additionalProperties . #f) (properties . ,properties)))
  (unless (and (object? selected) (= (length (.all-slots selected)) 3)
               (every (lambda (kind)
                        (and (.slot? selected kind) (object? (.ref selected kind))))
                      '(provider resource data)))
    (error "configuration types require provider/resource/data slots"))
  (def providers (rows (.get selected provider)))
  (def (same-package? contract)
    (any (lambda (row)
           (every (lambda (slot) (equal? (.ref contract slot) (.ref (cdr row) slot)))
                  '(provider version schema-digest)))
         providers))
  (def (section kind)
    (map (lambda (row)
           (let ((name (car row)) (contract (cdr row)))
             (unless (and (eq? (.get contract kind) kind)
                          (or (eq? kind 'provider) (eq? (.get contract name) name))
                          (same-package? contract))
               (error "configuration-contract-selection-mismatch" kind name))
             (cons name
               (if (eq? kind 'provider)
                 `((type . "array") (items . ,(.get contract schema)))
                 `((type . "object") (additionalProperties . ,(.get contract schema)))))))
         (rows (.ref selected kind))))
  (.cc (yuanxu-json-schema->contract 'opentofu/configuration
         (object-schema
           (map (lambda (kind) (cons kind (object-schema (section kind))))
                '(provider resource data))))
       'selected-types selected))

;; Package parsing is a lower role; native publication belongs to objects.
(def (required rows key)
  (or (yuanxu-contract-object-ref rows key #f)
      (error "provider-schema-field-missing" key)))

(def (provider-scope directory manifest artifact)
  (let* ((address (required manifest 'provider))
         (version (required manifest 'version))
         (origin (make-yuanxu-module-source-ref 'generated directory
                   (.cc (.o) 'provider address 'version version
                        'schema-digest (required manifest 'schema-sha256)
                        'index-digests (required manifest 'indexes))))
         (contracts (make-hash-table test: equal?)))
    ;; A package fixes the schema snapshot. Compile only requested contracts;
    ;; an unsupported/unselected resource cannot force all other resources.
    (def (contract name (kind 'resource))
      (let (key (cons kind name))
        (or (hash-ref contracts key #f)
            (let* ((input (.call artifact .read-entry name kind))
                   (entry (.get input schema))
                   (generated (agentic-ai-lab-opentofu-block-contract
                                (string->symbol
                                  (string-append address "@" version "/"
                                    (symbol->string kind) "/" (symbol->string name)
                                    "/" (required manifest 'schema-sha256)
                                    "/input/" (.get input digest)))
                                (required entry 'block)))
                   (published (.cc generated 'kind kind 'name name 'source origin
                                'provider address 'version version
                                'schema-digest (required manifest 'schema-sha256)
                                'input-digest (.get input digest)
                                'source-inputs (.get input source-inputs)
                                'value-type
                                (.cc (.get generated value-type)
                                  'schema (.get generated schema)
                                  'schema-artifact (.get generated schema-artifact)
                                  'source-inputs (.get input source-inputs)))))
              (hash-put! contracts key published)
              published))))
    (.cc (.o) 'status 'ready
         'provider address 'version version
         'schema-digest (required manifest 'schema-sha256)
         'artifact artifact
         'source origin
         'types
         (.o provider: (contract 'provider 'provider)
             resources:
             (object<-fun (cut contract <> 'resource)
               keys: (.call artifact .names 'resource))
             data:
             (object<-fun (cut contract <> 'data)
               keys: (.call artifact .names 'data)))
         '.contract contract
         '.find-contract
         (lambda (name kind)
           (or (hash-ref contracts (cons kind name) #f)
               (and (.call artifact .contains? name kind) (contract name kind))))
         '.contract-compile-count (lambda () (hash-length contracts))
         '.contract-cached? (lambda (name kind) (hash-key? contracts (cons kind name))))))


(def (agentic-ai-lab-opentofu-provider-from-directory directory)
  (let (artifact (agentic-ai-lab-opentofu-read-provider-artifact directory))
    (if (eq? (.get artifact status) 'ready)
      (provider-scope directory (.get artifact manifest) artifact)
      artifact)))

(def (required-provider directory)
  (unless (string? directory)
    (error "build-required: OpenTofu provider artifact has not been injected"))
  (let (scope (agentic-ai-lab-opentofu-provider-from-directory directory))
    (unless (eq? (.get scope status) 'ready)
      (error "build-required: OpenTofu provider artifact is incomplete" (.get scope missing)))
    scope))

;; The build/environment supplies config; bounded use-module merely binds this
;; lazy receiver. Neither module import nor alias binding reads the artifact.
(.def OpenTofuModule.
  config: OpenTofuProviderConfig
  provider: (required-provider (.get config provider-artifact))
  source: (.get provider source)
  types: (.get provider types))

;; Diagnostic composition preserves the child's exact path/constraint and adds
;; its original package SourceRef. It does not re-evaluate the candidate.
(def (configuration-diagnostic reason message path value source)
  (make-yuanxu-json-schema-validation-diagnostic
    'error reason message (yuanxu-json-schema-path->symbol path) value '()
    `((owner . opentofu/configuration) (path . ,path) (source . ,source))))

(def (configuration-child-diagnostic diagnostic prefix contract)
  (let* ((metadata (yuanxu-json-schema-validation-diagnostic-metadata diagnostic))
         (path (append prefix (yuanxu-contract-object-ref metadata 'path '()))))
    (make-yuanxu-json-schema-validation-diagnostic
      (yuanxu-json-schema-validation-diagnostic-severity diagnostic)
      (yuanxu-json-schema-validation-diagnostic-reason diagnostic)
      (yuanxu-json-schema-validation-diagnostic-message diagnostic)
      (yuanxu-json-schema-path->symbol path)
      (yuanxu-json-schema-validation-diagnostic-value diagnostic)
      (yuanxu-json-schema-validation-diagnostic-contract diagnostic)
      (append `((path . ,path) (source . ,(.get contract source))
                (contract-identity . ,(.get contract identity)))
              (filter (lambda (row) (not (memq (car row) '(path source contract-identity)))) metadata)))))

;; The local scope name owns its type prefix (aws_*, awscc_*, null_*).
;; Never probe every bound module to discover an owner. Provider alias and
;; explicit per-instance provider selection are not implemented by this rule.
(def (configuration-owner name)
  (let (parts (pregexp-match "^([^_]+)_" (symbol->string name)))
    (and parts (string->symbol (cadr parts)))))

;; Package demand is a projection of FINAL configuration keys, before any
;; Provider package is available. Never enumerate the package catalog or force
;; an instance value here. This is not configuration admission or a scheduler.
(def (configuration-build-inputs candidate)
  (def (keys value path)
    (cond ((object? value) (.all-slots value))
          ((hash-table? value) (map yuanxu-contract-key->symbol (hash-keys value)))
          ((list? value) (map (lambda (row) (yuanxu-contract-key->symbol (car row))) value))
          (else (error "invalid-opentofu-build-container" path))))
  (let* ((kinds (keys candidate '()))
         (owners (make-hash-table-eq))
         (requested-inputs
          (with-list-builder (emit)
            (for-each
             (lambda (kind)
               (unless (memq kind '(provider resource data))
                 (error "invalid-opentofu-build-section" (list kind)))
               (let (container (yuanxu-json-schema-candidate-slot candidate kind))
                 (for-each
                  (lambda (name)
                    (let (owner (if (eq? kind 'provider) name (configuration-owner name)))
                      (unless (and owner (pregexp-match "^[A-Za-z0-9_]+$" (symbol->string owner)))
                        (error "provider-binding-not-found" (list kind name)))
                      (hash-put! owners owner #t)
                      (emit (.o provider: owner path: (list kind name)))))
                  (keys container (list kind))))) kinds))))
    (.o providers: (list-sort string<? (map symbol->string (hash-keys owners)))
        demands: requested-inputs)))

(def (configuration-classify bindings candidate context)
  (let (envelope (.call ConfigurationEnvelopeContract .classify candidate context))
    (if (not (yuanxu-classification-evidence-accepted? envelope))
      (.cc envelope 'type-identity 'opentofu/configuration 'children '())
      (let ((failures '()) (children '()))
        (def (reject reason message path value source)
          (set! failures (cons (configuration-diagnostic reason message path value source) failures)))
        (def (resolve kind name)
          (let* ((owner (if (eq? kind 'provider) name (configuration-owner name)))
                 (path (list kind name)))
            (cond
              ((or (not owner) (not (.slot? bindings owner)))
               (reject 'provider-binding-not-found "No bound Provider scope for this configuration key"
                       path name #f)
               #f)
              (else
               (let* ((scope (.get (.ref bindings owner) provider))
                      (found (.call scope .find-contract (if (eq? kind 'provider) 'provider name) kind)))
                 (unless found
                   (reject 'provider-type-not-found "Type is absent from the bound Provider export"
                           path name (.get scope source)))
                 found)))))
        (def (admit contract value path)
          (let (result (.call contract .admit value context))
            (set! children (cons (.cc (.o) 'path path 'contract contract 'admission result) children))
            (unless (yuanxu-validation-evidence-accepted? result)
              (set! failures
                (append (reverse (map (cut configuration-child-diagnostic <> path contract)
                                      (.get result diagnostics))) failures)))))
        (def (visit kind)
          (for-each
            (lambda (row)
              (let* ((name (yuanxu-contract-key->symbol (car row)))
                     (contract (resolve kind name)))
                (when contract
                  (if (eq? kind 'provider)
                    (let loop ((values (yuanxu-contract-json-array->list (cdr row))) (index 0))
                      (unless (null? values)
                        (admit contract (car values) (list kind name index))
                        (loop (cdr values) (1+ index))))
                    (for-each
                      (lambda (instance)
                        (admit contract (cdr instance)
                               (list kind name (yuanxu-contract-key->symbol (car instance)))))
                      (yuanxu-json-schema-candidate-rows (cdr row)))))))
            (yuanxu-json-schema-candidate-rows
              (yuanxu-contract-object-ref
                (yuanxu-json-schema-candidate-rows candidate) kind '()))))
        (for-each visit '(provider resource data))
        (.cc (yuanxu-classification-evidence 'opentofu/configuration candidate
               (null? failures) (reverse failures) context)
             'children (reverse children))))))

;; A module-level native Contract; each admission discovers only the current
;; candidate's names. No SelectedTypes list or whole-catalog compilation.
(.def OpenTofuConfiguration.
  .build-inputs: configuration-build-inputs
  modules: (.o)
  types:
  (.o configuration:
      (.cc YuanxuContract. 'identity 'opentofu/configuration
           '.classify (cut configuration-classify modules <> <>))))

;; Enumerate only collection names. Creating/finding a leaf object never reads
;; its manifest, indexes or type inputs. object<-fun owns per-name laziness.
(def (artifact-modules directory)
  (unless (and (string? directory) (file-exists? directory))
    (error "build-required: OpenTofu artifact collection has not been injected"))
  (let (names (directory-files directory))
    (unless (every (cut pregexp-match "^[A-Za-z0-9_]+$" <>) names)
      (error "invalid-opentofu-artifact-collection-name" directory))
    (object<-fun
      (lambda (name)
        (.cc OpenTofuModule. 'config
          (.cc OpenTofuProviderConfig 'provider-artifact
            (string-append directory "/" (symbol->string name)))))
      keys: (map string->symbol names))))

(.def (OpenTofuScope. scope OpenTofuConfiguration.)
  config: Config
  modules: (artifact-modules (.get config artifact))
  ;; Both exports stay lazy while the source publication is still being linked.
  Null: (.o (:: @ NullExecution.)
          message: (let (settings (.get scope config services opentofu Null))
                     (if settings (.get settings message) (.get NullExecution. message)))
          provider: (.get scope modules null provider))
  types: =>.+ (.o config: OpenTofuConfigContract
                  Services: ServicesContract OpenTofu: OpenTofuContract
                  Null: (execution-admission (.get scope Null provider types resources null_resource)))
  prototypes: (.o provider: OpenTofuModule. configuration: OpenTofuConfiguration.
                   execution: OpenTofuExecution.)
  execution: opentofu-execution
  schema: (.o type: agentic-ai-lab-opentofu-cty->schema block: agentic-ai-lab-opentofu-block->schema)
  normalize: agentic-ai-lab-opentofu-normalize-block
  configuration-from-types: agentic-ai-lab-opentofu-configuration-from-types
  provider-from-directory: agentic-ai-lab-opentofu-provider-from-directory)
