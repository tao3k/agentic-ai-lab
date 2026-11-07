;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: bind an admitted Governance composition to one Cedar authority input.
;;; Invariant: this adapter only constructs inert POO values; the independent
;;; Rust+Lean Runtime Host remains the sole dual-engine execution boundary.
(import (only-in :clan/poo/object .cc .ref)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :agentic-ai-lab/modules/authorization/providers/cedar/objects
                 agentic-ai-lab-cedar-authority-snapshot
                 agentic-ai-lab-cedar-policy
                 agentic-ai-lab-cedar-authorization-request
                 agentic-ai-lab-cedar-runtime-handoff)
        (only-in :agentic-ai-lab/modules/temporal-causality/runtime/durable-journal
                 journal-pack journal-unpack journal-hash)
        (only-in "contracts.ss" agentic-ai-lab-cedar-governance-contract))

(export agentic-ai-lab-cedar-governance-snapshot
        agentic-ai-lab-cedar-policy-file
        agentic-ai-lab-cedar-workspace-retry-request)

;; Construct the existing Cedar request from owner-admitted bytes. The
;; subject and runtime roots come from the trusted deployment.
(def (agentic-ai-lab-cedar-workspace-retry-request admitted subject sequence-value
                                                 semantic-root execution-root)
  (let* ((command (.ref admitted 'command))
         (packed-command (journal-pack command))
         (packed-receipt (.ref admitted 'receipt))
         (decision-digest (.ref admitted 'digest))
         (original-digest (journal-hash (journal-pack (.ref admitted 'original)))))
    (unless (and (eq? (.ref command 'operation) 'workspace-retry-consume)
                 (equal? decision-digest (.ref (.ref command 'body) 'decision-digest))
                 (equal? decision-digest (journal-hash packed-receipt)))
      (error "Cedar retry request requires its exact Durable receipt"))
    (let* ((evidence (.ref (journal-unpack packed-receipt) 'evidence))
           (observations (.ref evidence 'outcome-observations)))
      (unless (and (pair? observations) (null? (cdr observations)))
        (error "Cedar workspace retry requires one coherent workspace read"))
      (agentic-ai-lab-cedar-authorization-request
        (.ref subject 'principal) (.ref subject 'action) (.ref subject 'resource)
        (.ref subject 'context) (journal-hash packed-command)
        (agentic-ai-lab-cedar-runtime-handoff
          sequence-value
          (string->utf8 (journal-pack (list packed-command original-digest)))
          semantic-root execution-root execution-root (.ref (car observations) 'digest))))))

;; Load the exact exported Cedar artifact as an inert POO policy value.
;; Cedar syntax and policy-set expansion remain owned by the runtime boundary.
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
