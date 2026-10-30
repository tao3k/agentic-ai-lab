;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: agent-sandbox request field contracts live here.
;;; Boundary: this module validates named builder fields, not normalized requests.
;;; Runtime contract: accepted field names are inert data until request assembly.
;;; Policy evidence: request facade re-exports these constants for stable callers.

(import (only-in :yuanxu/modules/funflow/control-plane/failure raise-control-plane-failure)
        :agentic-ai-lab/modules/agent-sandbox/alist)

(export +agent-sandbox-request-schema+
        +agent-sandbox-request-field-names+
        agent-sandbox-request-builder-field?
        agent-sandbox-request-field-contract-errors
        agent-sandbox-validate-request-fields)

;; : (-> Unit Symbol)
(def +agent-sandbox-request-schema+ 'agentic-ai-lab.agent-sandbox-request.v1)

;;; Named request fields are the typed public surface for macro builders. They
;;; deliberately exclude profile-derived backend fields, which stay descriptor-owned.
;; : (-> Unit [Symbol])
(def +agent-sandbox-request-field-names+
  '(command
    args
    env
    workdir
    mounts
    network-policy
    capabilities
    resource-policy
    output-policy
    metadata))

;; : (-> Symbol Boolean)
(def (agent-sandbox-request-builder-field? field)
  (and (memq field +agent-sandbox-request-field-names+) #t))

;;; Field contract errors catch typo-level interface mistakes before request
;;; normalization merges profile defaults into the runtime-facing shape.
;; : (-> FieldAlist [ValidationError] [ValidationError])
(def (agent-sandbox-request-field-contract-errors/rev fields errors-rev)
  (if (null? fields)
    errors-rev
    (let (error-row
          (agent-sandbox-request-field-contract-error (car fields)))
      (agent-sandbox-request-field-contract-errors/rev
       (cdr fields)
       (if error-row
         (cons error-row errors-rev)
         errors-rev)))))

;; : (-> FieldAlist [ValidationError])
(def (agent-sandbox-request-field-contract-errors fields)
  (reverse
   (agent-sandbox-request-field-contract-errors/rev fields '())))

;;; Boundary: agent sandbox request field contract error is the policy-visible
;;; edge for sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> FieldEntry MaybeValidationError)
(def (agent-sandbox-request-field-contract-error field)
  (cond
   ((not (pair? field))
    (agent-sandbox-request-field-error field 'malformed-field))
   ((agent-sandbox-request-builder-field?
     (agent-sandbox-request-field-name field))
    #f)
   (else
    (agent-sandbox-request-field-error
     (agent-sandbox-request-field-name field)
     'unsupported-field))))

;; : (-> FieldEntry Symbol)
(def (agent-sandbox-request-field-name field)
  (car field))

;; : (-> FieldDatum Symbol ValidationError)
(def (agent-sandbox-request-field-error field code)
  (list (cons 'field field)
        (cons 'code code)))

;;; Field validation is the first gate for the higher-level request macro:
;;; accepted fields are explicit, but value-level semantics remain request-owned.
;; : (-> FieldAlist FieldAlist)
(def (agent-sandbox-validate-request-fields fields)
  (let (errors (agent-sandbox-request-field-contract-errors fields))
    (if (null? errors)
      fields
      (raise-control-plane-failure
       'agent-sandbox
       'invalid-agent-sandbox-request-fields
       "invalid agent sandbox request fields"
       (list (cons 'errors errors)
             (cons 'fields fields))))))
