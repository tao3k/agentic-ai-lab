;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: declared POO session policy families.

(import :agentic-ai-lab/modules/session/objects
        :agentic-ai-lab/modules/session/policy-syntax
        :agentic-ai-lab/modules/session/policy-core
        :agentic-ai-lab/modules/session/policy-tool-grant)

(export agentic-ai-lab-session-isolation-policy
        agentic-ai-lab-session-sandbox-policy
        agentic-ai-lab-session-context-policy
        agentic-ai-lab-session-history-policy
        agentic-ai-lab-session-communication-policy
        agentic-ai-lab-session-sharing-policy
        agentic-ai-lab-session-resource-policy
        agentic-ai-lab-session-model-policy
        agentic-ai-lab-session-prompt-policy
        agentic-ai-lab-session-tool-permission-policy
        agentic-ai-lab-session-hook-tool-permission-policy
        agentic-ai-lab-session-resource-sharing-policy
        agentic-ai-lab-session-agent-execution-policy)

;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-isolation-policy
  agentic-ai-lab-session-policy-object
  (kind 'session-isolation)
  (schema 'agentic-ai-lab.modules.session.policy.isolation.v1)
  (default-action 'deny)
  (parameters (policy-name scope-ref mode sibling-context parent-write
                           peer-communication . maybe-metadata))
  (slots (('mode mode)
          ('sibling-context sibling-context)
          ('parent-write parent-write)
          ('peer-communication peer-communication)))
  (validate))

;; : (-> Symbol Symbol Symbol Symbol Symbol [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-sandbox-policy
  agentic-ai-lab-session-policy-object
  (kind 'session-sandbox)
  (schema 'agentic-ai-lab.modules.session.policy.sandbox.v1)
  (default-action 'deny)
  (parameters (policy-name scope-ref profile-ref inheritance-mode
                           sharing-mode . maybe-metadata))
  (slots (('profile-ref profile-ref)
          ('inheritance-mode inheritance-mode)
          ('sharing-mode sharing-mode)))
  (validate))

;; : (-> Symbol Symbol Symbol [Symbol] [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-context-policy
  agentic-ai-lab-session-policy-object
  (kind 'session-context)
  (schema 'agentic-ai-lab.modules.session.policy.context.v1)
  (default-action 'deny)
  (parameters (policy-name scope-ref visibility allowed-session-refs
                           . maybe-metadata))
  (slots (('visibility visibility)
          ('allowed-session-refs allowed-session-refs)))
  (validate
   (agentic-ai-lab-session-require "session context allowed refs must be symbols"
                             (agentic-ai-lab-session-symbol-list?
                              allowed-session-refs)
                             allowed-session-refs)))

;; : (-> Symbol Symbol Symbol [Symbol] [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-history-policy
  agentic-ai-lab-session-policy-object
  (kind 'session-history)
  (schema 'agentic-ai-lab.modules.session.policy.history.v1)
  (default-action 'deny)
  (parameters (policy-name scope-ref retention allowed-records
                           . maybe-metadata))
  (slots (('retention retention)
          ('allowed-records allowed-records)))
  (validate
   (agentic-ai-lab-session-require "session history records must be symbols"
                             (agentic-ai-lab-session-symbol-list?
                              allowed-records)
                             allowed-records)))

;; : (-> Symbol Symbol [Symbol] [Symbol] [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-communication-policy
  agentic-ai-lab-session-policy-object
  (kind 'session-communication)
  (schema 'agentic-ai-lab.modules.session.policy.communication.v1)
  (default-action 'deny)
  (parameters (policy-name scope-ref channel-refs target-session-refs
                           . maybe-metadata))
  (slots (('channel-refs channel-refs)
          ('target-session-refs target-session-refs)))
  (validate
   (agentic-ai-lab-session-require "session communication channels must be symbols"
                             (agentic-ai-lab-session-symbol-list?
                              channel-refs)
                             channel-refs)
   (agentic-ai-lab-session-require "session communication targets must be symbols"
                             (agentic-ai-lab-session-symbol-list?
                              target-session-refs)
                             target-session-refs)))

;; : (-> Symbol Symbol [Symbol] [Symbol] [Symbol] [Symbol/String] [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-sharing-policy
  agentic-ai-lab-session-policy-object
  (kind 'session-sharing)
  (schema 'agentic-ai-lab.modules.session.policy.sharing.v1)
  (default-action 'deny)
  (parameters (policy-name scope-ref memory-refs artifact-refs
                           tool-result-refs workspace-paths
                           . maybe-metadata))
  (slots (('memory-refs memory-refs)
          ('artifact-refs artifact-refs)
          ('tool-result-refs tool-result-refs)
          ('workspace-paths workspace-paths)))
  (validate
   (agentic-ai-lab-session-require "session sharing memory refs must be symbols"
                             (agentic-ai-lab-session-symbol-list? memory-refs)
                             memory-refs)
   (agentic-ai-lab-session-require "session sharing artifact refs must be symbols"
                             (agentic-ai-lab-session-symbol-list? artifact-refs)
                             artifact-refs)
   (agentic-ai-lab-session-require
    "session sharing tool result refs must be symbols"
    (agentic-ai-lab-session-symbol-list? tool-result-refs)
    tool-result-refs)
   (agentic-ai-lab-session-require
    "session sharing workspace paths must be symbols or strings"
    (agentic-ai-lab-session-policy-ref-list? workspace-paths)
    workspace-paths)))

;; : (-> Symbol Symbol [Symbol] [Symbol] Symbol [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-resource-policy
  agentic-ai-lab-session-policy-object
  (kind 'session-resource)
  (schema 'agentic-ai-lab.modules.session.policy.resource.v1)
  (default-action 'deny)
  (parameters (policy-name scope-ref budget-refs capability-refs
                           accounting-owner . maybe-metadata))
  (slots (('budget-refs budget-refs)
          ('capability-refs capability-refs)
          ('accounting-owner accounting-owner)))
  (validate
   (agentic-ai-lab-session-require "session resource budget refs must be symbols"
                             (agentic-ai-lab-session-symbol-list? budget-refs)
                             budget-refs)
   (agentic-ai-lab-session-require
    "session resource capability refs must be symbols"
    (agentic-ai-lab-session-symbol-list? capability-refs)
    capability-refs)
   (agentic-ai-lab-session-require
    "session resource accounting owner must be a symbol"
    (symbol? accounting-owner)
    accounting-owner)))

;; : (-> Symbol Symbol Symbol Symbol [Symbol] Symbol [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-model-policy
  agentic-ai-lab-session-policy-object
  (kind 'agent-model)
  (schema 'agentic-ai-lab.modules.session.policy.model.v1)
  (default-action 'deny)
  (parameters (policy-name scope-ref provider-ref model-ref
                           model-capabilities budget-ref
                           . maybe-metadata))
  (slots (('provider-ref provider-ref)
          ('model-ref model-ref)
          ('model-capabilities model-capabilities)
          ('budget-ref budget-ref)))
  (validate
   (agentic-ai-lab-session-require "session model policy provider must be a symbol"
                             (symbol? provider-ref)
                             provider-ref)
   (agentic-ai-lab-session-require "session model policy model must be a symbol"
                             (symbol? model-ref)
                             model-ref)
   (agentic-ai-lab-session-require "session model capabilities must be symbols"
                             (agentic-ai-lab-session-symbol-list?
                              model-capabilities)
                             model-capabilities)
   (agentic-ai-lab-session-require "session model budget ref must be a symbol"
                             (symbol? budget-ref)
                             budget-ref)))

;; : (-> Symbol Symbol Symbol [Symbol] Symbol [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-prompt-policy
  agentic-ai-lab-session-policy-object
  (kind 'agent-prompt)
  (schema 'agentic-ai-lab.modules.session.policy.prompt.v1)
  (default-action 'deny)
  (parameters (policy-name scope-ref prompt-session-ref prompt-chunk-refs
                           context-mode . maybe-metadata))
  (slots (('prompt-session-ref prompt-session-ref)
          ('prompt-chunk-refs prompt-chunk-refs)
          ('context-mode context-mode)))
  (validate
   (agentic-ai-lab-session-require
    "session prompt policy prompt session ref must be a symbol"
    (symbol? prompt-session-ref)
    prompt-session-ref)
   (agentic-ai-lab-session-require "session prompt chunk refs must be symbols"
                             (agentic-ai-lab-session-symbol-list?
                              prompt-chunk-refs)
                             prompt-chunk-refs)
   (agentic-ai-lab-session-require "session prompt context mode must be a symbol"
                             (symbol? context-mode)
                             context-mode)))

;; : (-> Symbol Symbol [PooSessionToolGrant] [Symbol] Symbol [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-tool-permission-policy
  agentic-ai-lab-session-policy-object
  (kind 'agent-tool-permission)
  (schema 'agentic-ai-lab.modules.session.policy.tool-permission.v1)
  (default-action default-action)
  (parameters (policy-name scope-ref tool-grants denied-tool-refs
                           default-action . maybe-metadata))
  (slots (('tool-grants tool-grants)
          ('denied-tool-refs denied-tool-refs)))
  (validate
   (agentic-ai-lab-session-require "session tool grants must be a list"
                             (list? tool-grants)
                             tool-grants)
   (agentic-ai-lab-session-require "session tool grants must contain only grants"
                             (agentic-ai-lab-session-every?
                              agentic-ai-lab-session-tool-grant?
                              tool-grants)
                             tool-grants)
   (agentic-ai-lab-session-require "session denied tools must be symbols"
                             (agentic-ai-lab-session-symbol-list?
                              denied-tool-refs)
                             denied-tool-refs)
   (agentic-ai-lab-session-require
    "session tool policy default action must be a symbol"
    (symbol? default-action)
    default-action)))

;; : (-> Symbol Symbol [Symbol] [PooSessionToolGrant] Symbol Symbol [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-hook-tool-permission-policy
  agentic-ai-lab-session-policy-object
  (kind 'hook-tool-permission)
  (schema 'agentic-ai-lab.modules.session.policy.hook-tool-permission.v1)
  (default-action default-action)
  (parameters (policy-name scope-ref hook-events tool-grants
                           escalation-policy default-action
                           . maybe-metadata))
  (slots (('hook-events hook-events)
          ('tool-grants tool-grants)
          ('escalation-policy escalation-policy)))
  (validate
   (agentic-ai-lab-session-require "session hook events must be symbols"
                             (agentic-ai-lab-session-symbol-list?
                              hook-events)
                             hook-events)
   (agentic-ai-lab-session-require "session hook tool grants must be a list"
                             (list? tool-grants)
                             tool-grants)
   (agentic-ai-lab-session-require
    "session hook tool grants must contain only grants"
    (agentic-ai-lab-session-every? agentic-ai-lab-session-tool-grant?
                             tool-grants)
    tool-grants)
   (agentic-ai-lab-session-require "session hook escalation must be a symbol"
                             (symbol? escalation-policy)
                             escalation-policy)
   (agentic-ai-lab-session-require "session hook default action must be a symbol"
                             (symbol? default-action)
                             default-action)))

;; : (-> Symbol Symbol [Alist] Symbol [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-resource-sharing-policy
  agentic-ai-lab-session-policy-object
  (kind 'resource-sharing)
  (schema 'agentic-ai-lab.modules.session.policy.resource-sharing.v1)
  (default-action default-action)
  (parameters (policy-name scope-ref resource-grants default-action
                           . maybe-metadata))
  (slots (('resource-grants resource-grants)))
  (validate
   (agentic-ai-lab-session-require "session resource grants must be a list"
                             (list? resource-grants)
                             resource-grants)
   (agentic-ai-lab-session-require
    "session resource default action must be a symbol"
    (symbol? default-action)
    default-action)))

;; : (-> Symbol Symbol Symbol Symbol Symbol Symbol Symbol Symbol Symbol [Alist] PooSessionPolicy)
(defpoo-session-policy-family
  agentic-ai-lab-session-agent-execution-policy
  agentic-ai-lab-session-policy-object
  (kind 'agent-execution)
  (schema 'agentic-ai-lab.modules.session.policy.agent-execution.v1)
  (default-action 'deny)
  (scope-ref session-ref)
  (parameters (policy-name agent-ref session-ref model-policy-ref
                           prompt-policy-ref tool-policy-ref hook-policy-ref
                           context-policy-ref resource-policy-ref
                           . maybe-metadata))
  (slots (('agent-ref agent-ref)
          ('session-ref session-ref)
          ('model-policy-ref model-policy-ref)
          ('prompt-policy-ref prompt-policy-ref)
          ('tool-policy-ref tool-policy-ref)
          ('hook-policy-ref hook-policy-ref)
          ('context-policy-ref context-policy-ref)
          ('resource-policy-ref resource-policy-ref)))
  (validate
   (agentic-ai-lab-session-require "session agent execution agent ref must be a symbol"
                             (symbol? agent-ref)
                             agent-ref)
   (agentic-ai-lab-session-require "session agent execution session ref must be a symbol"
                             (symbol? session-ref)
                             session-ref)
   (agentic-ai-lab-session-require "session agent model policy ref must be a symbol"
                             (symbol? model-policy-ref)
                             model-policy-ref)
   (agentic-ai-lab-session-require "session agent prompt policy ref must be a symbol"
                             (symbol? prompt-policy-ref)
                             prompt-policy-ref)
   (agentic-ai-lab-session-require "session agent tool policy ref must be a symbol"
                             (symbol? tool-policy-ref)
                             tool-policy-ref)
   (agentic-ai-lab-session-require "session agent hook policy ref must be a symbol"
                             (symbol? hook-policy-ref)
                             hook-policy-ref)
   (agentic-ai-lab-session-require "session agent context policy ref must be a symbol"
                             (symbol? context-policy-ref)
                             context-policy-ref)
   (agentic-ai-lab-session-require "session agent resource policy ref must be a symbol"
                             (symbol? resource-policy-ref)
                             resource-policy-ref)))
