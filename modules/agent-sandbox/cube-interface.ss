;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: CubeSandbox interface projection lives in this backend leaf.
;;; Boundary: this module emits API lifecycle manifests only.
;;; Runtime contract: Marlin owns Cube API calls, remote sessions, and snapshots.
;;; Policy evidence: Cube interface tests assert descriptor override and gates.

(import (only-in :clan/poo/object .ref object?)
        (only-in :poo-flow/modules/workflow/control-plane/roles execution-policy-role)
        (only-in :poo-flow/modules/workflow/control-plane/failure raise-control-plane-failure)
        :core/object-family/role-syntax
        :poo-flow/modules/agent-sandbox/alist
        :poo-flow/modules/agent-sandbox/projection-syntax
        :poo-flow/modules/agent-sandbox/profile
        :poo-flow/modules/agent-sandbox/bridge)

(export +cube-interface-schema+
        +cube-interface-api-compatibilities+
        +cube-interface-network-modes+
        +cube-interface-mount-modes+
        +cube-interface-lifecycle-operations+
        cube-interface-descriptor-prototype
        make-cube-interface-descriptor
        cube-interface-descriptor?
        cube-interface-descriptor-name
        cube-interface-descriptor-backend-kind
        cube-interface-descriptor-api-compatibility
        cube-interface-descriptor-runtime-owner
        cube-interface-descriptor-lifecycle-operations
        cube-interface-descriptor-network-modes
        cube-interface-descriptor-mount-modes
        cube-interface-descriptor->contract
        cube-interface-descriptor-validation-errors
        cube-interface-validate-descriptor
        cube-interface-runtime-manifest-validation-errors
        cube-interface-validate-runtime-manifest
        cube-interface-runtime-manifest->manifest
        agent-sandbox-request->cube-interface-manifest
        agent-sandbox-execution-request->cube-interface-manifest)

