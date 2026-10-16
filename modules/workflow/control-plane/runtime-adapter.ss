;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: adapters normalize calls to heavy runtime implementations.
;;; Invariant: this module only defines the request-only placeholder adapter.

(import :poo-flow/modules/workflow/control-plane/task
        :poo-flow/modules/workflow/control-plane/runtime-protocol
        :poo-flow/modules/workflow/control-plane/runtime-command-invocation)

(export make-runtime-adapter
        runtime-adapter?
        runtime-adapter-name
        runtime-adapter-capabilities
        runtime-adapter-submitter
        runtime-adapter-fetcher
        runtime-adapter-store-putter
        runtime-adapter-store-getter
        make-request-only-adapter
        make-rust-adapter
        rust-request-envelope
        adapter-supports?
        adapter-submit
        adapter-fetch
        adapter-store-put
        adapter-store-get)

;;; Function slots are the runtime boundary; Scheme policy calls these slots
;;; without owning the heavy implementation behind them.
;; : (-> Symbol [Symbol] Submitter Fetcher StorePutter StoreGetter RuntimeAdapter)
(defstruct runtime-adapter
  (name
   capabilities
   submitter
   fetcher
   store-putter
   store-getter)
  transparent: #t)

;;; The request-only adapter is deterministic evidence plumbing for tests and
;;; early control-plane validation.
;; : (-> Unit RuntimeAdapter)
(def (make-request-only-adapter)
  (make-runtime-adapter 'request-only
                        '(external)
                        request-only-submit
                        request-only-fetch
                        request-only-store-put
                        request-only-store-get))

;;; The Rust adapter is a Scheme-side handoff stub. It proves the request shape
;;; can cross the boundary without embedding the heavy runtime implementation.
;; : (-> [RuntimeCommand] RuntimeAdapter)
(def (make-rust-adapter . maybe-command)
  (if (or (null? maybe-command) (not (car maybe-command)))
    (make-runtime-adapter 'rust
                          '(external)
                          rust-submit
                          rust-fetch
                          rust-store-put
                          rust-store-get)
    (let (command (car maybe-command))
      (make-runtime-adapter 'rust
                            '(external)
                            (lambda (request)
                              (rust-command-submit command request))
                            rust-fetch
                            (lambda (request)
                              (rust-command-store-put command request))
                            rust-store-get))))

;; : (-> RuntimeAdapter Symbol Boolean)
(def (adapter-supports? adapter capability)
  (and (memq capability (runtime-adapter-capabilities adapter)) #t))

;; : (-> RuntimeAdapter ExecutionRequest AdapterResult)
(def (adapter-submit adapter request)
  ((runtime-adapter-submitter adapter) request))

;; : (-> RuntimeAdapter RequestId AdapterResult)
(def (adapter-fetch adapter request-id)
  ((runtime-adapter-fetcher adapter) request-id))

;; : (-> RuntimeAdapter ExecutionRequest AdapterResult)
(def (adapter-store-put adapter request)
  ((runtime-adapter-store-putter adapter) request))

;; : (-> RuntimeAdapter ArtifactHandle AdapterResult)
(def (adapter-store-get adapter handle)
  ((runtime-adapter-store-getter adapter) handle))

;; : (-> ExecutionRequest RequestId)
(def (request-id request)
  (list 'request (execution-request-name request) (execution-request-kind request)))

;; : (-> ExecutionRequest RequestId)
(def (rust-request-id request)
  (list 'rust-request (execution-request-name request) (execution-request-kind request)))

;; : (-> ExecutionRequest ArtifactHandle)
(def (rust-artifact-handle request)
  (list 'rust-artifact
        (execution-request-plan-id request)
        (execution-request-node-id request)))

;;; The envelope is intentionally alist-shaped so Rust can deserialize the same
;;; data without understanding Gerbil structs.
;; : (-> ExecutionRequest [Symbol] Alist)
(def (rust-request-envelope request . maybe-operation)
  (let ((operation (if (null? maybe-operation) 'submit (car maybe-operation))))
    (list (cons 'schema +runtime-request-schema+)
          (cons 'runtime 'rust)
          (cons 'operation operation)
          (cons 'request-id (rust-request-id request))
          (cons 'artifact-handle (rust-artifact-handle request))
          (cons 'request request)
          (cons 'policy (execution-request-policy request))
          (cons 'plan-id (execution-request-plan-id request))
          (cons 'node-id (execution-request-node-id request))
          (cons 'frontier (execution-request-frontier request)))))

;; : (-> ExecutionRequest AdapterResult)
(def (request-only-submit request)
  (make-adapter-result (request-id request) 'requested request #f #f))

;; : (-> RequestId AdapterResult)
(def (request-only-fetch request-id)
  (make-adapter-result request-id 'requested #f #f #f))

;; : (-> ExecutionRequest AdapterResult)
(def (request-only-store-put request)
  (make-adapter-result (request-id request) 'requested request #f #f))

;; : (-> ArtifactHandle AdapterResult)
(def (request-only-store-get handle)
  (make-adapter-result (list 'store-get handle) 'requested #f handle #f))

;; : (-> ExecutionRequest AdapterResult)
(def (rust-submit request)
  (make-adapter-result (rust-request-id request)
                       'submitted
                       (rust-request-envelope request)
                       (rust-artifact-handle request)
                       #f))

;; : (-> RequestId AdapterResult)
(def (rust-fetch request-id)
  (make-adapter-result request-id 'submitted #f #f #f))

;; : (-> ExecutionRequest AdapterResult)
(def (rust-store-put request)
  (make-adapter-result (rust-request-id request)
                       'submitted
                       (rust-request-envelope request 'store-put)
                       (rust-artifact-handle request)
                       #f))

;; : (-> ArtifactHandle AdapterResult)
(def (rust-store-get handle)
  (make-adapter-result (list 'rust-store-get handle) 'submitted #f handle #f))

;; : (-> RuntimeCommand ExecutionRequest AdapterResult)
(def (rust-command-submit command request)
  (runtime-command-result command (rust-request-envelope request)))

;; : (-> RuntimeCommand ExecutionRequest AdapterResult)
(def (rust-command-store-put command request)
  (runtime-command-result command (rust-request-envelope request 'store-put)))
