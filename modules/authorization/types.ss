;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: engine-neutral authorization Provider identity and capabilities.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every))

(export agentic-ai-lab-authorization-provider-kind
        agentic-ai-lab-authorization-capability-kind
        AgenticAILabAuthorizationProvider
        AgenticAILabAuthorizationCapability
        agentic-ai-lab-authorization-provider?
        agentic-ai-lab-authorization-capability?)

(def agentic-ai-lab-authorization-provider-kind
  'agentic-ai-lab.authorization-provider)
(def agentic-ai-lab-authorization-capability-kind
  'agentic-ai-lab.authorization-capability)

(def (authorization-provider-shape? value)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot))
              '(kind identity engines arbitration contract-executor runtime-owner
                runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-authorization-provider-kind)
       (string? (.ref value 'identity))
       (> (string-length (.ref value 'identity)) 0)
       (pair? (.ref value 'engines))
       (every string? (.ref value 'engines))
       (symbol? (.ref value 'arbitration))
       (symbol? (.ref value 'runtime-owner))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabAuthorizationProvider @ Type.)
  .element?: authorization-provider-shape?)

(def (authorization-capability-shape? value)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot))
              '(kind identity action event-kind risk runtime-executed?))
       (eq? (.ref value 'kind) agentic-ai-lab-authorization-capability-kind)
       (string? (.ref value 'identity))
       (> (string-length (.ref value 'identity)) 0)
       (string? (.ref value 'action))
       (> (string-length (.ref value 'action)) 0)
       (exact-integer? (.ref value 'event-kind))
       (< 0 (.ref value 'event-kind) 4294967296)
       (memq (.ref value 'risk) '(ordinary elevated))
       (eq? (.ref value 'runtime-executed?) #f)))

(define-type (AgenticAILabAuthorizationCapability @ Type.)
  .element?: authorization-capability-shape?)

(def (agentic-ai-lab-authorization-provider? value)
  (element? AgenticAILabAuthorizationProvider value))

(def (agentic-ai-lab-authorization-capability? value)
  (element? AgenticAILabAuthorizationCapability value))
