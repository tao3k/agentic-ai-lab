;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable artifact policy owns the Scheme-side artifact/profile
;;; contract before runtime, database, and Marlin handoff layers consume it.
;;; Invariant: this module must keep profile objects POO-native while emitting
;;; stable bounded receipts for policy and parser-owned validation.
(import (only-in :clan/poo/object .o .ref)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-protocol
                 +runtime-request-schema+)
        (only-in :poo-flow/modules/workflow/control-plane/runtime-command-descriptor
                 runtime-command-fields->manifest)
        :poo-flow/modules/ai-agentic-context/features/memory/durable/artifact-profile
        :poo-flow/modules/ai-agentic-context/features/memory/durable/artifact-object
        :poo-flow/modules/ai-agentic-context/features/memory/durable/artifact-validation)

(export +poo-flow-durable-artifact-profile-kind+
        +poo-flow-durable-artifact-profile-schema+
        +poo-flow-durable-artifact-database-profile-kind+
        +poo-flow-durable-artifact-database-profile-schema+
        poo-flow-artifact-profile
        poo-flow-artifact-database-profile
        poo-flow-artifact-profile-extend
        poo-flow-artifact-profile-override
        poo-flow-artifact-profile-apply-hooks
        poo-flow-artifact-profile->alist
        poo-flow-artifact-database-profile->alist
        poo-flow-artifact-profile?
        poo-flow-artifact-database-profile?
        poo-flow-artifact-scope-contained?
        poo-flow-artifact-publish-gated?
        poo-flow-durable-artifact
        poo-flow-durable-artifact?
        poo-flow-durable-artifact->alist
        poo-flow-durable-artifact-visible?
        poo-flow-durable-artifact-lifecycle-transition-allowed?
        poo-flow-durable-artifact-transition
        poo-flow-durable-artifact-validate
        poo-flow-durable-artifact-policy-receipt?
        poo-flow-durable-artifact-policy-receipt-valid?
        poo-flow-durable-artifact-policy-receipt->alist
        make-poo-flow-durable-artifact-manifest-receipt
        poo-flow-durable-artifact-manifest-receipt?
        poo-flow-durable-artifact-manifest-receipt-valid?
        poo-flow-durable-artifact-manifest-receipt-diagnostics
        poo-flow-durable-artifact-manifest
        poo-flow-durable-artifact-manifest-receipt->alist
        poo-flow-durable-artifact-manifest->marlin-handoff
        artifact-profile
        database-profile
        durable-artifact
        artifact-module
        database-module)

