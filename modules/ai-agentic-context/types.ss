;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Boundary shapes and invariants; no construction or runtime effects.
(import (only-in :clan/poo/object .ref .slot? object? .cc)
        (only-in :clan/poo/type Record Exactly True Or)
        (only-in :clan/poo/type Type. define-type Fun)
        (only-in :std/list/list every)
        (only-in :tao3k/agentic-ai-lab/modules/temporal-causality/time/types agentic-ai-lab-temporal-interval?))
(export ContextScopeContract ContextMemoryScopeContract
        AiAgenticContextTemporalPolicyType agentic-ai-lab-ai-agentic-context-temporal-policy-shape?
        AiAgenticContextOrgAnchorType agentic-ai-lab-ai-agentic-context-org-anchor-shape?
        AiAgenticContextOrgPropertyType agentic-ai-lab-ai-agentic-context-org-property-shape?
        AiAgenticContextGovernanceGraphType agentic-ai-lab-ai-agentic-context-governance-graph-shape?
        AiAgenticContextOrgElementGraphType agentic-ai-lab-ai-agentic-context-org-element-graph-shape?
        AiAgenticContextProgressiveRuleConfigType agentic-ai-lab-ai-agentic-context-progressive-rule-config-shape?
        AiAgenticContextAgentAffinityType agentic-ai-lab-ai-agentic-context-agent-affinity-shape?
        AiAgenticContextSubtreeProposalType agentic-ai-lab-ai-agentic-context-subtree-proposal-shape?
        AiAgenticContextSubtreeCommitReceiptType agentic-ai-lab-ai-agentic-context-subtree-commit-receipt-shape?
        AiAgenticContextTrustRoleType agentic-ai-lab-ai-agentic-context-trust-role?
        AiAgenticContextEndorsementReceiptType agentic-ai-lab-ai-agentic-context-endorsement-receipt-shape?
        AiAgenticContextRestrictionEnvelopeType agentic-ai-lab-ai-agentic-context-restriction-envelope-shape?
        AiAgenticContextOmittedAlternativesReceiptType agentic-ai-lab-ai-agentic-context-omitted-alternatives-receipt-shape?
        AiAgenticContextEpistemicProjectionType agentic-ai-lab-ai-agentic-context-epistemic-projection-shape?
        AiAgenticContextDeclassificationCertType agentic-ai-lab-ai-agentic-context-declassification-cert-shape?
        AiAgenticContextConsolidationReceiptType agentic-ai-lab-ai-agentic-context-consolidation-receipt-shape?
        AiAgenticContextDeltaType agentic-ai-lab-ai-agentic-context-delta-shape?
        AiAgenticContextScopeType AiAgenticContextAdmissionType agentic-ai-lab-ai-agentic-context-scope-shape?)
