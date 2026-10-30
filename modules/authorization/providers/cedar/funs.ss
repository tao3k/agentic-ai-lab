;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: bind an admitted Governance composition to one Cedar authority input.
;;; Invariant: this adapter only constructs inert POO values; the independent
;;; Rust+Lean Runtime Host remains the sole dual-engine execution boundary.
(import (only-in :clan/poo/object .cc)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :agentic-ai-lab/modules/authorization/providers/cedar/objects
                 agentic-ai-lab-cedar-authority-snapshot
                 agentic-ai-lab-cedar-policy)
        (only-in "contracts.ss" agentic-ai-lab-cedar-governance-contract))

(export agentic-ai-lab-cedar-governance-snapshot
        agentic-ai-lab-cedar-policy-file)

;; Load the exact exported Cedar artifact as an inert POO policy value.
;; Cedar syntax and policy-set expansion remain owned by the native boundary.
(def (agentic-ai-lab-cedar-policy-file identity path)
  (unless (and (string? path)
               (>= (string-length path) 6)
               (string=? (substring path (- (string-length path) 6)
                                    (string-length path))
                         ".cedar"))
    (error "Cedar policy file must be an exported .cedar artifact" path))
  (agentic-ai-lab-cedar-policy
   identity
   (call-with-input-file path read-all-as-string)))

(def (agentic-ai-lab-cedar-governance-snapshot
      composition-identity profile-values assessment-values
      context-value proof-value policy-values
      schema-value entities-value capability-values)
  (agentic-ai-lab-cedar-governance-contract
   composition-identity profile-values assessment-values proof-value)
  (.cc
   (agentic-ai-lab-cedar-authority-snapshot
    context-value proof-value policy-values schema-value entities-value
    capability-values)
   'governance-assessments assessment-values))
