;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO-native tool specification owner and runtime-boundary projection.

(import (only-in :clan/poo/object .ref object? object<-alist)
        :yuanxu/utilities/final-projection-syntax
        :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy
        :agentic-ai-lab/modules/tool-core/objects-support)

(export +agentic-ai-lab-tool-core-spec-kind+
        agentic-ai-lab-tool-spec
        agentic-ai-lab-tool-spec?
        agentic-ai-lab-tool-spec-ref
        agentic-ai-lab-tool-spec-tool-kind
        agentic-ai-lab-tool-spec-actions
        agentic-ai-lab-tool-spec-sandbox-required?
        agentic-ai-lab-tool-spec-sandbox-profile-ref
        agentic-ai-lab-tool-spec->alist
        agentic-ai-lab-tool-specs->alists)

(def +agentic-ai-lab-tool-core-spec-kind+ 'agentic-ai-lab.tool-core.spec)

(def (agentic-ai-lab-tool-spec tool-ref
                         tool-kind
                         actions
                         input-schema
                         output-schema
                         runtime-owner
                         handoff-operation
                         sandbox-required?
                         sandbox-profile-ref
                         runtime-backend
                         . maybe-metadata)
  (agentic-ai-lab-session-require "tool spec ref must be a symbol"
                            (symbol? tool-ref)
                            tool-ref)
  (agentic-ai-lab-session-require "tool spec kind must be a symbol"
                            (symbol? tool-kind)
                            tool-kind)
  (agentic-ai-lab-session-require "tool spec actions must be symbols"
                            (agentic-ai-lab-tool-symbol-list? actions)
                            actions)
  (agentic-ai-lab-session-require "tool spec input schema must be an alist"
                            (agentic-ai-lab-tool-alist? input-schema)
                            input-schema)
  (agentic-ai-lab-session-require "tool spec output schema must be an alist"
                            (agentic-ai-lab-tool-alist? output-schema)
                            output-schema)
  (agentic-ai-lab-session-require "tool spec runtime owner must be a string"
                            (string? runtime-owner)
                            runtime-owner)
  (agentic-ai-lab-session-require "tool spec handoff operation must be a symbol"
                            (symbol? handoff-operation)
                            handoff-operation)
  (agentic-ai-lab-session-require "tool spec sandbox-required? must be boolean"
                            (boolean? sandbox-required?)
                            sandbox-required?)
  (agentic-ai-lab-session-require "tool spec runtime backend must be a symbol"
                            (symbol? runtime-backend)
                            runtime-backend)
  (object<-alist
   (list
    (cons 'kind +agentic-ai-lab-tool-core-spec-kind+)
    (cons 'schema 'agentic-ai-lab.modules.tool-core.spec.v1)
    (cons 'tool-ref tool-ref)
    (cons 'tool-kind tool-kind)
    (cons 'actions actions)
    (cons 'input-schema input-schema)
    (cons 'output-schema output-schema)
    (cons 'runtime-owner runtime-owner)
    (cons 'handoff-operation handoff-operation)
    (cons 'sandbox-required? sandbox-required?)
    (cons 'sandbox-profile-ref sandbox-profile-ref)
    (cons 'runtime-backend runtime-backend)
    (cons 'runtime-executed #f)
    (cons 'metadata (if (null? maybe-metadata)
                      '()
                      (car maybe-metadata))))))

(def (agentic-ai-lab-tool-spec? value)
  (and (object? value)
       (eq? (agentic-ai-lab-tool-slot value 'kind #f)
            +agentic-ai-lab-tool-core-spec-kind+)))

(def (agentic-ai-lab-tool-spec-ref spec)
  (.ref spec 'tool-ref))

(def (agentic-ai-lab-tool-spec-tool-kind spec)
  (.ref spec 'tool-kind))

(def (agentic-ai-lab-tool-spec-actions spec)
  (.ref spec 'actions))

(def (agentic-ai-lab-tool-spec-sandbox-required? spec)
  (.ref spec 'sandbox-required?))

(def (agentic-ai-lab-tool-spec-sandbox-profile-ref spec)
  (.ref spec 'sandbox-profile-ref))

(defpoo-final-projection
  agentic-ai-lab-tool-spec->alist (spec)
  (bindings ((checked-spec
              (agentic-ai-lab-session-require
               "tool spec projection requires a tool spec"
               (agentic-ai-lab-tool-spec? spec)
               spec))))
  (fields ((kind (.ref checked-spec 'kind))
           (schema (.ref checked-spec 'schema))
           (tool-ref (.ref checked-spec 'tool-ref))
           (tool-kind (.ref checked-spec 'tool-kind))
           (actions (.ref checked-spec 'actions))
           (input-schema (.ref checked-spec 'input-schema))
           (output-schema (.ref checked-spec 'output-schema))
           (runtime-owner (.ref checked-spec 'runtime-owner))
           (handoff-operation (.ref checked-spec 'handoff-operation))
           (sandbox-required? (.ref checked-spec 'sandbox-required?))
           (sandbox-profile-ref (.ref checked-spec 'sandbox-profile-ref))
           (runtime-backend (.ref checked-spec 'runtime-backend))
           (runtime-executed (.ref checked-spec 'runtime-executed))
           (metadata (.ref checked-spec 'metadata)))))

(defpoo-final-projection-batch
  agentic-ai-lab-tool-specs->alists (specs)
  (projector agentic-ai-lab-tool-spec->alist)
  (error-message "tool spec serialization requires a list"))