(def CoreFeatureIds (Exactly '(ai-agentic-context/core)))
(def MemoryFeatureIds (Exactly '(ai-agentic-context/core ai-agentic-context/memory)))
(def ContextScopeContract
  (.cc (Record config: [(Record)]
               profile: [(Record accepted?: [True] feature-ids: [(Or CoreFeatureIds MemoryFeatureIds)])])
    identity: 'ai-agentic-context/scope))
(def ContextMemoryScopeContract
  (.cc (Record profile: [(Record accepted?: [True] feature-ids: [MemoryFeatureIds])])
    identity: 'ai-agentic-context/memory-scope))

(def (name? x) (and (string? x) (< 0 (string-length x) 257)))
(def (agentic-ai-lab-ai-agentic-context-scope-shape? spec)
  (and (object? spec)
       (every (lambda (k) (and (.slot? spec k) (name? (.ref spec k))))
              '(bundle organization project worktree source-cut actor task destination))
       (.slot? spec 'kind)
       (eq? (.ref spec 'kind) 'agentic-ai-lab.ai-agentic-context.scope.v1)
       (.slot? spec 'epoch)
       (exact-integer? (.ref spec 'epoch)) (>= (.ref spec 'epoch) 0)
       (.slot? spec 'session) (.slot? spec 'turn)
       (or (and (eq? (.ref spec 'session) #f) (eq? (.ref spec 'turn) #f))
           (and (name? (.ref spec 'session))
                (exact-integer? (.ref spec 'turn)) (>= (.ref spec 'turn) 0)))))
(define-type (AiAgenticContextScopeType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-scope-shape?)

;; One library-owned identity survives Module role projection and composition.
(def AiAgenticContextAdmissionType
  (Fun AiAgenticContextScopeType <- AiAgenticContextScopeType))

(def (unit? value identity)
  (and (pair? value) (equal? (car value) identity) (list? (cdr value))))
(def (edit? value)
  (and (object? value)
       (every (lambda (k) (.slot? value k)) '(kind identity expected replacement))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.edit.v1)
       (string? (.ref value 'identity))
       (let ((old (.ref value 'expected)) (new (.ref value 'replacement)))
         (and (or old new)
              (or (eq? old #f) (unit? old (.ref value 'identity)))
              (or (eq? new #f) (unit? new (.ref value 'identity)))))))
(def (agentic-ai-lab-ai-agentic-context-delta-shape? value)
  (and (object? value)
       (every (lambda (k) (.slot? value k)) '(kind base-digest target-digest edits order))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.delta.v1)
       (string? (.ref value 'base-digest)) (string? (.ref value 'target-digest))
       (list? (.ref value 'edits)) (<= (length (.ref value 'edits)) 512)
       (every edit? (.ref value 'edits))
       (list? (.ref value 'order)) (<= (length (.ref value 'order)) 256)
       (every string? (.ref value 'order))))
(define-type (AiAgenticContextDeltaType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-delta-shape?)

(def (agentic-ai-lab-ai-agentic-context-org-anchor-shape? value)
  (and (object? value)
       (every (lambda (key) (.slot? value key))
          '(kind org-id container-kind container-start value-start value-end source-digest parser-identity
            projection-digest scope-digest session turn semantic-digest source-authenticated? action-authorized?))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.org-anchor.v1)
       (every (lambda (key) (name? (.ref value key)))
          '(org-id source-digest parser-identity projection-digest scope-digest session semantic-digest))
       (memq (.ref value 'container-kind) '(OrgFile OrgSection))
       (every (lambda (key) (and (exact-integer? (.ref value key)) (>= (.ref value key) 0)))
          '(container-start value-start value-end turn))
       (<= (.ref value 'container-start) (.ref value 'value-start))
       (< (.ref value 'value-start) (.ref value 'value-end) 1048577)
       (eq? (.ref value 'source-authenticated?) #f) (eq? (.ref value 'action-authorized?) #f)))
(define-type (AiAgenticContextOrgAnchorType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-org-anchor-shape?)

;; A property owned by the drawer directly under an OrgFile or OrgSection.
;; Offsets are half-open UTF-8 byte coordinates; an empty value has no span.
(def (agentic-ai-lab-ai-agentic-context-org-property-shape? value)
  (and (object? value)
       (every (lambda (key) (.slot? value key))
          '(kind container-kind container-start container-end drawer-end key key-start key-end value value-start value-end))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.org-property.v1)
       (memq (.ref value 'container-kind) '(OrgFile OrgSection))
       (string? (.ref value 'key))
       (every (lambda (key) (exact-integer? (.ref value key))) '(container-start container-end drawer-end key-start key-end))
       (<= 0 (.ref value 'container-start) (.ref value 'key-start) (.ref value 'key-end)
           (.ref value 'drawer-end) (.ref value 'container-end))
       (let ((text (.ref value 'value)) (start (.ref value 'value-start)) (end (.ref value 'value-end)))
         (or (and (eq? text #f) (eq? start #f) (eq? end #f))
             (and (string? text) (exact-integer? start) (exact-integer? end)
                  (<= (.ref value 'key-end) start) (< start end) (<= end (.ref value 'drawer-end)))))))
(define-type (AiAgenticContextOrgPropertyType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-org-property-shape?)

(def (agentic-ai-lab-ai-agentic-context-temporal-policy-shape? value)
  (and (object? value)
       (every (lambda (key) (.slot? value key)) '(kind identity revision window clock-role purposes semantic-digest))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.temporal-policy.v1)
       (name? (.ref value 'identity)) (name? (.ref value 'semantic-digest))
       (exact-integer? (.ref value 'revision)) (<= 0 (.ref value 'revision) 65535)
       (agentic-ai-lab-temporal-interval? (.ref value 'window))
       (eq? (.ref (.ref value 'window) 'start-closed?) #t)
       (eq? (.ref (.ref value 'window) 'end-closed?) #f)
       (< (.ref (.ref (.ref value 'window) 'start) 'coordinate)
          (.ref (.ref (.ref value 'window) 'end) 'coordinate))
       (symbol? (.ref value 'clock-role)) (list? (.ref value 'purposes))
       (<= 1 (length (.ref value 'purposes)) 5)
       (every (lambda (purpose) (memq purpose '(prepare disclose accept-result publish-memory revisit)))
              (.ref value 'purposes))))
(define-type (AiAgenticContextTemporalPolicyType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-temporal-policy-shape?)

;; Layered GitOps Project topology + inline Org governance relation graph.
(def (agentic-ai-lab-ai-agentic-context-governance-graph-shape? value)
  (and (object? value)
       (every (lambda (key) (.slot? value key))
          '(kind identity semantic-revision element-space graph source-digests
            element-identities complete? source-authenticated? action-authorized?))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.governance-graph.v1)
       (symbol? (.ref value 'identity))
       (name? (.ref value 'semantic-revision))
       (list? (.ref value 'source-digests)) (every name? (.ref value 'source-digests))
       (list? (.ref value 'element-identities)) (every name? (.ref value 'element-identities))
       (boolean? (.ref value 'complete?))
       (eq? (.ref value 'source-authenticated?) #f)
       (eq? (.ref value 'action-authorized?) #f)))
(define-type (AiAgenticContextGovernanceGraphType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-governance-graph-shape?)

;; Rich cross-file native Org Elements graph (`OrgSource`, `OrgHeadline`,
;; `OrgListItem`, `OrgSrcBlock`, `OrgDrawer`, `OrgLink`) over YuanxuGraph.
(def (agentic-ai-lab-ai-agentic-context-org-element-graph-shape? value)
  (and (object? value)
       (every (lambda (key) (.slot? value key))
          '(kind identity semantic-revision element-space graph source-digests
            source-texts element-identities complete? source-authenticated? action-authorized?))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.org-element-graph.v1)
       (symbol? (.ref value 'identity))
       (name? (.ref value 'semantic-revision))
       (list? (.ref value 'source-digests)) (every name? (.ref value 'source-digests))
       (list? (.ref value 'source-texts))
       (list? (.ref value 'element-identities)) (every name? (.ref value 'element-identities))
       (boolean? (.ref value 'complete?))
       (eq? (.ref value 'source-authenticated?) #f)
       (eq? (.ref value 'action-authorized?) #f)))
(define-type (AiAgenticContextOrgElementGraphType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-org-element-graph-shape?)

;; Declarative progressive disclosure & ASCENT facet policy configuration.
(def (agentic-ai-lab-ai-agentic-context-progressive-rule-config-shape? value)
  (and (object? value)
       (every (lambda (key) (.slot? value key))
          '(kind split-line-watermark default-focus-depth require-sod-reviewer?
            fold-thinking-by-default? allow-agent-drill-down?))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.progressive-rule-config.v1)
       (exact-integer? (.ref value 'split-line-watermark))
       (<= 50 (.ref value 'split-line-watermark) 100000)
       (exact-integer? (.ref value 'default-focus-depth))
       (<= 0 (.ref value 'default-focus-depth) 3)
       (boolean? (.ref value 'require-sod-reviewer?))
       (boolean? (.ref value 'fold-thinking-by-default?))
       (boolean? (.ref value 'allow-agent-drill-down?))))
(define-type (AiAgenticContextProgressiveRuleConfigType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-progressive-rule-config-shape?)

;; Bounded typed runtime refinement row scoring an Agent's relation to an Org `:ID:`.
(def (agentic-ai-lab-ai-agentic-context-agent-affinity-shape? value)
  (and (object? value)
       (every (lambda (key) (.slot? value key))
          '(kind agent-id project-id task-id anchor-identity property-id source-id
            container-start container-end score-bps reasons write-eligible? action-authorized?))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.agent-affinity.v1)
       (every (lambda (key) (name? (.ref value key)))
          '(agent-id project-id task-id anchor-identity property-id source-id))
       (exact-integer? (.ref value 'container-start))
       (exact-integer? (.ref value 'container-end))
       (<= 0 (.ref value 'container-start) (.ref value 'container-end))
       (exact-integer? (.ref value 'score-bps))
       (<= 0 (.ref value 'score-bps) 10000)
       (list? (.ref value 'reasons)) (every symbol? (.ref value 'reasons))
       (boolean? (.ref value 'write-eligible?))
       (eq? (.ref value 'action-authorized?) #f)))
(define-type (AiAgenticContextAgentAffinityType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-agent-affinity-shape?)

;; Agent proposal to update the body of one governed Org `:ID:` section.
(def (agentic-ai-lab-ai-agentic-context-subtree-proposal-shape? value)
  (and (object? value)
       (every (lambda (key) (.slot? value key))
          '(kind source-id base-generation target-property-id agent-id task-id session-id
            expected-subtree-digest replacement-body nonce lease-id))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.subtree-proposal.v1)
       (every (lambda (key) (name? (.ref value key)))
          '(source-id target-property-id agent-id task-id session-id
            expected-subtree-digest nonce lease-id))
       (exact-integer? (.ref value 'base-generation))
       (<= 1 (.ref value 'base-generation) 65533)
       (string? (.ref value 'replacement-body))
       (<= (u8vector-length (string->utf8 (.ref value 'replacement-body))) 262144)))
(define-type (AiAgenticContextSubtreeProposalType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-subtree-proposal-shape?)

;; Receipt emitted by governed subtree mediation (rebased or direct).
(def (agentic-ai-lab-ai-agentic-context-subtree-commit-receipt-shape? value)
  (and (object? value)
       (every (lambda (key) (.slot? value key))
          '(kind accepted? reason source-id committed-generation target-property-id
            agent-id before-subtree-digest after-subtree-digest rebased?
            mediation-state mediation-receipt next-source-cut))
       (eq? (.ref value 'kind) 'agentic-ai-lab.ai-agentic-context.subtree-commit-receipt.v1)
       (boolean? (.ref value 'accepted?))
       (symbol? (.ref value 'reason))
       (boolean? (.ref value 'rebased?))))
(define-type (AiAgenticContextSubtreeCommitReceiptType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-subtree-commit-receipt-shape?)

;; Slice 40: Trust-role finite chain `untrusted-data < observed-fact < model-proposal < user-intent < system-policy`.
(def (agentic-ai-lab-ai-agentic-context-trust-role? x)
  (and (memq x '(untrusted-data observed-fact model-proposal user-intent system-policy)) #t))
(define-type (AiAgenticContextTrustRoleType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-trust-role?)

;; Slice 40: EndorsementReceipt binding cut + proposer != endorser for trust promotion.
(def (agentic-ai-lab-ai-agentic-context-endorsement-receipt-shape? v)
  (and (object? v)
       (every (cut .slot? v <>)
              '(kind content-digest bound-cut proposer endorser target-role semantic-digest))
       (eq? (.ref v 'kind) 'agentic-ai-lab.ai-agentic-context.endorsement-receipt.v1)
       (every (lambda (k) (name? (.ref v k)))
              '(content-digest bound-cut proposer endorser semantic-digest))
       (not (equal? (.ref v 'proposer) (.ref v 'endorser)))
       (agentic-ai-lab-ai-agentic-context-trust-role? (.ref v 'target-role))))
(define-type (AiAgenticContextEndorsementReceiptType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-endorsement-receipt-shape?)

;; Slice 40: Six-tuple restriction lower semilattice `(readers, destinations, capabilities, [t0, t1), trust-ceiling, obligations)`.
(def (agentic-ai-lab-ai-agentic-context-restriction-envelope-shape? v)
  (and (object? v)
       (every (cut .slot? v <>)
              '(kind domain readers destinations capabilities lease-start lease-end
                trust-ceiling obligations semantic-digest))
       (eq? (.ref v 'kind) 'agentic-ai-lab.ai-agentic-context.restriction-envelope.v1)
       (name? (.ref v 'domain)) (name? (.ref v 'semantic-digest))
       (every (lambda (k) (and (list? (.ref v k)) (every name? (.ref v k))))
              '(readers destinations capabilities obligations))
       (exact-integer? (.ref v 'lease-start)) (exact-integer? (.ref v 'lease-end))
       (agentic-ai-lab-ai-agentic-context-trust-role? (.ref v 'trust-ceiling))))
(define-type (AiAgenticContextRestrictionEnvelopeType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-restriction-envelope-shape?)

;; Slice 41 & 43: OmittedAlternativesReceipt when budget drops live undefeated hypotheses.
(def (agentic-ai-lab-ai-agentic-context-omitted-alternatives-receipt-shape? v)
  (and (object? v)
       (every (cut .slot? v <>)
              '(kind inquiry-id omitted-hypotheses claims-exhaustive? semantic-digest))
       (eq? (.ref v 'kind) 'agentic-ai-lab.ai-agentic-context.omitted-alternatives-receipt.v1)
       (name? (.ref v 'inquiry-id)) (name? (.ref v 'semantic-digest))
       (pair? (.ref v 'omitted-hypotheses)) (list? (.ref v 'omitted-hypotheses))
       (every name? (.ref v 'omitted-hypotheses))
       (eq? (.ref v 'claims-exhaustive?) #f)))
(define-type (AiAgenticContextOmittedAlternativesReceiptType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-omitted-alternatives-receipt-shape?)

;; Slice 41: Bounded epistemic projection retaining non-droppable defeater + restriction kernel.
(def (agentic-ai-lab-ai-agentic-context-epistemic-projection-shape? v)
  (and (object? v)
       (every (cut .slot? v <>)
              '(kind admitted? status inquiry-id budget total-cost selected-hypotheses
                retained-defeaters restriction-digest omission-receipt claims-exhaustive?
                action-authorized?))
       (eq? (.ref v 'kind) 'agentic-ai-lab.ai-agentic-context.epistemic-projection.v1)
       (boolean? (.ref v 'admitted?)) (symbol? (.ref v 'status))
       (name? (.ref v 'inquiry-id)) (name? (.ref v 'restriction-digest))
       (exact-integer? (.ref v 'budget)) (exact-integer? (.ref v 'total-cost))
       (list? (.ref v 'selected-hypotheses)) (list? (.ref v 'retained-defeaters))
       (boolean? (.ref v 'claims-exhaustive?))
       (eq? (.ref v 'action-authorized?) #f)))
(define-type (AiAgenticContextEpistemicProjectionType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-epistemic-projection-shape?)

;; Slice 42: Cross-repo controlled declassification certificate under 3-party SoD.
(def (agentic-ai-lab-ai-agentic-context-declassification-cert-shape? v)
  (and (object? v)
       (every (cut .slot? v <>)
              '(kind source-repo target-repo bound-source-cut bound-target-cut
                raw-digest redacted-digest preserves-defeaters?
                proposer declassifier recipient origin-role recipient-role semantic-digest))
       (eq? (.ref v 'kind) 'agentic-ai-lab.ai-agentic-context.declassification-cert.v1)
       (every (lambda (k) (name? (.ref v k)))
              '(source-repo target-repo bound-source-cut bound-target-cut
                raw-digest redacted-digest proposer declassifier recipient semantic-digest))
       (not (equal? (.ref v 'raw-digest) (.ref v 'redacted-digest)))
       (eq? (.ref v 'preserves-defeaters?) #t)
       (not (equal? (.ref v 'proposer) (.ref v 'declassifier)))
       (not (equal? (.ref v 'recipient) (.ref v 'declassifier)))
       (not (equal? (.ref v 'proposer) (.ref v 'recipient)))
       (agentic-ai-lab-ai-agentic-context-trust-role? (.ref v 'origin-role))
       (agentic-ai-lab-ai-agentic-context-trust-role? (.ref v 'recipient-role))))
(define-type (AiAgenticContextDeclassificationCertType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-declassification-cert-shape?)

;; Slice 41 & 44: Memory consolidation / causal-survival quotient receipt.
(def (agentic-ai-lab-ai-agentic-context-consolidation-receipt-shape? v)
  (and (object? v)
       (every (cut .slot? v <>)
              '(kind admitted? reason insight-id proposer evidence-owner approver
                outcome-receipt-digest cited-premises defeat-conditions
                raw-cost quotient-cost audit-hook-id watermark-covered?
                org-promoted? semantic-digest action-authorized?))
       (eq? (.ref v 'kind) 'agentic-ai-lab.ai-agentic-context.consolidation-receipt.v1)
       (boolean? (.ref v 'admitted?)) (symbol? (.ref v 'reason))
       (boolean? (.ref v 'org-promoted?))
       (eq? (.ref v 'action-authorized?) #f)))
(define-type (AiAgenticContextConsolidationReceiptType @ Type.)
  .element?: agentic-ai-lab-ai-agentic-context-consolidation-receipt-shape?)