;;; Cube interface schema is separate from the neutral runtime manifest because
;;; Marlin needs backend lifecycle semantics, not only process/filesystem fields.
;; : Symbol
(def +cube-interface-schema+ 'poo-flow.agent-sandbox-cube-interface.v1)

;;; API compatibility names the runtime surface Marlin should bind to. Today it
;;; is E2B-compatible; future Cube-native APIs can override this descriptor slot.
;; : [Symbol]
(def +cube-interface-api-compatibilities+
  '(e2b-compatible cube-native))

;;; Cube network policy is API-level policy. These symbols remain declarative;
;;; Marlin maps them to the provider-specific network controls.
;; : [Symbol]
(def +cube-interface-network-modes+
  '(egress-filtered blocked allow-all proxy-only))

;;; Mount modes are the filesystem grants this Scheme layer can validate before
;;; Marlin turns them into remote workspace upload or mount calls.
;; : [Symbol]
(def +cube-interface-mount-modes+
  '(read write read-write))

;;; Lifecycle operations are stable operation names, not function symbols.
;;; The ordered plan lets Marlin replay request setup without reading Gerbil
;;; request internals or guessing where snapshot/resume belongs.
;; : [Alist]
(def +cube-interface-lifecycle-operations+
  '(((stage . resolve-template)
     (operation . cube.template.resolve))
    ((stage . create-sandbox)
     (operation . cube.sandbox.create))
    ((stage . start-sandbox)
     (operation . cube.sandbox.start))
    ((stage . mount-filesystem)
     (operation . cube.filesystem.mount))
    ((stage . exec-process)
     (operation . cube.process.exec))
    ((stage . fetch-output)
     (operation . cube.output.fetch))
    ((stage . snapshot)
     (operation . cube.snapshot.create))
    ((stage . resume)
     (operation . cube.sandbox.resume))
    ((stage . destroy)
     (operation . cube.sandbox.destroy))))

;;; Validator slot delegates back to the public descriptor gate so POO override
;;; paths and direct calls share the same failure vocabulary.
;; : (-> CubeInterfaceDescriptor CubeInterfaceDescriptor)
(def (cube-interface-descriptor-validator descriptor)
  (cube-interface-validate-descriptor descriptor))

;;; Membership normalizes `memq`'s tail result into a strict boolean for field
;;; validators that are consumed by generic required-field checks.
;; : (-> CubeInterfaceEnumCandidate [Symbol] Boolean)
(def (cube-interface-member? value allowed)
  (and (memq value allowed) #t))

;;; Schema validation pins Cube manifests to this backend contract version.
;; : (-> CubeInterfaceSchemaCandidate Boolean)
(def (cube-interface-schema? value)
  (eq? value +cube-interface-schema+))

;;; Generic presence accepts any non-false descriptor value because some slots
;;; are symbols while others are lists or backend-owned payloads.
;; : (-> CubeInterfaceRequiredFieldCandidate Boolean)
(def (cube-interface-present? value)
  (and value #t))

;; : (-> Symbol Symbol ValidationError)
(def (cube-interface-validation-error field code)
  (agent-sandbox-field-rows
   (field field)
   (code code)))

;; : (-> Symbol Integer Symbol ValidationError)
(def (cube-interface-indexed-validation-error field index code)
  (agent-sandbox-field-rows
   (field field)
   (index index)
   (code code)))

;; : (-> Symbol Integer Value Symbol ValidationError)
(def (cube-interface-indexed-value-validation-error field index value code)
  (agent-sandbox-field-rows
   (field field)
   (index index)
   (value value)
   (code code)))

;;; Cube interface descriptors are backend-specific and must not validate for
;;; non-Cube profile descriptors.
;; : (-> CubeInterfaceBackendKindCandidate Boolean)
(def (cube-interface-backend-kind? value)
  (eq? value 'cube))

;;; API compatibility is descriptor-owned so future Cube-native APIs can be
;;; added without changing the neutral sandbox bridge.
;; : (-> CubeInterfaceApiCompatibilityCandidate Boolean)
(def (cube-interface-api-compatibility? value)
  (cube-interface-member? value +cube-interface-api-compatibilities+))

;;; Runtime ownership is fixed at this boundary: Scheme emits lifecycle data,
;;; while Marlin performs the provider calls.
;; : (-> CubeInterfaceRuntimeOwnerCandidate Boolean)
(def (cube-interface-runtime-owner? value)
  (eq? value 'marlin))

;;; Lifecycle operations must be a non-empty ordered plan; individual operation
;;; payloads remain backend vocabulary validated by runtime adapters.
;; : (-> CubeInterfaceLifecycleOperationsCandidate Boolean)
(def (cube-interface-lifecycle-operations? value)
  (and (list? value)
       (pair? value)))

;;; Runtime manifest schema must already be normalized by the neutral sandbox
;;; bridge before Cube-specific lifecycle projection begins.
;; : (-> CubeInterfaceRuntimeSchemaCandidate Boolean)
(def (cube-interface-runtime-schema? value)
  (eq? value +agent-sandbox-runtime-manifest-schema+))

;;; Runtime backend gates this projector to Cube manifests only.
;; : (-> CubeInterfaceRuntimeBackendCandidate Boolean)
(def (cube-interface-runtime-backend? value)
  (eq? value 'cube))

;;; Runtime backend refs may be provider ids or richer opaque handles, so the
;;; Cube gate only requires a non-false value.
;; : (-> CubeInterfaceRuntimeRefCandidate Boolean)
(def (cube-interface-runtime-ref? value)
  (and value #t))

;;; Process commands are runtime-owned payloads; Scheme only verifies presence
;;; before serializing the lifecycle plan.
;; : (-> CubeInterfaceRuntimeCommandCandidate Boolean)
(def (cube-interface-runtime-command? value)
  (and value #t))

;;; Cube interface descriptors are POO policy objects so API compatibility and
;;; lifecycle operation names can be overridden without changing request shape.
;; : CubeInterfaceDescriptorPrototype
(def cube-interface-descriptor-prototype
  (poo-core-role-object
   (slots ((schema +cube-interface-schema+)
           (name 'cube-interface)
           (backend-kind 'cube)
           (api-compatibility 'e2b-compatible)
           (runtime-owner 'marlin)
           (lifecycle-operations
            +cube-interface-lifecycle-operations+)
           (network-modes +cube-interface-network-modes+)
           (mount-modes +cube-interface-mount-modes+)
           (validator
            cube-interface-descriptor-validator)))
   (supers execution-policy-role)))

;;; Descriptor construction is the extension override point for local Cube API
;;; variants; default construction remains enough for the Tencent Cube profile.
;; : (-> [Alist] CubeInterfaceDescriptor)
(def (make-cube-interface-descriptor . maybe-overrides)
  (poo-core-role-object
   (slot-rows (if (null? maybe-overrides) '() (car maybe-overrides)))
   (supers cube-interface-descriptor-prototype)))

;; : (-> CubeInterfaceDescriptorCandidate Boolean)
(def (cube-interface-descriptor? descriptor)
  (object? descriptor))

;;; Descriptor slots are read dynamically because backend interface descriptors
;;; are POO objects with override precedence, not fixed records.
;; : (-> CubeInterfaceDescriptor Symbol Value Value)
(def (cube-interface-descriptor-slot descriptor slot default)
  (if (cube-interface-descriptor? descriptor)
    (.ref descriptor slot)
    default))

;; : (-> CubeInterfaceDescriptor Symbol)
(def (cube-interface-descriptor-name descriptor)
  (cube-interface-descriptor-slot descriptor 'name #f))

;; : (-> CubeInterfaceDescriptor Symbol)
(def (cube-interface-descriptor-backend-kind descriptor)
  (cube-interface-descriptor-slot descriptor 'backend-kind #f))

;; : (-> CubeInterfaceDescriptor Symbol)
(def (cube-interface-descriptor-api-compatibility descriptor)
  (cube-interface-descriptor-slot descriptor 'api-compatibility #f))

;; : (-> CubeInterfaceDescriptor Symbol)
(def (cube-interface-descriptor-runtime-owner descriptor)
  (cube-interface-descriptor-slot descriptor 'runtime-owner #f))

;; : (-> CubeInterfaceDescriptor [Alist])
(def (cube-interface-descriptor-lifecycle-operations descriptor)
  (cube-interface-descriptor-slot descriptor 'lifecycle-operations '()))

;; : (-> CubeInterfaceDescriptor [Symbol])
(def (cube-interface-descriptor-network-modes descriptor)
  (cube-interface-descriptor-slot descriptor 'network-modes '()))

;; : (-> CubeInterfaceDescriptor [Symbol])
(def (cube-interface-descriptor-mount-modes descriptor)
  (cube-interface-descriptor-slot descriptor 'mount-modes '()))

;;; Descriptor contracts are the serializable API surface that Marlin should
;;; read before interpreting Cube lifecycle plans.
;; : (-> CubeInterfaceDescriptor Alist)
(def (cube-interface-descriptor->contract descriptor)
  (let (valid-descriptor (cube-interface-validate-descriptor descriptor))
    (agent-sandbox-field-rows
     (schema +cube-interface-schema+)
     (name (cube-interface-descriptor-name valid-descriptor))
     (backend-kind
      (cube-interface-descriptor-backend-kind valid-descriptor))
     (api-compatibility
      (cube-interface-descriptor-api-compatibility valid-descriptor))
     (runtime-owner
      (cube-interface-descriptor-runtime-owner valid-descriptor))
     (lifecycle-operations
      (cube-interface-descriptor-lifecycle-operations
       valid-descriptor))
     (network-modes
      (cube-interface-descriptor-network-modes valid-descriptor))
     (mount-modes
      (cube-interface-descriptor-mount-modes valid-descriptor)))))

;;; Descriptor validation prevents drift between Cube profile defaults and the
;;; backend interface contract consumed by Marlin.
;; : (-> CubeInterfaceDescriptor [ValidationError])
(def (cube-interface-descriptor-validation-errors descriptor)
  (if (cube-interface-descriptor? descriptor)
    (agent-sandbox-required-field-errors
     (agent-sandbox-field-rows
      (schema
       (cube-interface-descriptor-slot descriptor 'schema #f))
      (name (cube-interface-descriptor-name descriptor))
      (backend-kind
       (cube-interface-descriptor-backend-kind descriptor))
      (api-compatibility
       (cube-interface-descriptor-api-compatibility descriptor))
      (runtime-owner
       (cube-interface-descriptor-runtime-owner descriptor))
      (lifecycle-operations
       (cube-interface-descriptor-lifecycle-operations
        descriptor)))
     (list (cons 'schema
                 cube-interface-schema?)
           (cons 'name cube-interface-present?)
           (cons 'backend-kind cube-interface-backend-kind?)
           (cons 'api-compatibility cube-interface-api-compatibility?)
           (cons 'runtime-owner cube-interface-runtime-owner?)
           (cons 'lifecycle-operations
                 cube-interface-lifecycle-operations?)))
    (list (cube-interface-validation-error 'descriptor 'not-poo-object))))

;;; Descriptor failures use typed control-plane errors so callers can recover by
;;; code and keep Cube API details out of Scheme exception strings.
;; : (-> CubeInterfaceDescriptor CubeInterfaceDescriptor)
(def (cube-interface-validate-descriptor descriptor)
  (let (errors (cube-interface-descriptor-validation-errors descriptor))
    (if (null? errors)
      descriptor
      (raise-control-plane-failure
       'agent-sandbox-cube
       'invalid-cube-interface-descriptor
       "invalid CubeSandbox interface descriptor"
       (agent-sandbox-field-rows
        (errors errors))))))

;;; Mount validation records indices so Marlin-facing failures identify exactly
;;; which remote workspace grant cannot be projected.
;; : (-> Mount Integer CubeInterfaceDescriptor [ValidationError])
(def (cube-interface-mount-validation-errors mount index descriptor)
  (if (list? mount)
    (let* ((path (agent-sandbox-alist-ref mount 'path #f))
           (mode (agent-sandbox-alist-ref mount 'mode #f)))
      (let* ((errors-rev
              (if (string? path)
                '()
                (list (cube-interface-indexed-validation-error
                       'mount-path
                       index
                       'missing-or-invalid-path))))
             (errors-rev
              (if (cube-interface-member?
                   mode
                   (cube-interface-descriptor-mount-modes descriptor))
                errors-rev
                (cons (cube-interface-indexed-value-validation-error
                       'mount-mode
                       index
                       mode
                       'unsupported-mount-mode)
                      errors-rev))))
        (reverse errors-rev)))
    (list (cube-interface-indexed-validation-error 'mount index 'not-alist))))

;;; Recursive mount validation keeps the original grant order because the
;;; lifecycle plan will preserve one remote mount operation per request mount.
;; : (-> [Mount] Integer CubeInterfaceDescriptor [ValidationError])
(def (cube-interface-mounts-validation-errors/rev mounts
                                                  index
                                                  descriptor
                                                  errors-rev)
  (if (null? mounts)
    errors-rev
    (cube-interface-mounts-validation-errors/rev
     (cdr mounts)
     (+ index 1)
     descriptor
     (agent-sandbox-rows-into/rev
      (cube-interface-mount-validation-errors (car mounts)
                                              index
                                              descriptor)
      errors-rev))))

;; : (-> [Mount] Integer CubeInterfaceDescriptor [ValidationError])
(def (cube-interface-mounts-validation-errors mounts index descriptor)
  (reverse
   (cube-interface-mounts-validation-errors/rev mounts
                                                index
                                                descriptor
                                                '())))

;;; Network validation is Cube-specific: the neutral bridge does not know which
;;; provider modes Marlin can map into remote sandbox networking.
;; : (-> NetworkPolicy CubeInterfaceDescriptor [ValidationError])
(def (cube-interface-network-validation-errors network-policy descriptor)
  (let (mode (agent-sandbox-alist-ref network-policy 'mode 'egress-filtered))
    (if (cube-interface-member?
         mode
         (cube-interface-descriptor-network-modes descriptor))
      '()
      (list (agent-sandbox-field-rows
             (field 'network-mode)
             (value mode)
             (code 'unsupported-network-mode))))))

;;; Runtime manifest validation is the backend gate before Marlin receives a
;;; Cube lifecycle manifest. It rejects non-Cube backends and unsupported policy.
;; : (-> RuntimeManifest CubeInterfaceDescriptor [ValidationError])
(def (cube-interface-runtime-manifest-validation-errors runtime-manifest
                                                       descriptor)
  (if (list? runtime-manifest)
    (let* ((backend (agent-sandbox-alist-ref runtime-manifest 'backend '()))
           (process (agent-sandbox-alist-ref runtime-manifest 'process '()))
           (filesystem (agent-sandbox-alist-ref runtime-manifest 'filesystem '()))
           (mounts (agent-sandbox-alist-ref filesystem 'mounts '()))
           (network-policy
            (agent-sandbox-alist-ref runtime-manifest 'network-policy '())))
      (let* ((errors-rev
              (agent-sandbox-rows-into/rev
               (agent-sandbox-required-field-errors
                runtime-manifest
                (list (cons 'schema
                            cube-interface-runtime-schema?)))
               '()))
             (errors-rev
              (agent-sandbox-rows-into/rev
               (agent-sandbox-required-field-errors
                backend
                (list (cons 'kind cube-interface-runtime-backend?)
                      (cons 'ref cube-interface-runtime-ref?)))
               errors-rev))
             (errors-rev
              (agent-sandbox-rows-into/rev
               (agent-sandbox-required-field-errors
                process
                (list (cons 'command cube-interface-runtime-command?)
                      (cons 'argv list?)))
               errors-rev))
             (errors-rev
              (agent-sandbox-rows-into/rev
               (if (list? mounts)
                 (cube-interface-mounts-validation-errors mounts 0 descriptor)
                 (list (cube-interface-validation-error 'mounts 'not-list)))
               errors-rev))
             (errors-rev
              (agent-sandbox-rows-into/rev
               (cube-interface-network-validation-errors network-policy descriptor)
               errors-rev)))
        (reverse errors-rev)))
    (list (cube-interface-validation-error 'runtime-manifest 'not-alist))))

;;; Validation preserves the original manifest in failure details so bridge
;;; tests and Marlin adapters can inspect the rejected policy.
;; : (-> RuntimeManifest [CubeInterfaceDescriptor] AgentSandboxRuntimeManifest)
(def (cube-interface-validate-runtime-manifest runtime-manifest
                                              . maybe-descriptor)
  (let* ((descriptor
          (cube-interface-validate-descriptor
           (if (null? maybe-descriptor)
             (make-cube-interface-descriptor)
             (car maybe-descriptor))))
         (errors
          (cube-interface-runtime-manifest-validation-errors runtime-manifest
                                                            descriptor)))
    (if (null? errors)
      runtime-manifest
      (raise-control-plane-failure
       'agent-sandbox-cube
       'invalid-cube-interface-manifest
       "invalid CubeSandbox interface manifest"
       (agent-sandbox-field-rows
        (errors errors)
        (runtime-manifest runtime-manifest))))))

;; : (-> RuntimeManifest CubeInterfaceDescriptor Alist)
(def (cube-interface-template runtime-manifest descriptor)
  (let (backend (agent-sandbox-alist-ref runtime-manifest 'backend '()))
    (agent-sandbox-field-rows
     (ref (agent-sandbox-alist-ref backend 'ref #f))
     (api-compatibility
      (cube-interface-descriptor-api-compatibility descriptor)))))

;; : (-> RuntimeManifest Alist)
(def (cube-interface-snapshot-policy runtime-manifest)
  (let (resource-policy
        (agent-sandbox-alist-ref runtime-manifest 'resource-policy '()))
    (agent-sandbox-field-rows
     (snapshot
      (agent-sandbox-alist-ref resource-policy 'snapshot #f))
     (resume
      (agent-sandbox-alist-ref resource-policy 'resume #f)))))

;; : (-> LifecycleOperation RuntimeManifest CubeInterfaceDescriptor Alist)
(def (cube-interface-lifecycle-step operation runtime-manifest descriptor)
  (let ((stage (agent-sandbox-alist-ref operation 'stage #f))
        (resource-policy
         (agent-sandbox-alist-ref runtime-manifest 'resource-policy '())))
    (agent-sandbox-rows/tail
     operation
     (cond
      ((eq? stage 'resolve-template)
       (agent-sandbox-field-rows
        (template
         (cube-interface-template runtime-manifest descriptor))))
      ((eq? stage 'exec-process)
       (agent-sandbox-field-rows
        (process
         (agent-sandbox-alist-ref runtime-manifest 'process '()))))
      ((eq? stage 'mount-filesystem)
       (agent-sandbox-field-rows
        (filesystem
         (agent-sandbox-alist-ref runtime-manifest 'filesystem '()))))
      ((eq? stage 'snapshot)
       (agent-sandbox-field-rows
        (policy
         (agent-sandbox-alist-ref resource-policy 'snapshot #f))))
      ((eq? stage 'resume)
       (agent-sandbox-field-rows
        (policy
         (agent-sandbox-alist-ref resource-policy 'resume #f))))
      (else '())))))

;; : (-> RuntimeManifest CubeInterfaceDescriptor Procedure)
(def (cube-interface-lifecycle-step-mapper runtime-manifest descriptor)
  (lambda (operation)
    (cube-interface-lifecycle-step operation runtime-manifest descriptor)))

;;; Lifecycle plans are pure data transforms over validated manifests. Each
;;; operation is annotated with the request subset Marlin needs for that phase.
;; : (-> RuntimeManifest CubeInterfaceDescriptor [Alist])
(def (cube-interface-lifecycle-plan runtime-manifest descriptor)
  (map (cube-interface-lifecycle-step-mapper runtime-manifest descriptor)
       (cube-interface-descriptor-lifecycle-operations descriptor)))

;;; Final projection packages Cube API compatibility, lifecycle operations, and
;;; neutral request policy into one Marlin-facing manifest.
;; : (-> AgentSandboxRuntimeManifest [CubeInterfaceDescriptor] CubeInterfaceManifest)
(def (cube-interface-runtime-manifest->manifest runtime-manifest
                                                . maybe-descriptor)
  (let* ((descriptor
          (cube-interface-validate-descriptor
           (if (null? maybe-descriptor)
             (make-cube-interface-descriptor)
             (car maybe-descriptor))))
         (valid-manifest
          (cube-interface-validate-runtime-manifest runtime-manifest
                                                    descriptor))
         (backend (agent-sandbox-alist-ref valid-manifest 'backend '()))
         (process (agent-sandbox-alist-ref valid-manifest 'process '()))
         (filesystem (agent-sandbox-alist-ref valid-manifest 'filesystem '()))
         (network-policy
          (agent-sandbox-alist-ref valid-manifest 'network-policy '())))
    (agent-sandbox-field-rows
     (schema +cube-interface-schema+)
     (interface
      (cube-interface-descriptor->contract descriptor))
     (runtime-schema
      (agent-sandbox-alist-ref valid-manifest 'schema #f))
     (backend backend)
     (template
      (cube-interface-template valid-manifest descriptor))
     (process process)
     (filesystem filesystem)
     (network-policy network-policy)
     (capabilities
      (agent-sandbox-alist-ref valid-manifest 'capabilities '()))
     (resource-policy
      (agent-sandbox-alist-ref valid-manifest 'resource-policy '()))
     (snapshot-policy
      (cube-interface-snapshot-policy valid-manifest))
     (lifecycle-plan
      (cube-interface-lifecycle-plan valid-manifest descriptor))
     (output-policy
      (agent-sandbox-alist-ref valid-manifest 'output-policy #f))
     (metadata
      (agent-sandbox-alist-ref valid-manifest 'metadata '())))))

;;; Request projection lets Scheme callers ask for a Cube interface manifest
;;; without constructing a runtime envelope first.
;; : (-> AgentSandboxRequest [CubeInterfaceDescriptor] CubeInterfaceManifest)
(def (agent-sandbox-request->cube-interface-manifest request
                                                     . maybe-descriptor)
  (apply cube-interface-runtime-manifest->manifest
         (agent-sandbox-request->runtime-manifest request)
         maybe-descriptor))

;;; Execution-request projection reuses the bridge envelope so Cube interface
;;; manifests and Marlin request envelopes stay aligned.
;; : (-> ExecutionRequest [CubeInterfaceDescriptor] CubeInterfaceManifest)
(def (agent-sandbox-execution-request->cube-interface-manifest request
                                                               . maybe-descriptor)
  (let (runtime-manifest
        (agent-sandbox-alist-ref
         (make-agent-sandbox-bridge-envelope request)
         'runtime-manifest
         #f))
    (apply cube-interface-runtime-manifest->manifest
           runtime-manifest
           maybe-descriptor)))
