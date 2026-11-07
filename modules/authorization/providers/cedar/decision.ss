;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Cedar Provider evaluates policy while Scheme POO owns semantic token meaning.
;;; Invariant: a Cedar decision cannot mint or reinterpret authorized-effect evidence.
(import (only-in :clan/poo/object .o .ref)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        :agentic-ai-lab/modules/governance/policy/authorized-effect-token)

(export agentic-ai-lab-cedar-decision
        agentic-ai-lab-cedar-decision-permit?
        agentic-ai-lab-cedar-decision->semantic-root
        agentic-ai-lab-cedar-decision->authorized-effect-token)

(def (decision-digest value)
  (hex-encode
   (sha256
    (string->utf8
     (call-with-output-string (lambda (port) (write value port)))))))

(def (agentic-ai-lab-cedar-decision identity decision-outcome policy-identity
                              policy-hash entity-hash reason-list)
  (unless (memq decision-outcome '(permit forbid indeterminate))
    (error "unknown Cedar decision outcome" decision-outcome))
  (let* ((canonical
          (list 'agentic-ai-lab.cedar-decision.draft.1 identity decision-outcome
                policy-identity policy-hash entity-hash reason-list))
         (decision-hash (decision-digest canonical)))
    (.o (kind 'agentic-ai-lab-cedar-decision)
        (schema 'agentic-ai-lab.cedar-decision.draft.1)
        (decision-id identity)
        (outcome decision-outcome)
        (policy-id policy-identity)
        (policy-digest policy-hash)
        (entity-digest entity-hash)
        (reasons reason-list)
        (decision-digest decision-hash))))

(def (agentic-ai-lab-cedar-decision-permit? decision)
  (eq? (.ref decision 'outcome) 'permit))

(def (agentic-ai-lab-cedar-decision->semantic-root decision bundle-digest
                                              intent-digest)
  (agentic-ai-lab-semantic-root
   bundle-digest
   (.ref decision 'policy-digest)
   (.ref decision 'entity-digest)
   (.ref decision 'decision-digest)
   intent-digest))

(def (agentic-ai-lab-cedar-decision->authorized-effect-token
      decision token-id nonce semantic-root binding validity durability
      evidence-bits issuer signature)
  (unless (agentic-ai-lab-cedar-decision-permit? decision)
    (error "Cedar forbid/indeterminate cannot issue AuthorizedEffectToken"))
  (unless (and (equal? (.ref decision 'policy-digest)
                       (.ref binding 'policy-digest))
               (equal? (.ref decision 'entity-digest)
                       (.ref binding 'entity-digest))
               (equal? (.ref decision 'decision-digest)
                       (.ref binding 'decision-digest))
               (equal? (.ref semantic-root 'digest)
                       (.ref (agentic-ai-lab-cedar-decision->semantic-root
                              decision
                              (.ref binding 'bundle-digest)
                              (.ref binding 'intent-digest))
                             'digest)))
    (error "Cedar decision/binding/semantic-root mismatch"))
  (agentic-ai-lab-authorized-effect-token
   token-id nonce semantic-root binding validity durability evidence-bits
   issuer signature))
