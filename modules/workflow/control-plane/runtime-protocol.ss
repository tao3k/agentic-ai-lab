;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: runtime request/response protocol data shared by adapters.
;;; Invariant: this module owns durable schemas and normalization only.

(import :poo-flow/modules/workflow/control-plane/projection-syntax)

(export make-adapter-result
        adapter-result?
        adapter-result-request-id
        adapter-result-status
        adapter-result-value
        adapter-result-artifact-handle
        adapter-result-error
        +runtime-request-schema+
        +runtime-response-schema+
        +runtime-command-descriptor-schema+
        +runtime-response-family+
        runtime-response-family
        runtime-response-family-build
        runtime-response-family-ref
        make-runtime-response
        runtime-response?
        runtime-response-request-id
        runtime-response-status
        runtime-response-value
        runtime-response-artifact-handle
        runtime-response-error
        runtime-response-metadata
        runtime-response->alist
        runtime-response->adapter-result
        normalize-runtime-response
        adapter-result->runtime-response
        adapter-result->alist
        runtime-alist-ref)

;; : (-> RequestId Symbol Value ArtifactHandle Error AdapterResult)
(defstruct adapter-result
  (request-id
   status
   value
   artifact-handle
   error)
  transparent: #t)

;; : (-> Unit Symbol)
(def +runtime-request-schema+ 'poo-flow.runtime-request.v1)

;; : (-> Unit Symbol)
(def +runtime-response-schema+ 'poo-flow.runtime-response.v1)

;; : (-> Unit Symbol)
(def +runtime-command-descriptor-schema+ 'poo-flow.runtime-command-descriptor.v1)

;; : (-> Symbol Symbol Alist)
(def (runtime-response-family family-name schema)
  (list (cons 'kind 'poo-flow-runtime-response-family)
        (cons 'name family-name)
        (cons 'schema schema)))

;; : Alist
(def +runtime-response-family+
  (runtime-response-family 'poo-flow-runtime-response-family
                           +runtime-response-schema+))

;;; Runtime responses are the durable schema projection for adapter results.
;;; The runner may still consume =adapter-result= directly, while Rust bridges
;;; and receipt stores can persist this stable alist-shaped response.
;; : (-> RequestId Symbol Value ArtifactHandle Error Alist RuntimeResponse)
(defstruct runtime-response
  (request-id
   status
   value
   artifact-handle
   error
   metadata)
  transparent: #t)

;; : (-> Alist Alist Alist)
(def (runtime-response-family-metadata family metadata)
  (let* ((family-name (runtime-alist-ref family 'name #f))
         (schema (runtime-alist-ref family 'schema #f))
         (with-family
          (if (assq 'response-family metadata)
            metadata
            (cons (cons 'response-family family-name) metadata))))
    (if (assq 'schema with-family)
      with-family
      (cons (cons 'schema schema) with-family))))

;; : (-> Alist RequestId Symbol Value ArtifactHandle Error Alist RuntimeResponse)
(def (runtime-response-family-build family
                                    request-id
                                    status
                                    value
                                    artifact-handle
                                    error
                                    metadata)
  (make-runtime-response
   request-id
   status
   value
   artifact-handle
   error
   (runtime-response-family-metadata family metadata)))

;; : (-> Alist RuntimeResponse Symbol Value Value)
(def (runtime-response-family-ref family response key default)
  (let (metadata (runtime-response-metadata response))
    (if (eq? (runtime-alist-ref metadata 'response-family #f)
             (runtime-alist-ref family 'name #f))
      (runtime-alist-ref (runtime-response->alist response) key default)
      default)))

;; : (-> RuntimeResponse Alist)
(defpoo-core-receipt-projection
  runtime-response->alist (response)
  (bindings ())
  (fields ((schema +runtime-response-schema+)
           (request-id (runtime-response-request-id response))
           (status (runtime-response-status response))
           (value (runtime-response-value response))
           (artifact-handle (runtime-response-artifact-handle response))
           (error (runtime-response-error response))
           (metadata (runtime-response-metadata response)))))

;; : (-> AdapterResult [Alist] RuntimeResponse)
(def (adapter-result->runtime-response result . maybe-metadata)
  (runtime-response-family-build
   +runtime-response-family+
   (adapter-result-request-id result)
   (adapter-result-status result)
   (adapter-result-value result)
   (adapter-result-artifact-handle result)
   (adapter-result-error result)
   (if (null? maybe-metadata) '() (car maybe-metadata))))

;; : (-> AdapterResult Alist)
(defpoo-core-receipt-projection
  adapter-result->alist (result)
  (bindings ((response (adapter-result->runtime-response result))))
  (fields ((schema +runtime-response-schema+)
           (request-id (runtime-response-request-id response))
           (status (runtime-response-status response))
           (value (runtime-response-value response))
           (artifact-handle (runtime-response-artifact-handle response))
           (error (runtime-response-error response))
           (metadata (runtime-response-metadata response)))))

;;; Boundary: runtime alist ref is the policy-visible edge for core behavior,
;;; keeping validation, lookup, or projection responsibilities centralized for
;;; callers.
;; : (-> Alist Symbol Value Value)
(def (runtime-alist-ref alist key default)
  (let (entry (assoc key alist))
    (if entry
      (cdr entry)
      default)))

;; : (-> RuntimeResponse AdapterResult)
(def (runtime-response->adapter-result response)
  (make-adapter-result
   (runtime-response-request-id response)
   (runtime-response-status response)
   (runtime-response-value response)
   (runtime-response-artifact-handle response)
   (runtime-response-error response)))

;; : (-> RuntimeResponseAlistCandidate Boolean)
(def (runtime-response-alist? value)
  (and (list? value)
       (let (schema (assoc 'schema value))
         (and schema (eq? (cdr schema) +runtime-response-schema+)))))

;; : (-> Value Alist)
(defpoo-core-receipt-projection
  invalid-runtime-response-error (response)
  (bindings ())
  (fields ((code 'invalid-runtime-response)
           (response response))))

;; : (-> Alist Value AdapterResult)
(def (invalid-runtime-response envelope response)
  (make-adapter-result
   (runtime-alist-ref envelope 'request-id #f)
   'failed
   #f
   (runtime-alist-ref envelope 'artifact-handle #f)
   (invalid-runtime-response-error response)))

;;; Runtime command responses are normalized before the runner sees them, so
;;; callers can return either the durable schema or the internal adapter shape.
;; : (-> Alist Value AdapterResult)
(def (normalize-runtime-response envelope response)
  (cond
   ((adapter-result? response)
    response)
   ((runtime-response? response)
    (runtime-response->adapter-result response))
   ((runtime-response-alist? response)
    (make-adapter-result
     (runtime-alist-ref response
                        'request-id
                        (runtime-alist-ref envelope 'request-id #f))
     (runtime-alist-ref response 'status 'submitted)
     (runtime-alist-ref response 'value #f)
     (runtime-alist-ref response
                        'artifact-handle
                        (runtime-alist-ref envelope 'artifact-handle #f))
     (runtime-alist-ref response 'error #f)))
   (else
    (invalid-runtime-response envelope response))))
