;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime command descriptors and request-bound manifests.
;;; Invariant: descriptors are inert CLI contracts until materialized.

(import :poo-flow/modules/workflow/control-plane/runtime-protocol
        :poo-flow/modules/workflow/control-plane/runtime-command-invocation
        (only-in :std/misc/process run-process))

(export make-runtime-command-descriptor
        runtime-command-descriptor?
        runtime-command-descriptor-name
        runtime-command-descriptor-executable
        runtime-command-descriptor-arguments
        runtime-command-descriptor-protocol
        runtime-command-descriptor-metadata
        make-stdout-runtime-command-descriptor
        runtime-command-fields->manifest
        runtime-command-descriptor-arguments-for
        runtime-command-descriptor->manifest
        runtime-command-manifest?
        runtime-command-manifest-ref
        runtime-command-manifest-argv
        runtime-command-manifest-envelope
        run-runtime-command-manifest
        runtime-command-manifest->command
        runtime-command-descriptor->command)

;;; Runtime command descriptors are inert CLI contracts. They make the future
;;; Rust executable boundary inspectable before the command is materialized.
;; : (-> Symbol Path ArgumentsBuilder Protocol Alist RuntimeCommandDescriptor)
(defstruct runtime-command-descriptor
  (name
   executable
   arguments
   protocol
   metadata)
  transparent: #t)

;; : (-> Symbol Path ArgumentsBuilder [Alist] RuntimeCommandDescriptor)
(def (make-stdout-runtime-command-descriptor name executable arguments . maybe-metadata)
  (make-runtime-command-descriptor
   name
   executable
   arguments
   'stdout-s-expression
   (if (null? maybe-metadata) '() (car maybe-metadata))))

;; : (-> RuntimeCommandDescriptor Alist [String])
(def (runtime-command-descriptor-arguments-for descriptor envelope)
  (let (arguments (runtime-command-descriptor-arguments descriptor))
    (if (procedure? arguments)
      (arguments envelope)
      arguments)))

;;; Field manifests are the class-free handoff path for owners that should not
;;; expose Gerbil descriptor structs in their compile-time metadata.
;; : (-> Symbol Path ArgumentsBuilder Protocol Alist Alist Alist)
(def (runtime-command-fields->manifest name executable arguments protocol metadata envelope)
  (let ((arguments-value
         (if (procedure? arguments)
           (arguments envelope)
           arguments)))
    (list (cons 'schema +runtime-command-descriptor-schema+)
          (cons 'request-schema (runtime-alist-ref envelope 'schema #f))
          (cons 'operation (runtime-alist-ref envelope 'operation #f))
          (cons 'request-id (runtime-alist-ref envelope 'request-id #f))
          (cons 'artifact-handle (runtime-alist-ref envelope 'artifact-handle #f))
          (cons 'request (runtime-alist-ref envelope 'request #f))
          (cons 'policy (runtime-alist-ref envelope 'policy '()))
          (cons 'plan-id (runtime-alist-ref envelope 'plan-id #f))
          (cons 'node-id (runtime-alist-ref envelope 'node-id #f))
          (cons 'frontier (runtime-alist-ref envelope 'frontier '()))
          (cons 'name name)
          (cons 'protocol protocol)
          (cons 'executable executable)
          (cons 'arguments arguments-value)
          (cons 'argv (cons executable arguments-value))
          (cons 'metadata metadata))))

;;; Descriptor manifests are the concrete CLI handoff for a request envelope:
;;; Rust can consume this data without knowing Scheme constructor details.
;; : (-> RuntimeCommandDescriptor Alist Alist)
(def (runtime-command-descriptor->manifest descriptor envelope)
  (runtime-command-fields->manifest
   (runtime-command-descriptor-name descriptor)
   (runtime-command-descriptor-executable descriptor)
   (runtime-command-descriptor-arguments descriptor)
   (runtime-command-descriptor-protocol descriptor)
   (runtime-command-descriptor-metadata descriptor)
   envelope))

;; : (-> RuntimeCommandManifestCandidate Boolean)
(def (runtime-command-manifest? value)
  (and (list? value)
       (let (schema (assoc 'schema value))
         (and schema
              (eq? (cdr schema) +runtime-command-descriptor-schema+)))))

;; : (-> RuntimeCommandManifest Symbol Value Value)
(def (runtime-command-manifest-ref manifest key default)
  (runtime-alist-ref manifest key default))

;;; Manifest argv is the concrete Rust/process command line. If older manifests
;;; omit =argv=, it is reconstructed from executable and arguments.
;; : (-> RuntimeCommandManifest [String])
(def (runtime-command-manifest-argv manifest)
  (runtime-command-manifest-ref
   manifest
   'argv
   (cons (runtime-command-manifest-ref manifest 'executable #f)
         (runtime-command-manifest-ref manifest 'arguments '()))))

;;; A manifest is request-bound, so its envelope is reconstructed from the
;;; durable request fields captured when descriptor code exported the manifest.
;; : (-> RuntimeCommandManifest Alist)
(def (runtime-command-manifest-envelope manifest)
  (list (cons 'schema
              (runtime-command-manifest-ref manifest
                                            'request-schema
                                            +runtime-request-schema+))
        (cons 'runtime 'manifest)
        (cons 'operation
              (runtime-command-manifest-ref manifest 'operation 'submit))
        (cons 'request-id
              (runtime-command-manifest-ref manifest 'request-id #f))
        (cons 'artifact-handle
              (runtime-command-manifest-ref manifest 'artifact-handle #f))
        (cons 'request
              (runtime-command-manifest-ref manifest 'request #f))
        (cons 'policy
              (runtime-command-manifest-ref manifest 'policy '()))
        (cons 'plan-id
              (runtime-command-manifest-ref manifest 'plan-id #f))
        (cons 'node-id
              (runtime-command-manifest-ref manifest 'node-id #f))
        (cons 'frontier
              (runtime-command-manifest-ref manifest 'frontier '()))))

;; : (-> RuntimeCommandManifest Symbol Value AdapterResult)
(def (runtime-command-manifest-failure manifest code detail)
  (make-adapter-result
   (runtime-command-manifest-ref manifest 'request-id #f)
   'failed
   #f
   (runtime-command-manifest-ref manifest 'artifact-handle #f)
   (list (cons 'code code)
         (cons 'detail detail))))

;;; Manifest execution is the first local consumer for Rust CLI handoff data:
;;; it runs the stored argv and normalizes stdout through the declared protocol.
;; : (-> RuntimeCommandManifest AdapterResult)
(def (run-runtime-command-manifest manifest)
  (cond
   ((not (runtime-command-manifest? manifest))
    (runtime-command-manifest-failure
     '()
     'invalid-runtime-command-manifest
     manifest))
   ((eq? (runtime-command-manifest-ref manifest 'protocol #f)
         'stdout-s-expression)
    (with-catch
     (lambda (failure)
       (runtime-command-manifest-failure
        manifest
        'runtime-command-manifest-error
        failure))
     (lambda ()
       (let* ((envelope (runtime-command-manifest-envelope manifest))
              (stdout (run-process (runtime-command-manifest-argv manifest))))
         (normalize-runtime-response
          envelope
          (runtime-command-read-response envelope stdout))))))
   (else
    (runtime-command-manifest-failure
     manifest
     'unsupported-runtime-command-manifest-protocol
     (runtime-command-manifest-ref manifest 'protocol #f)))))

;;; Materializing a manifest as a command lets existing adapter tests consume a
;;; request-bound CLI manifest through the same RuntimeCommand slot.
;; : (-> RuntimeCommandManifest RuntimeCommand)
(def (runtime-command-manifest->command manifest)
  (make-procedure-runtime-command
   (runtime-command-manifest-ref manifest 'name 'runtime-command-manifest)
   (lambda (_envelope)
     (run-runtime-command-manifest manifest))
   (runtime-command-field-rows/tail
    (runtime-command-manifest-ref manifest 'metadata '())
    (source 'manifest))))

;;; Descriptor materialization is the narrow replacement seam for Rust-backed
;;; commands: workflow code depends on protocol data, not constructor details.
;; : (-> RuntimeCommandDescriptor RuntimeCommand)
(def (runtime-command-descriptor->command descriptor)
  (let ((metadata
         (runtime-command-field-rows/tail
          (runtime-command-descriptor-metadata descriptor)
          (protocol (runtime-command-descriptor-protocol descriptor)))))
    (if (eq? (runtime-command-descriptor-protocol descriptor) 'stdout-s-expression)
      (make-stdout-runtime-command
       (runtime-command-descriptor-name descriptor)
       (runtime-command-descriptor-executable descriptor)
       (runtime-command-descriptor-arguments descriptor)
       metadata)
      (make-procedure-runtime-command
       (runtime-command-descriptor-name descriptor)
       (lambda (envelope)
         (runtime-command-failure-response
          envelope
          'unsupported-runtime-command-protocol
          (runtime-command-descriptor-protocol descriptor)
          metadata))
       metadata))))
