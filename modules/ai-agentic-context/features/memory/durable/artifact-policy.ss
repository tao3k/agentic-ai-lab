;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: durable artifact policy owns the Scheme-side artifact/profile
;;; contract before runtime, database, and Marlin handoff layers consume it.
;;; Invariant: this module must keep profile objects POO-native while emitting
;;; stable bounded receipts for policy and parser-owned validation.
(import (only-in :clan/poo/object .o .ref)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-protocol
                 +runtime-request-schema+)
        (only-in :yuanxu/modules/funflow/control-plane/runtime-command-descriptor
                 runtime-command-fields->manifest)
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/artifact-profile
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/artifact-object
        :agentic-ai-lab/modules/ai-agentic-context/features/memory/durable/artifact-validation)

(export +agentic-ai-lab-durable-artifact-profile-kind+
        +agentic-ai-lab-durable-artifact-profile-schema+
        +agentic-ai-lab-durable-artifact-database-profile-kind+
        +agentic-ai-lab-durable-artifact-database-profile-schema+
        agentic-ai-lab-artifact-profile
        agentic-ai-lab-artifact-database-profile
        agentic-ai-lab-artifact-profile-extend
        agentic-ai-lab-artifact-profile-override
        agentic-ai-lab-artifact-profile-apply-hooks
        agentic-ai-lab-artifact-profile->alist
        agentic-ai-lab-artifact-database-profile->alist
        agentic-ai-lab-artifact-profile?
        agentic-ai-lab-artifact-database-profile?
        agentic-ai-lab-artifact-scope-contained?
        agentic-ai-lab-artifact-publish-gated?
        agentic-ai-lab-durable-artifact
        agentic-ai-lab-durable-artifact?
        agentic-ai-lab-durable-artifact->alist
        agentic-ai-lab-durable-artifact-visible?
        agentic-ai-lab-durable-artifact-lifecycle-transition-allowed?
        agentic-ai-lab-durable-artifact-transition
        agentic-ai-lab-durable-artifact-validate
        agentic-ai-lab-durable-artifact-policy-receipt?
        agentic-ai-lab-durable-artifact-policy-receipt-valid?
        agentic-ai-lab-durable-artifact-policy-receipt->alist
        make-agentic-ai-lab-durable-artifact-manifest-receipt
        agentic-ai-lab-durable-artifact-manifest-receipt?
        agentic-ai-lab-durable-artifact-manifest-receipt-valid?
        agentic-ai-lab-durable-artifact-manifest-receipt-diagnostics
        agentic-ai-lab-durable-artifact-manifest
        agentic-ai-lab-durable-artifact-manifest-receipt->alist
        agentic-ai-lab-durable-artifact-manifest->marlin-handoff
        artifact-profile
        database-profile
        durable-artifact
        artifact-module
        database-module)

