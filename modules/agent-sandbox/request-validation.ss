;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: agent-sandbox normalized request validation lives here.
;;; Boundary:
;;; - Request builders assemble data before calling this module.
;;; - Backend-specific policy payloads remain runtime-owned.
;;; Import contract:
;;; - Request owner re-exports these validators through the facade.
;;; Runtime contract:
;;; - Validation raises typed control-plane failures before bridge projection.
;;; - Predicate and lookup helpers never execute sandbox backends.
;;; Policy evidence:
;;; - Profile and bridge tests assert both valid requests and failure codes.

(import (only-in :yuanxu/modules/funflow/control-plane/failure raise-control-plane-failure)
        :agentic-ai-lab/modules/agent-sandbox/alist
        :agentic-ai-lab/modules/agent-sandbox/projection-syntax
        :agentic-ai-lab/modules/agent-sandbox/profile
        :agentic-ai-lab/modules/agent-sandbox/request-field)

(export agent-sandbox-request-validation-errors
        agent-sandbox-validate-request
        agent-sandbox-request?
        agent-sandbox-request-ref)

;; : (-> Symbol Symbol ValidationError)
(def (agent-sandbox-request-validation-error field code)
  (agent-sandbox-field-rows
   (field field)
   (code code)))

;;; Schema predicate is intentionally exact: bridge requests must use the
;;; normalized request vocabulary before backend-specific validation begins.
;; : (-> AgentSandboxRequestSchemaCandidate Boolean)
(def (agent-sandbox-request-schema? value)
  (eq? value +agent-sandbox-request-schema+))

;;; Presence accepts any non-false value because backend refs and commands may
;;; be symbols, strings, or richer request payloads owned by later adapters.
;; : (-> AgentSandboxRequiredFieldCandidate Boolean)
(def (agent-sandbox-present? value)
  (and value #t))

;;; Request validation covers the bridge-stable fields that every backend needs
;;; before runtime dispatch. Policy payloads stay backend-owned alists.
;; : (-> AgentSandboxRequest [ValidationError])
(def (agent-sandbox-request-validation-errors request)
  (let* ((errors-rev
          (if (agent-sandbox-request-schema?
               (agent-sandbox-request-ref request 'schema #f))
            '()
            (list (agent-sandbox-request-validation-error
                   'schema
                   'schema-mismatch))))
         (errors-rev
          (agent-sandbox-rows-into/rev
           (agent-sandbox-required-field-errors
            request
            (list (cons 'backend-kind agent-sandbox-present?)
                  (cons 'backend-ref agent-sandbox-present?)
                  (cons 'command agent-sandbox-present?)))
           errors-rev)))
    (reverse errors-rev)))

;;; Request validation is the last Scheme-side gate before a runtime adapter or
;;; bridge envelope sees the normalized sandbox request.
;; : (-> AgentSandboxRequest AgentSandboxRequest)
(def (agent-sandbox-validate-request request)
  (let (errors (agent-sandbox-request-validation-errors request))
    (if (null? errors)
      request
      (raise-control-plane-failure
       'agent-sandbox
       'invalid-agent-sandbox-request
       "invalid agent sandbox request"
       (agent-sandbox-field-rows
        (errors errors)
        (request request))))))

;;; Request predicates keep bridge code honest without making Scheme validate
;;; backend-specific policy details that Marlin or Cube/nono integrations own.
;; : (-> AgentSandboxRequestCandidate Boolean)
(def (agent-sandbox-request? value)
  (and (list? value)
       (let (schema (assoc 'schema value))
         (and schema
              (eq? (cdr schema) +agent-sandbox-request-schema+)))))

;;; Public request lookup gives bridge tests and future bindings one stable
;;; reader instead of duplicating raw alist access at every integration point.
;; : (-> AgentSandboxRequest Symbol Value Value)
(def (agent-sandbox-request-ref request key default)
  (agent-sandbox-alist-ref request key default))
