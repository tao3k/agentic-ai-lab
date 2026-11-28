;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Generic Higher-Order Governance Rule combinators, reusable
;;; multi-party principal/role/scope/depth rules, and rule-driven ThreatModel
;;; & Profile composition built natively on agentic-ai-lab POO contracts.
;;;
;;; Invariant: Rules produce semantic GovernanceAssessments (`runtime-executed? #f`);
;;; assessment NEVER implies execution authority without an explicit runtime
;;; Provider or Strict-Mediated AuthorizedEffectToken handoff.

(import (only-in :clan/poo/object .cc .o .ref .slot? object?)
        (only-in :clan/poo/mop .defgeneric)
        (only-in :clan/poo/type define-type Type. element? validate)
        (only-in :std/list/list every filter)
        (only-in :tao3k/agentic-ai-lab/modules/governance/types
                 AgenticAILabGovernanceProfile
                 AgenticAILabGovernanceThreatModel
                 agentic-ai-lab-governance-profile?
                 agentic-ai-lab-governance-threat-model-kind)
        (only-in :tao3k/agentic-ai-lab/modules/governance/objects
                 AgenticAILabGovernanceThreatModel.
                 agentic-ai-lab-governance-precondition
                 agentic-ai-lab-governance-threat
                 agentic-ai-lab-governance-threat-blocking?
                 agentic-ai-lab-governance-assessment-value))

(export agentic-ai-lab-governance-rule-kind
        agentic-ai-lab-governance-rule-result-kind
        AgenticAILabGovernanceRuleResult
        AgenticAILabGovernanceRule
        agentic-ai-lab-governance-rule-result?
        agentic-ai-lab-governance-rule?
        agentic-ai-lab-governance-evaluate-rule
        agentic-ai-lab-governance-rule-allow
        agentic-ai-lab-governance-rule-deny
        agentic-ai-lab-governance-rule
        agentic-ai-lab-governance-compose-all
        agentic-ai-lab-governance-compose-any
        agentic-ai-lab-governance-guard-when
        agentic-ai-lab-governance-negate
        agentic-ai-lab-governance-context-ref
        agentic-ai-lab-governance-require-principal-kind
        agentic-ai-lab-governance-require-actor-roles
        agentic-ai-lab-governance-require-scope-subset
        agentic-ai-lab-governance-require-chain-depth-within
        agentic-ai-lab-governance-rule-threat-model
        agentic-ai-lab-governance-profile-extend)

