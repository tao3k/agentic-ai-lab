;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public agent-sandbox contracts and type predicates.

(import "profile-contract.ss" (only-in :clan/poo/object .cc)
        (only-in :clan/poo/type Record List))
(export (import: "profile-contract.ss"))

;; A Profile module publishes validated business values through the ordinary
;; module protocol. This is a scope contract, not a Profile loader.
(def SandboxProfilesScopeContract
  (.cc (Record profiles: (list (List AgenticAILabSandboxProfileContract)))
       identity: 'agent-sandbox/profiles-scope))
(export SandboxProfilesScopeContract)
