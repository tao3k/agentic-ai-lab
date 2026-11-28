;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public agent-sandbox contracts and type predicates.

(import "profile-contract.ss"
        (only-in :clan/poo/object .cc .ref .slot? object?)
        (only-in :clan/poo/type define-type Type. Record List))
(export AgentSandboxScope (import: "profile-contract.ss"))

(define-type (AgentSandboxScope @ Type.)
  identity: 'agent-sandbox/scope
  .element?: (lambda (value)
               (and (object? value)
                    (.slot? value 'library)
                    (eq? (.ref value 'library) 'tao3k/agentic-ai-lab/modules/agent-sandbox/interface))))

;; A Profile module publishes validated business values through the ordinary
;; module protocol. This is a scope contract, not a Profile loader.
(def SandboxProfilesScopeContract
  (.cc (Record profiles: (list (List AgenticAILabSandboxProfileContract)))
       identity: 'agent-sandbox/profiles-scope))
(export SandboxProfilesScopeContract)