(def agentic-ai-lab-governance-rule-kind 'agentic-ai-lab.governance-rule)
(def agentic-ai-lab-governance-rule-result-kind 'agentic-ai-lab.governance-rule-result)

(def (rule-text? value)
  (and (string? value) (> (string-length value) 0)))

(def (rule-severity? value)
  (and (memq value '(low moderate high critical)) #t))

(def (rule-has-slots? value slots)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot)) slots)))

;;; Open POO dispatch for rule evaluation.
(.defgeneric (agentic-ai-lab-governance-evaluate-rule rule context)
  slot: .evaluate-rule)

(def (governance-rule-result-shape? value)
  (and (rule-has-slots?
        value '(kind rule-identity allowed? severity code reason mitigations))
       (eq? (.ref value 'kind) agentic-ai-lab-governance-rule-result-kind)
       (rule-text? (.ref value 'rule-identity))
       (boolean? (.ref value 'allowed?))
       (rule-severity? (.ref value 'severity))
       (symbol? (.ref value 'code))
       (rule-text? (.ref value 'reason))
       (list? (.ref value 'mitigations))
       (every rule-text? (.ref value 'mitigations))))

(define-type (AgenticAILabGovernanceRuleResult @ Type.)
  .element?: governance-rule-result-shape?)

(def (governance-rule-shape? value)
  (and (rule-has-slots? value '(kind identity severity .evaluate-rule))
       (eq? (.ref value 'kind) agentic-ai-lab-governance-rule-kind)
       (rule-text? (.ref value 'identity))
       (rule-severity? (.ref value 'severity))
       (procedure? (.ref value '.evaluate-rule))))

(define-type (AgenticAILabGovernanceRule @ Type.)
  .element?: governance-rule-shape?)

(def (agentic-ai-lab-governance-rule-result? value)
  (element? AgenticAILabGovernanceRuleResult value))

(def (agentic-ai-lab-governance-rule? value)
  (element? AgenticAILabGovernanceRule value))

;;; Safe slot/hash lookup over either POO objects or Gerbil hash tables.
(def (agentic-ai-lab-governance-context-ref context key default: (default-value #f))
  (cond
   ((and (object? context) (.slot? context key))
    (.ref context key))
   ((hash-table? context)
    (hash-ref context key default-value))
   (else default-value)))

(def (agentic-ai-lab-governance-rule-allow rule-identity-value code-value reason-value
                                           severity: (severity-value 'high)
                                           mitigations: (mitigation-values '()))
  (validate
   AgenticAILabGovernanceRuleResult
   (.o kind: agentic-ai-lab-governance-rule-result-kind
       rule-identity: rule-identity-value
       allowed?: #t
       severity: severity-value
       code: code-value
       reason: reason-value
       mitigations: (if (null? mitigation-values)
                      (list reason-value)
                      mitigation-values))))

(def (agentic-ai-lab-governance-rule-deny rule-identity-value code-value reason-value
                                          severity: (severity-value 'high)
                                          mitigations: (mitigation-values '()))
  (validate
   AgenticAILabGovernanceRuleResult
   (.o kind: agentic-ai-lab-governance-rule-result-kind
       rule-identity: rule-identity-value
       allowed?: #f
       severity: severity-value
       code: code-value
       reason: reason-value
       mitigations: mitigation-values)))

;;; Construct a validated POO higher-order governance rule.
(def (agentic-ai-lab-governance-rule identity-value evaluator
                                     severity: (severity-value 'high))
  (unless (procedure? evaluator)
    (error "governance rule requires evaluator procedure" identity-value evaluator))
  (validate
   AgenticAILabGovernanceRule
   (.o kind: agentic-ai-lab-governance-rule-kind
       identity: identity-value
       severity: severity-value
       .evaluate-rule:
       (lambda (context)
         (validate AgenticAILabGovernanceRuleResult (evaluator context))))))

;;; Higher-order combinator: fail-closed conjunction over a list of rules.
;;; Returns the first denial encountered, or allow when every rule permits.
(def (agentic-ai-lab-governance-compose-all identity-value rules
                                            severity: (severity-value 'high))
  (unless (and (list? rules) (every agentic-ai-lab-governance-rule? rules))
    (error "compose-all requires a list of AgenticAILabGovernanceRule values" rules))
  (agentic-ai-lab-governance-rule
   identity-value
   (lambda (context)
     (let loop ((rest rules))
       (if (null? rest)
         (agentic-ai-lab-governance-rule-allow
          identity-value 'composed-all-allow "all composed governance rules passed"
          severity: severity-value)
         (let (result (agentic-ai-lab-governance-evaluate-rule (car rest) context))
           (if (.ref result 'allowed?)
             (loop (cdr rest))
             result)))))
   severity: severity-value))

;;; Higher-order combinator: disjunction over a list of rules (fail-closed if empty).
(def (agentic-ai-lab-governance-compose-any identity-value rules
                                            severity: (severity-value 'high))
  (unless (and (list? rules) (every agentic-ai-lab-governance-rule? rules))
    (error "compose-any requires a list of AgenticAILabGovernanceRule values" rules))
  (agentic-ai-lab-governance-rule
   identity-value
   (lambda (context)
     (let loop ((rest rules)
                (last-deny
                 (agentic-ai-lab-governance-rule-deny
                  identity-value 'composed-any-empty
                  "fail-closed: no governance rule matched"
                  severity: severity-value)))
       (if (null? rest)
         last-deny
         (let (result (agentic-ai-lab-governance-evaluate-rule (car rest) context))
           (if (.ref result 'allowed?)
             result
             (loop (cdr rest) result))))))
   severity: severity-value))

;;; Higher-order combinator: evaluate `rule` only when `(predicate context)` is true.
(def (agentic-ai-lab-governance-guard-when identity-value predicate rule
                                           severity: (severity-value 'high))
  (unless (and (procedure? predicate) (agentic-ai-lab-governance-rule? rule))
    (error "guard-when requires a predicate procedure and governance rule" identity-value))
  (agentic-ai-lab-governance-rule
   identity-value
   (lambda (context)
     (if (predicate context)
       (agentic-ai-lab-governance-evaluate-rule rule context)
       (agentic-ai-lab-governance-rule-allow
        identity-value 'guard-not-applicable "guard predicate not triggered"
        severity: severity-value)))
   severity: severity-value))

;;; Higher-order combinator: invert an existing governance rule with explicit reason.
(def (agentic-ai-lab-governance-negate identity-value rule code reason
                                       severity: (severity-value 'high))
  (unless (agentic-ai-lab-governance-rule? rule)
    (error "negate requires an AgenticAILabGovernanceRule" rule))
  (agentic-ai-lab-governance-rule
   identity-value
   (lambda (context)
     (let (result (agentic-ai-lab-governance-evaluate-rule rule context))
       (if (.ref result 'allowed?)
         (agentic-ai-lab-governance-rule-deny
          identity-value code reason severity: severity-value)
         (agentic-ai-lab-governance-rule-allow
          identity-value 'negated-allow "negated rule condition did not hold"
          severity: severity-value))))
   severity: severity-value))

;;; Reusable rule: require `actor-kind` in context to match `expected-kind` (e.g. 'human).
(def (agentic-ai-lab-governance-require-principal-kind
      identity-value expected-kind
      severity: (severity-value 'critical))
  (agentic-ai-lab-governance-rule
   identity-value
   (lambda (context)
     (let (actual (agentic-ai-lab-governance-context-ref context 'actor-kind))
       (if (eq? actual expected-kind)
         (agentic-ai-lab-governance-rule-allow
          identity-value 'principal-kind-verified
          (string-append "principal kind matches " (symbol->string expected-kind))
          severity: severity-value)
         (agentic-ai-lab-governance-rule-deny
          identity-value 'principal-kind-rejected
          (string-append "principal kind must be " (symbol->string expected-kind))
          severity: severity-value))))
   severity: severity-value))

;;; Reusable rule: require `actor-role` to belong to `allowed-roles`.
(def (agentic-ai-lab-governance-require-actor-roles
      identity-value allowed-roles
      severity: (severity-value 'high))
  (agentic-ai-lab-governance-rule
   identity-value
   (lambda (context)
     (let (role (agentic-ai-lab-governance-context-ref context 'actor-role))
       (if (and role (memq role allowed-roles))
         (agentic-ai-lab-governance-rule-allow
          identity-value 'actor-role-authorized "actor role is authorized"
          severity: severity-value)
         (agentic-ai-lab-governance-rule-deny
          identity-value 'actor-role-unauthorized "actor role is not in authorized role set"
          severity: severity-value))))
   severity: severity-value))

;;; Reusable rule: ensure `requested-slot` scopes are a subset of `allowed-scopes`.
(def (agentic-ai-lab-governance-require-scope-subset
      identity-value requested-slot allowed-scopes
      severity: (severity-value 'high))
  (agentic-ai-lab-governance-rule
   identity-value
   (lambda (context)
     (let (requested (agentic-ai-lab-governance-context-ref context requested-slot default: '()))
       (if (and (list? requested)
                (every (lambda (scope) (and (member scope allowed-scopes) #t))
                       requested))
         (agentic-ai-lab-governance-rule-allow
          identity-value 'scope-subset-valid "requested scopes stay within ceiling"
          severity: severity-value)
         (agentic-ai-lab-governance-rule-deny
          identity-value 'scope-escalation-denied
          "requested scopes exceed allowed ceiling"
          severity: severity-value))))
   severity: severity-value))

;;; Reusable rule: enforce a maximum numeric chain depth (e.g. anti-loop guardrail).
(def (agentic-ai-lab-governance-require-chain-depth-within
      identity-value depth-slot max-depth
      severity: (severity-value 'high))
  (agentic-ai-lab-governance-rule
   identity-value
   (lambda (context)
     (let (depth (agentic-ai-lab-governance-context-ref context depth-slot default: 0))
       (if (and (integer? depth) (>= depth 0) (<= depth max-depth))
         (agentic-ai-lab-governance-rule-allow
          identity-value 'chain-depth-within-limit "chain depth within configured ceiling"
          severity: severity-value)
         (agentic-ai-lab-governance-rule-deny
          identity-value 'chain-depth-exceeded "chain depth exceeds configured ceiling"
          severity: severity-value))))
   severity: severity-value))

(def (rule-result->threat result)
  (let* ((allowed? (.ref result 'allowed?))
         (reason (.ref result 'reason))
         (rule-id (.ref result 'rule-identity))
         (precondition
          (agentic-ai-lab-governance-precondition
           (string-append rule-id "/precondition")
           (not allowed?)
           reason)))
    (agentic-ai-lab-governance-threat
     rule-id
     (.ref result 'severity)
     (if allowed? 'mitigated 'realized)
     (list precondition)
     mitigations: (if allowed? (.ref result 'mitigations) '()))))

;;; Bridge higher-order rules directly into an `AgenticAILabGovernanceThreatModel.`
;;; whose `.assess-threats` dynamically evaluates every rule against `context`
;;; and returns a validated `AgenticAILabGovernanceAssessment`.
(def (agentic-ai-lab-governance-rule-threat-model identity-value rule-values)
  (unless (and (list? rule-values) (every agentic-ai-lab-governance-rule? rule-values))
    (error "rule-threat-model requires a list of AgenticAILabGovernanceRule values" rule-values))
  (validate
   AgenticAILabGovernanceThreatModel
   (.o (:: @ AgenticAILabGovernanceThreatModel.)
       kind: agentic-ai-lab-governance-threat-model-kind
       identity: identity-value
       threats: '()
       rules: rule-values
       .assess-threats:
       (lambda (profile context)
         (let* ((results
                 (map (lambda (rule)
                        (agentic-ai-lab-governance-evaluate-rule rule context))
                      rule-values))
                (evaluated-threats (map rule-result->threat results))
                (unresolved
                 (map (lambda (threat) (.ref threat 'identity))
                      (filter agentic-ai-lab-governance-threat-blocking?
                              evaluated-threats)))
                (snapshot-model
                 (.o (:: @ AgenticAILabGovernanceThreatModel.)
                     identity: identity-value
                     threats: evaluated-threats)))
           (agentic-ai-lab-governance-assessment-value
            profile snapshot-model unresolved context))))))

;;; Compose a specialized domain Profile over an existing `AgenticAILabGovernanceProfile.`.
(def (agentic-ai-lab-governance-profile-extend
      base-profile
      identity: identity-value
      revision: revision-value
      owner: owner-value
      ontology: (ontology-value (.o))
      policies: (policies-value (.o))
      source-assets: (source-assets-value '())
      threat-model: (threat-model-value #f))
  (unless (object? base-profile)
    (error "profile-extend requires a base POO profile object" base-profile))
  (let* ((base-assets (if (.slot? base-profile 'source-assets)
                        (.ref base-profile 'source-assets)
                        '()))
         (effective-threat-model
          (or threat-model-value
              (.ref base-profile 'threat-model))))
    (validate
     AgenticAILabGovernanceProfile
     (.cc base-profile
          identity: identity-value
          revision: revision-value
          owner: owner-value
          ontology: ontology-value
          policies: policies-value
          source-assets: (append base-assets source-assets-value)
          threat-model: effective-threat-model))))