(def +agentic-ai-lab-durable-artifact-manifest-receipt-kind+
  'agentic-ai-lab.durable.artifact.manifest-receipt)

(def +agentic-ai-lab-durable-artifact-manifest-receipt-schema+
  'agentic-ai-lab.durable.artifact.manifest-receipt.v1)

(def +agentic-ai-lab-durable-artifact-manifest-handoff-schema+
  'agentic-ai-lab.durable.artifact.marlin-handoff.v1)

(defstruct agentic-ai-lab-durable-artifact-manifest-receipt
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
(def (agentic-ai-lab-artifact-option-ref options key default-value)
  (let (entry (assoc key options))
    (if entry (cdr entry) default-value)))

;; : (-> Datum Alist [Symbol])
(def (agentic-ai-lab-artifact-manifest-diagnostics manifest-id policy-row)
  (append
   (if (symbol? manifest-id)
     '()
     (list 'artifact-manifest-id-must-be-symbol))
   (if (eq? (agentic-ai-lab-artifact-alist-ref policy-row 'valid? #f) #t)
     '()
     (list 'artifact-policy-receipt-invalid))))

;; : (-> PooDurableArtifact PooArtifactProfile PooArtifactDatabaseProfile [Alist] PooDurableArtifactManifestReceipt)
(def (agentic-ai-lab-durable-artifact-manifest artifact
                                         profile
                                         database-profile
                                         . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (policy-receipt
          (agentic-ai-lab-durable-artifact-validate artifact
                                              profile
                                              database-profile))
         (policy-row
          (agentic-ai-lab-durable-artifact-policy-receipt->alist policy-receipt))
         (manifest-id
          (agentic-ai-lab-artifact-option-ref
           options
           'manifest-id
           (list 'artifact-manifest (.ref artifact 'artifact-id))))
         (metadata
          (agentic-ai-lab-artifact-option-ref options 'metadata '()))
         (runtime-owner
          (agentic-ai-lab-artifact-option-ref options
                                        'runtime-owner
                                        "marlin-agent-core"))
         (diagnostics
          (agentic-ai-lab-artifact-manifest-diagnostics manifest-id policy-row))
         (valid-value
          (and (null? diagnostics)
               (eq? (agentic-ai-lab-artifact-alist-ref policy-row 'valid? #f) #t)
               #t)))
    (make-agentic-ai-lab-durable-artifact-manifest-receipt
     manifest-id
     (.ref artifact 'artifact-id)
     (.ref artifact 'artifact-kind)
     (.ref artifact 'storage-class)
     (.ref artifact 'lifecycle-state)
     (.ref artifact 'producer-ref)
     (.ref artifact 'owner-ref)
     (.ref artifact 'sandbox-scope)
     policy-row
     (agentic-ai-lab-durable-artifact->alist artifact)
     (agentic-ai-lab-artifact-profile->alist profile)
     (agentic-ai-lab-artifact-database-profile->alist database-profile)
     valid-value
     diagnostics
     metadata
     runtime-owner
     #t
     #f)))

;; : (-> PooDurableArtifactManifestReceipt Alist)
(def (agentic-ai-lab-durable-artifact-manifest-receipt->alist receipt)
  (list
   (cons 'kind +agentic-ai-lab-durable-artifact-manifest-receipt-kind+)
   (cons 'schema +agentic-ai-lab-durable-artifact-manifest-receipt-schema+)
   (cons 'manifest-id
         (agentic-ai-lab-durable-artifact-manifest-receipt-manifest-id receipt))
   (cons 'artifact-id
         (agentic-ai-lab-durable-artifact-manifest-receipt-artifact-id receipt))
   (cons 'artifact-kind
         (agentic-ai-lab-durable-artifact-manifest-receipt-artifact-kind receipt))
   (cons 'storage-class
         (agentic-ai-lab-durable-artifact-manifest-receipt-storage-class receipt))
   (cons 'lifecycle-state
         (agentic-ai-lab-durable-artifact-manifest-receipt-lifecycle-state receipt))
   (cons 'producer-ref
         (agentic-ai-lab-durable-artifact-manifest-receipt-producer-ref receipt))
   (cons 'owner-ref
         (agentic-ai-lab-durable-artifact-manifest-receipt-owner-ref receipt))
   (cons 'sandbox-scope
         (agentic-ai-lab-durable-artifact-manifest-receipt-sandbox-scope receipt))
   (cons 'policy-receipt
         (agentic-ai-lab-durable-artifact-manifest-receipt-policy-receipt receipt))
   (cons 'artifact-row
         (agentic-ai-lab-durable-artifact-manifest-receipt-artifact-row receipt))
   (cons 'profile-row
         (agentic-ai-lab-durable-artifact-manifest-receipt-profile-row receipt))
   (cons 'database-row
         (agentic-ai-lab-durable-artifact-manifest-receipt-database-row receipt))
   (cons 'valid?
         (agentic-ai-lab-durable-artifact-manifest-receipt-valid? receipt))
   (cons 'diagnostics
         (agentic-ai-lab-durable-artifact-manifest-receipt-diagnostics receipt))
   (cons 'diagnostic-count
         (length
          (agentic-ai-lab-durable-artifact-manifest-receipt-diagnostics receipt)))
   (cons 'metadata
         (agentic-ai-lab-durable-artifact-manifest-receipt-metadata receipt))
   (cons 'runtime-owner
         (agentic-ai-lab-durable-artifact-manifest-receipt-runtime-owner receipt))
   (cons 'handoff-required
         (agentic-ai-lab-durable-artifact-manifest-receipt-handoff-required receipt))
   (cons 'runtime-executed
         (agentic-ai-lab-durable-artifact-manifest-receipt-runtime-executed receipt))))

;;; Boundary: Marlin handoff projection preserves a stable manifest ABI while
;;; keeping provider-specific transport details outside durable policy objects.
;; : (-> PooDurableArtifactManifestReceipt [Alist] Alist)
(def (agentic-ai-lab-durable-artifact-manifest->marlin-handoff receipt
                                                           . maybe-options)
  (let* ((options (if (null? maybe-options) '() (car maybe-options)))
         (manifest-row
          (agentic-ai-lab-durable-artifact-manifest-receipt->alist receipt))
         (operation
          (agentic-ai-lab-artifact-option-ref options
                                        'manifest-operation
                                        'durable-artifact-manifest))
         (command-executable
          (agentic-ai-lab-artifact-option-ref options
                                        'executable
                                        "marlin-artifact-store"))
         (command-arguments
          (agentic-ai-lab-artifact-option-ref options
                                        'arguments
                                        '("durable-artifact" "manifest")))
         (command-protocol
          (agentic-ai-lab-artifact-option-ref options
                                        'protocol
                                        'stdout-s-expression))
         (command-metadata
          (list
           (cons 'source 'agentic-ai-lab.durable.artifact.manifest)
           (cons 'artifact-id
                 (agentic-ai-lab-durable-artifact-manifest-receipt-artifact-id
                  receipt))
           (cons 'runtime-executed #f)))
         (envelope
          (list
           (cons 'schema +runtime-request-schema+)
           (cons 'runtime 'marlin)
           (cons 'operation operation)
           (cons 'request-id
                 (list 'agentic-ai-lab.durable.artifact.manifest
                       (agentic-ai-lab-durable-artifact-manifest-receipt-artifact-id
                        receipt)))
           (cons 'artifact-handle
                 (agentic-ai-lab-durable-artifact-manifest-receipt-artifact-id
                  receipt))
           (cons 'request
                 (list (cons 'artifact-manifest manifest-row)))
           (cons 'policy
                 (list
                  (cons 'runtime-owner
                        (agentic-ai-lab-durable-artifact-manifest-receipt-runtime-owner
                         receipt))
                  (cons 'handoff-required #t)
                  (cons 'runtime-executed #f)))
           (cons 'plan-id #f)
           (cons 'node-id
                 (agentic-ai-lab-durable-artifact-manifest-receipt-manifest-id
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
     (cons 'kind 'agentic-ai-lab.durable.artifact.marlin-handoff)
     (cons 'schema +agentic-ai-lab-durable-artifact-manifest-handoff-schema+)
     (cons 'request-schema +runtime-request-schema+)
     (cons 'operation operation)
     (cons 'request-id (agentic-ai-lab-artifact-alist-ref manifest 'request-id #f))
     (cons 'artifact-id
           (agentic-ai-lab-durable-artifact-manifest-receipt-artifact-id receipt))
     (cons 'manifest-id
           (agentic-ai-lab-durable-artifact-manifest-receipt-manifest-id receipt))
     (cons 'runtime-owner
           (agentic-ai-lab-durable-artifact-manifest-receipt-runtime-owner receipt))
     (cons 'handoff-ready?
           (agentic-ai-lab-durable-artifact-manifest-receipt-valid? receipt))
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
     #'(agentic-ai-lab-artifact-profile-apply-hooks
        (agentic-ai-lab-artifact-profile 'name '(section ...))
        (list hook ...)))
    ((_ name section ... :with hook)
     #'(hook (agentic-ai-lab-artifact-profile 'name '(section ...))))
    ((_ name section ...)
     #'(agentic-ai-lab-artifact-profile 'name '(section ...)))))

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
     #'(agentic-ai-lab-artifact-database-profile 'name '(section ...)))))

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
     #'(agentic-ai-lab-durable-artifact 'artifact-id '(section ...)))))

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
