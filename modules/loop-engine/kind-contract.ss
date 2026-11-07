;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop-engine POO prototype-kind predicates.
;;; Invariant: only recognized prototype descendants lower into report rows.

(import (only-in :clan/poo/object .ref .slot? object?)
        "prototypes.ss")

(export agentic-ai-lab-user-loop-engine-poo-kind?
        agentic-ai-lab-user-loop-engine-poo-use-case?
        agentic-ai-lab-user-loop-engine-poo-profile?)

;;; Prototype-kind matching is the inheritance gate for every loop-engine POO
;;; object before it can lower into report rows.
;; : (-> Value Symbol Boolean)
(def (agentic-ai-lab-user-loop-engine-poo-kind? value kind)
  (and (object? value)
       (.slot? value 'kind)
       (eq? (.ref value 'kind) kind)))

;;; Use-case objects are the only accepted roots for single-loop row lowering;
;;; the predicate is public because tests and diagnostics assert this boundary.
;; : (-> AgenticAILabLoopEngineUseCaseCandidate Boolean)
(def (agentic-ai-lab-user-loop-engine-poo-use-case? value)
  (agentic-ai-lab-user-loop-engine-poo-kind?
   value
   +agentic-ai-lab-user-loop-engine-use-case-prototype-kind+))

;;; Profile objects are the public `:config` root. Rejecting non-profile values
;;; here keeps downstream modules from smuggling arbitrary POO objects into
;;; runtime handoff projection.
;; : (-> AgenticAILabLoopEngineProfileCandidate Boolean)
(def (agentic-ai-lab-user-loop-engine-poo-profile? value)
  (agentic-ai-lab-user-loop-engine-poo-kind?
   value
   +agentic-ai-lab-user-loop-engine-profile-prototype-kind+))
