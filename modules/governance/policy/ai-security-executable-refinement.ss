;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Provider-neutral AI-security executable refinement.
;;;
;;; Boundary: provider adapters normalize logs into the POO-native envelope.
;;; This module owns only pure policy transition and versioned proof receipts.

(import (only-in :clan/poo/object .def .mix .o .ref)
        (only-in :std/list/list every filter-map)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :yuanxu/utilities/functional
                 yuanxu-set-subset?))

(export agentic-ai-lab-agent-action-evidence-envelope
        agentic-ai-lab-agent-action-evidence-envelope->projection
        agentic-ai-lab-ai-security-transition-policy
        agentic-ai-lab-ai-security-transition-prototype
        agentic-ai-lab-ai-security-transition-engine
        agentic-ai-lab-ai-security-reference-transition
        agentic-ai-lab-ai-security-transition-replay-valid?)

(def action-evidence-envelope-schema
  'agentic-ai-lab.ai-security.action-evidence-envelope.v1)

(def executable-transition-receipt-schema
  'agentic-ai-lab.ai-security.executable-transition-receipt.v1)

;; : (-> Object String)
(def (canonical-digest value)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8
      (call-with-output-string
       (lambda (port) (write value port))))))))

;; : (-> Symbol MaybeSymbol Symbol Symbol Symbol Symbol Symbol Symbol String String [Symbol] [Symbol] PooAgentActionEvidenceEnvelope)
(def (agentic-ai-lab-agent-action-evidence-envelope
      action-id parent-action-id observation-event-id recovery-decision-id
      actor-identity tool-identity capability-id effect-domain evidence-root
      trace-parent-root requested-effects allowed-effects)
  (let ((action-id-value action-id)
        (parent-action-id-value parent-action-id)
        (observation-event-id-value observation-event-id)
        (recovery-decision-id-value recovery-decision-id)
        (actor-identity-value actor-identity)
        (tool-identity-value tool-identity)
        (capability-id-value capability-id)
        (effect-domain-value effect-domain)
        (evidence-root-value evidence-root)
        (trace-parent-root-value trace-parent-root)
        (requested-effect-values requested-effects)
        (allowed-effect-values allowed-effects))
    (.o (kind 'agentic-ai-lab-agent-action-evidence-envelope)
        (schema action-evidence-envelope-schema)
        (schema-version "1")
        (action-id action-id-value)
        (parent-action-id parent-action-id-value)
        (observation-event-id observation-event-id-value)
        (recovery-decision-id recovery-decision-id-value)
        (actor-identity actor-identity-value)
        (tool-identity tool-identity-value)
        (capability-id capability-id-value)
        (effect-domain effect-domain-value)
        (evidence-root evidence-root-value)
        (trace-parent-root trace-parent-root-value)
        (requested-effects requested-effect-values)
        (allowed-effects allowed-effect-values))))

;; : (-> PooAgentActionEvidenceEnvelope Alist)
(def (agentic-ai-lab-agent-action-evidence-envelope->projection envelope)
  (unless (eq? (.ref envelope 'kind)
               'agentic-ai-lab-agent-action-evidence-envelope)
    (error "projection requires AgentActionEvidenceEnvelope" envelope))
  (list
   (cons 'schemaId (.ref envelope 'schema))
   (cons 'schemaVersion (.ref envelope 'schema-version))
   (cons 'actionId (.ref envelope 'action-id))
   (cons 'parentActionId (.ref envelope 'parent-action-id))
   (cons 'observationEventId (.ref envelope 'observation-event-id))
   (cons 'recoveryDecisionId (.ref envelope 'recovery-decision-id))
   (cons 'actorIdentity (.ref envelope 'actor-identity))
   (cons 'toolIdentity (.ref envelope 'tool-identity))
   (cons 'capabilityId (.ref envelope 'capability-id))
   (cons 'effectDomain (.ref envelope 'effect-domain))
   (cons 'evidenceRoot (.ref envelope 'evidence-root))
   (cons 'traceParentRoot (.ref envelope 'trace-parent-root))
   (cons 'requestedEffects (.ref envelope 'requested-effects))
   (cons 'allowedEffects (.ref envelope 'allowed-effects))))

