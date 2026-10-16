;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO-native tool specification owner and runtime-boundary projection.

(import (only-in :clan/poo/object .ref object? object<-alist)
        :core/utilities/final-projection-syntax
        :poo-flow/modules/session/objects
        :poo-flow/modules/session/policy
        :poo-flow/modules/tool-core/objects-support)

(export +poo-flow-tool-core-spec-kind+
        poo-flow-tool-spec
        poo-flow-tool-spec?
        poo-flow-tool-spec-ref
        poo-flow-tool-spec-tool-kind
        poo-flow-tool-spec-actions
        poo-flow-tool-spec-sandbox-required?
        poo-flow-tool-spec-sandbox-profile-ref
        poo-flow-tool-spec->alist
        poo-flow-tool-specs->alists)

(def +poo-flow-tool-core-spec-kind+ 'poo-flow.tool-core.spec)

(def (poo-flow-tool-spec tool-ref
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
  (poo-flow-session-require "tool spec ref must be a symbol"
                            (symbol? tool-ref)
                            tool-ref)
  (poo-flow-session-require "tool spec kind must be a symbol"
                            (symbol? tool-kind)
                            tool-kind)
  (poo-flow-session-require "tool spec actions must be symbols"
                            (poo-flow-tool-symbol-list? actions)
                            actions)
  (poo-flow-session-require "tool spec input schema must be an alist"
                            (poo-flow-tool-alist? input-schema)
                            input-schema)
  (poo-flow-session-require "tool spec output schema must be an alist"
                            (poo-flow-tool-alist? output-schema)
                            output-schema)
  (poo-flow-session-require "tool spec runtime owner must be a string"
                            (string? runtime-owner)
                            runtime-owner)
  (poo-flow-session-require "tool spec handoff operation must be a symbol"
                            (symbol? handoff-operation)
                            handoff-operation)
  (poo-flow-session-require "tool spec sandbox-required? must be boolean"
                            (boolean? sandbox-required?)
                            sandbox-required?)
  (poo-flow-session-require "tool spec runtime backend must be a symbol"
                            (symbol? runtime-backend)
                            runtime-backend)
  (object<-alist
   (list
    (cons 'kind +poo-flow-tool-core-spec-kind+)
    (cons 'schema 'poo-flow.modules.tool-core.spec.v1)
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

(def (poo-flow-tool-spec? value)
  (and (object? value)
       (eq? (poo-flow-tool-slot value 'kind #f)
            +poo-flow-tool-core-spec-kind+)))

(def (poo-flow-tool-spec-ref spec)
  (.ref spec 'tool-ref))

(def (poo-flow-tool-spec-tool-kind spec)
  (.ref spec 'tool-kind))

(def (poo-flow-tool-spec-actions spec)
  (.ref spec 'actions))

(def (poo-flow-tool-spec-sandbox-required? spec)
  (.ref spec 'sandbox-required?))

(def (poo-flow-tool-spec-sandbox-profile-ref spec)
  (.ref spec 'sandbox-profile-ref))

(defpoo-final-projection
  poo-flow-tool-spec->alist (spec)
  (bindings ((checked-spec
              (poo-flow-session-require
               "tool spec projection requires a tool spec"
               (poo-flow-tool-spec? spec)
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
  poo-flow-tool-specs->alists (specs)
  (projector poo-flow-tool-spec->alist)
  (error-message "tool spec serialization requires a list"))