(def +poo-flow-durable-artifact-manifest-receipt-kind+
  'poo-flow.durable.artifact.manifest-receipt)

(def +poo-flow-durable-artifact-manifest-receipt-schema+
  'poo-flow.durable.artifact.manifest-receipt.v1)

(def +poo-flow-durable-artifact-manifest-handoff-schema+
  'poo-flow.durable.artifact.marlin-handoff.v1)

(defstruct poo-flow-durable-artifact-manifest-receipt
  (manifest-id
   artifact-id
   artifact-kind
   storage-class
   lifecycle-state
   producer-ref
   owner-ref
   sandbox-scope
   policy-receipt
   artifact-row
   profile-row
   database-row
   valid?
   diagnostics
   metadata
   runtime-owner
   handoff-required
   runtime-executed)
  transparent: #t)

;; : (-> Alist Symbol Datum Datum)
(def (poo-flow-artifact-option-ref options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; : (-> Datum Alist [Symbol])
(def (poo-flow-artifact-manifest-diagnostics manifest-id policy-row)
  (append
   (if (symbol? manifest-id)
     '()
     (list 'artifact-manifest-id-must-be-symbol))
   (if (eq? (poo-flow-artifact-alist-ref policy-row 'valid? #f) #t)
     '()
     (list 'artifact-policy-receipt-invalid))))

;; : (-> PooDurableArtifact PooArtifactProfile PooArtifactDatabaseProfile [Alist] PooDurableArtifactManifestReceipt)
(def (poo-flow-durable-artifact-manifest artifact
                                         profile
                                         database-profile
                                         . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (policy-receipt
          (poo-flow-durable-artifact-validate artifact
                                              profile
                                              database-profile))
         (policy-row
          (poo-flow-durable-artifact-policy-receipt->alist policy-receipt))
         (manifest-id
          (poo-flow-artifact-option-ref
           options
           'manifest-id
           (list 'artifact-manifest (.ref artifact 'artifact-id))))
         (metadata
          (poo-flow-artifact-option-ref options 'metadata '()))
         (runtime-owner
          (poo-flow-artifact-option-ref options
                                        'runtime-owner
                                        "marlin-agent-core"))
         (diagnostics
          (poo-flow-artifact-manifest-diagnostics manifest-id policy-row))
         (valid-value
          (and (null? diagnostics)
               (eq? (poo-flow-artifact-alist-ref policy-row 'valid? #f) #t)
               #t)))
    (make-poo-flow-durable-artifact-manifest-receipt
     manifest-id
     (.ref artifact 'artifact-id)
     (.ref artifact 'artifact-kind)
     (.ref artifact 'storage-class)
     (.ref artifact 'lifecycle-state)
     (.ref artifact 'producer-ref)
     (.ref artifact 'owner-ref)
     (.ref artifact 'sandbox-scope)
     policy-row
     (poo-flow-durable-artifact->alist artifact)
     (poo-flow-artifact-profile->alist profile)
     (poo-flow-artifact-database-profile->alist database-profile)
     valid-value
     diagnostics
     metadata
     runtime-owner
     #t
     #f)))

;; : (-> PooDurableArtifactManifestReceipt Alist)
(def (poo-flow-durable-artifact-manifest-receipt->alist receipt)
  (list
   (cons 'kind +poo-flow-durable-artifact-manifest-receipt-kind+)
   (cons 'schema +poo-flow-durable-artifact-manifest-receipt-schema+)
   (cons 'manifest-id
         (poo-flow-durable-artifact-manifest-receipt-manifest-id receipt))
   (cons 'artifact-id
         (poo-flow-durable-artifact-manifest-receipt-artifact-id receipt))
   (cons 'artifact-kind
         (poo-flow-durable-artifact-manifest-receipt-artifact-kind receipt))
   (cons 'storage-class
         (poo-flow-durable-artifact-manifest-receipt-storage-class receipt))
   (cons 'lifecycle-state
         (poo-flow-durable-artifact-manifest-receipt-lifecycle-state receipt))
   (cons 'producer-ref
         (poo-flow-durable-artifact-manifest-receipt-producer-ref receipt))
   (cons 'owner-ref
         (poo-flow-durable-artifact-manifest-receipt-owner-ref receipt))
   (cons 'sandbox-scope
         (poo-flow-durable-artifact-manifest-receipt-sandbox-scope receipt))
   (cons 'policy-receipt
         (poo-flow-durable-artifact-manifest-receipt-policy-receipt receipt))
   (cons 'artifact-row
         (poo-flow-durable-artifact-manifest-receipt-artifact-row receipt))
   (cons 'profile-row
         (poo-flow-durable-artifact-manifest-receipt-profile-row receipt))
   (cons 'database-row
         (poo-flow-durable-artifact-manifest-receipt-database-row receipt))
   (cons 'valid?
         (poo-flow-durable-artifact-manifest-receipt-valid? receipt))
   (cons 'diagnostics
         (poo-flow-durable-artifact-manifest-receipt-diagnostics receipt))
   (cons 'diagnostic-count
         (length
          (poo-flow-durable-artifact-manifest-receipt-diagnostics receipt)))
   (cons 'metadata
         (poo-flow-durable-artifact-manifest-receipt-metadata receipt))
   (cons 'runtime-owner
         (poo-flow-durable-artifact-manifest-receipt-runtime-owner receipt))
   (cons 'handoff-required
         (poo-flow-durable-artifact-manifest-receipt-handoff-required receipt))
   (cons 'runtime-executed
         (poo-flow-durable-artifact-manifest-receipt-runtime-executed receipt))))

;;; Boundary: Marlin handoff projection preserves a stable manifest ABI while
;;; keeping provider-specific transport details outside durable policy objects.
;; : (-> PooDurableArtifactManifestReceipt [Alist] Alist)
(def (poo-flow-durable-artifact-manifest->marlin-handoff receipt
                                                           . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (manifest-row
          (poo-flow-durable-artifact-manifest-receipt->alist receipt))
         (operation
          (poo-flow-artifact-option-ref options
                                        'manifest-operation
                                        'durable-artifact-manifest))
         (command-executable
          (poo-flow-artifact-option-ref options
                                        'executable
                                        "marlin-artifact-store"))
         (command-arguments
          (poo-flow-artifact-option-ref options
                                        'arguments
                                        '("durable-artifact" "manifest")))
         (command-protocol
          (poo-flow-artifact-option-ref options
                                        'protocol
                                        'stdout-s-expression))
         (command-metadata
          (list
           (cons 'source 'poo-flow.durable.artifact.manifest)
           (cons 'artifact-id
                 (poo-flow-durable-artifact-manifest-receipt-artifact-id
                  receipt))
           (cons 'runtime-executed #f)))
         (envelope
          (list
           (cons 'schema +runtime-request-schema+)
           (cons 'runtime 'marlin)
           (cons 'operation operation)
           (cons 'request-id
                 (list 'poo-flow.durable.artifact.manifest
                       (poo-flow-durable-artifact-manifest-receipt-artifact-id
                        receipt)))
           (cons 'artifact-handle
                 (poo-flow-durable-artifact-manifest-receipt-artifact-id
                  receipt))
           (cons 'request
                 (list (cons 'artifact-manifest manifest-row)))
           (cons 'policy
                 (list
                  (cons 'runtime-owner
                        (poo-flow-durable-artifact-manifest-receipt-runtime-owner
                         receipt))
                  (cons 'handoff-required #t)
                  (cons 'runtime-executed #f)))
           (cons 'plan-id #f)
           (cons 'node-id
                 (poo-flow-durable-artifact-manifest-receipt-manifest-id
                  receipt))
           (cons 'frontier '())))
         (manifest
          (runtime-command-fields->manifest
           operation
           command-executable
           command-arguments
           command-protocol
           command-metadata
           envelope)))
    (list
     (cons 'kind 'poo-flow.durable.artifact.marlin-handoff)
     (cons 'schema +poo-flow-durable-artifact-manifest-handoff-schema+)
     (cons 'request-schema +runtime-request-schema+)
     (cons 'operation operation)
     (cons 'request-id (poo-flow-artifact-alist-ref manifest 'request-id #f))
     (cons 'artifact-id
           (poo-flow-durable-artifact-manifest-receipt-artifact-id receipt))
     (cons 'manifest-id
           (poo-flow-durable-artifact-manifest-receipt-manifest-id receipt))
     (cons 'runtime-owner
           (poo-flow-durable-artifact-manifest-receipt-runtime-owner receipt))
     (cons 'handoff-ready?
           (poo-flow-durable-artifact-manifest-receipt-valid? receipt))
     (cons 'artifact-manifest manifest-row)
     (cons 'runtime-command-manifest manifest)
     (cons 'runtime-executed #f)
     (cons 'runtime-parses-scheme-source #f)
     (cons 'scheme-manufactures-runtime-handlers #f))))

;;; Boundary: this macro expands user artifact-profile syntax into runtime POO
;;; profile construction without leaking syntax-phase witnesses.
;; artifact-profile
;; : (-> Syntax DurableArtifactProfileExpansionSyntax)
;; | doc m%
;;   Expand an artifact profile declaration into a POO-native durable artifact
;;   profile, optionally applying profile hooks.
;;   # Examples
;;   ```scheme
;;   (artifact-profile build outputs logs)
;;   ;; => artifact profile object
;;   ```
(defsyntax (artifact-profile stx)
  (syntax-case stx (:with)
    ((_ name section ... :with (hook ...))
     #'(poo-flow-artifact-profile-apply-hooks
        (poo-flow-artifact-profile 'name '(section ...))
        (list hook ...)))
    ((_ name section ... :with hook)
     #'(hook (poo-flow-artifact-profile 'name '(section ...))))
    ((_ name section ...)
     #'(poo-flow-artifact-profile 'name '(section ...)))))

;;; Boundary: this macro preserves the database-profile expansion shape that
;;; durable artifact policy validation and handoff code expect.
;; database-profile
;; : (-> Syntax DurableDatabaseProfileExpansionSyntax)
;; | doc m%
;;   Expand a durable database profile declaration for checkpoint and receipt stores.
;;   # Examples
;;   ```scheme
;;   (database-profile project checkpoints receipts)
;;   ;; => database profile object
;;   ```
(defsyntax (database-profile stx)
  (syntax-case stx ()
    ((_ name section ...)
     #'(poo-flow-artifact-database-profile 'name '(section ...)))))

;;; Boundary: this macro keeps durable-artifact authoring syntax hygienic while
;;; lowering to explicit runtime artifact object construction.
;; durable-artifact
;; : (-> Syntax DurableArtifactExpansionSyntax)
;; | doc m%
;;   Expand a durable artifact declaration into the policy object used by
;;   artifact validation and runtime manifest projection.
;;   # Examples
;;   ```scheme
;;   (durable-artifact build-log location retention visibility)
;;   ;; => durable artifact object
;;   ```
(defsyntax (durable-artifact stx)
  (syntax-case stx ()
    ((_ artifact-id section ...)
     #'(poo-flow-durable-artifact 'artifact-id '(section ...)))))

;;; Boundary: artifact-module preserves grouped artifact profile expansion as a
;;; single POO object namespace for module loader consumption.
;; artifact-module
;; : (-> Syntax DurableArtifactModuleExpansionSyntax)
;; | doc m%
;;   Expand a group of artifact profile declarations into one POO module object.
;;   # Examples
;;   ```scheme
;;   (artifact-module (_ build outputs) (_ test reports))
;;   ;; => artifact module object
;;   ```
(defsyntax (artifact-module stx)
  (syntax-case stx ()
    ((_ (_ name section ...) ...)
     #'(.o (name (artifact-profile name section ...)) ...))))

;;; Boundary: database-module preserves grouped database profile expansion as a
;;; single POO object namespace for durable artifact policy.
;; database-module
;; : (-> Syntax DurableDatabaseModuleExpansionSyntax)
;; | doc m%
;;   Expand a group of database profile declarations into one POO module object.
;;   # Examples
;;   ```scheme
;;   (database-module (_ project checkpoints) (_ session events))
;;   ;; => database module object
;;   ```
(defsyntax (database-module stx)
  (syntax-case stx ()
    ((_ (_ name section ...) ...)
     #'(.o (name (database-profile name section ...)) ...))))