;; : (-> [Symbol] Symbol [Symbol] MaybeSymbol String PooAiSecurityTransitionPolicy)
(def (agentic-ai-lab-ai-security-transition-policy
      granted-capabilities expected-tool-identity allowed-effect-domains
      expected-parent-action-id expected-trace-parent-root)
  (let ((granted-capability-values granted-capabilities)
        (expected-tool-identity-value expected-tool-identity)
        (allowed-effect-domain-values allowed-effect-domains)
        (expected-parent-action-id-value expected-parent-action-id)
        (expected-trace-parent-root-value expected-trace-parent-root))
    (.o (kind 'agentic-ai-lab-ai-security-transition-policy)
        (schema 'agentic-ai-lab.ai-security.transition-policy.v1)
        (schema-version "1")
        (granted-capabilities granted-capability-values)
        (expected-tool-identity expected-tool-identity-value)
        (allowed-effect-domains allowed-effect-domain-values)
        (expected-parent-action-id expected-parent-action-id-value)
        (expected-trace-parent-root expected-trace-parent-root-value))))

;; : (-> PooAgentActionEvidenceEnvelope List)
(def (envelope-identity envelope)
  (list action-evidence-envelope-schema
        "1"
        (.ref envelope 'action-id)
        (.ref envelope 'parent-action-id)
        (.ref envelope 'observation-event-id)
        (.ref envelope 'recovery-decision-id)
        (.ref envelope 'actor-identity)
        (.ref envelope 'tool-identity)
        (.ref envelope 'capability-id)
        (.ref envelope 'effect-domain)
        (.ref envelope 'evidence-root)
        (.ref envelope 'trace-parent-root)
        (.ref envelope 'requested-effects)
        (.ref envelope 'allowed-effects)))

;; : (-> Symbol Boolean String PooAiSecurityInvariantEvidence)
(def (invariant-receipt name satisfied reason)
  (let (reason-value reason)
    (.o (kind 'agentic-ai-lab-ai-security-invariant-evidence)
        (invariant name)
        (satisfied? satisfied)
        (reason reason-value))))

;; : (-> PooAiSecurityInvariantEvidence List)
(def (invariant-identity invariant)
  (list (.ref invariant 'invariant)
        (.ref invariant 'satisfied?)
        (.ref invariant 'reason)))

;; : (-> [PooAiSecurityInvariantEvidence] [Symbol])
(def (failed-invariants invariants)
  (filter-map
   (lambda (invariant)
     (and (not (.ref invariant 'satisfied?))
          (.ref invariant 'invariant)))
   invariants))

;; : (-> Symbol Boolean String String POOObject)
(def (described-invariant name accepted? accepted-reason rejected-reason)
  (invariant-receipt name
                     accepted?
                     (if accepted? accepted-reason rejected-reason)))

;;; Reference transition: evaluate the full invariant set and return an auditable denial or acceptance receipt.
;; : (-> PooAgentActionEvidenceEnvelope PooAiSecurityTransitionPolicy PooAiSecurityTransitionReceipt)
(def (agentic-ai-lab-ai-security-reference-transition envelope policy)
  (unless (eq? (.ref envelope 'kind)
               'agentic-ai-lab-agent-action-evidence-envelope)
    (error "reference transition requires AgentActionEvidenceEnvelope" envelope))
  (unless (eq? (.ref policy 'kind)
               'agentic-ai-lab-ai-security-transition-policy)
    (error "reference transition requires TransitionPolicy" policy))
  (let* ((capability-ok
          (and (member (.ref envelope 'capability-id)
                       (.ref policy 'granted-capabilities))
               #t))
         (tool-ok
          (equal? (.ref envelope 'tool-identity)
                  (.ref policy 'expected-tool-identity)))
         (effect-ok
          (and (member (.ref envelope 'effect-domain)
                       (.ref policy 'allowed-effect-domains))
               (yuanxu-set-subset? (.ref envelope 'requested-effects)
                                     (.ref envelope 'allowed-effects))))
         (causal-ok
          (and (equal? (.ref envelope 'parent-action-id)
                       (.ref policy 'expected-parent-action-id))
               (equal? (.ref envelope 'trace-parent-root)
                       (.ref policy 'expected-trace-parent-root))))
         (invariants
          (list
           (described-invariant
            'capability-confinement capability-ok
            "capability is explicitly granted"
            "capability is outside the granted set")
           (described-invariant
            'tool-identity tool-ok
            "tool identity matches policy"
            "tool identity does not match policy")
           (described-invariant
            'effect-containment effect-ok
            "effect domain and requested effects are contained"
            "effect domain or requested effects escape containment")
           (described-invariant
            'causal-continuity causal-ok
            "parent action and trace root are continuous"
            "parent action or trace root breaks causal continuity")))
         (failures (failed-invariants invariants))
         (decision (if (null? failures) 'accepted 'fail-closed))
         (envelope-digest (canonical-digest (envelope-identity envelope)))
         (output-identity
          (list decision (map invariant-identity invariants) failures))
         (output-digest (canonical-digest output-identity))
         (trace-root
          (canonical-digest
           (list envelope-digest output-digest
                 (.ref envelope 'evidence-root)
                 (.ref envelope 'trace-parent-root)))))
    (let ((envelope-digest-value envelope-digest)
          (decision-value decision)
          (invariant-values invariants)
          (output-digest-value output-digest)
          (trace-root-value trace-root))
      (.o (kind 'agentic-ai-lab-ai-security-executable-transition-receipt)
        (schema executable-transition-receipt-schema)
        (schema-version "1")
        (envelope-digest envelope-digest-value)
        (decision decision-value)
        (invariants invariant-values)
        (escalation-reasons failures)
        (output-digest output-digest-value)
        (trace-root trace-root-value)))))

;; : (-> PooAiSecurityTransitionReceipt List)
(def (receipt-identity receipt)
  (list (.ref receipt 'schema)
        (.ref receipt 'schema-version)
        (.ref receipt 'envelope-digest)
        (.ref receipt 'decision)
        (map invariant-identity (.ref receipt 'invariants))
        (.ref receipt 'escalation-reasons)
        (.ref receipt 'output-digest)
        (.ref receipt 'trace-root)))

;; : (-> PooAgentActionEvidenceEnvelope PooAiSecurityTransitionPolicy PooAiSecurityTransitionReceipt Boolean)
(def (agentic-ai-lab-ai-security-transition-replay-valid? envelope policy receipt)
  (equal? (receipt-identity
           (agentic-ai-lab-ai-security-reference-transition envelope policy))
          (receipt-identity receipt)))

;;; The public extension point is an ordinary POO prototype.  Downstream policy
;;; modules compose it with `.mix`; the execution slot remains a pure function.
(.def agentic-ai-lab-ai-security-transition-prototype
  (kind 'agentic-ai-lab-ai-security-transition-engine)
  (schema 'agentic-ai-lab.ai-security.transition-engine.v1)
  (schema-version "1")
  (execute agentic-ai-lab-ai-security-reference-transition)
  (replay-valid? agentic-ai-lab-ai-security-transition-replay-valid?))

;; : (-> [POOObject] PooAiSecurityTransitionEngine)
(def (agentic-ai-lab-ai-security-transition-engine . policy-prototypes)
  (.mix policy-prototypes agentic-ai-lab-ai-security-transition-prototype))
