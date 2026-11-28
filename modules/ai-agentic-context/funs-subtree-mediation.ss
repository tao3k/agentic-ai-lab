;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Governed Org `:ID:` subtree mediation and conflict-free structural rebase.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        (only-in :std/list/list find)
        (only-in :tao3k/agentic-ai-lab/modules/governance/policy/authorized-effect-token
                 agentic-ai-lab-semantic-root
                 agentic-ai-lab-effect-binding
                 agentic-ai-lab-token-validity
                 agentic-ai-lab-authorized-effect-token
                 agentic-ai-lab-token-validation-context)
        (only-in :tao3k/agentic-ai-lab/modules/governance/policy/strict-mediation
                 agentic-ai-lab-strict-mediation-state
                 agentic-ai-lab-strict-mediate
                 agentic-ai-lab-strict-mediation-result-state
                 agentic-ai-lab-strict-mediation-result-receipt)
        "types.ss" "objects.ss" "funs-scope.ss" "funs-org-properties.ss"
        "funs-governance-graph.ss" "org-contract/elements.ss")
(export agentic-ai-lab-ai-agentic-context-org-subtree-digest
        agentic-ai-lab-ai-agentic-context-subtree-mediation-init
        agentic-ai-lab-ai-agentic-context-subtree-issue-token
        agentic-ai-lab-ai-agentic-context-subtree-commit)

(def digest agentic-ai-lab-ai-agentic-context-digest)

(def (org-source-cut? v)
  (and (object? v) (.slot? v 'kind)
       (eq? (.ref v 'kind) 'context.org-source.v1)
       (eq? (.ref v 'active?) #t)))

(def (locate-governed-section source-text target-property-id)
  (let* ((props (agentic-ai-lab-ai-agentic-context-org-properties source-text))
         (bytes (string->utf8 source-text))
         (property (find (lambda (p)
                           (and (eq? (.ref p 'container-kind) 'OrgSection)
                                (agentic-ai-lab-ai-agentic-context-org-property-key? p "ID")
                                (equal? (.ref p 'value) target-property-id)))
                         props)))
    (and property
         (let* ((container-start (.ref property 'container-start))
                (container-end (.ref property 'container-end))
                (drawer-end (.ref property 'drawer-end))
                (child-starts
                 (filter values
                   (map (lambda (p)
                          (and (eq? (.ref p 'container-kind) 'OrgSection)
                               (< container-start (.ref p 'container-start) container-end)
                               (agentic-ai-lab-ai-agentic-context-org-property-key? p "ID")
                               (.ref p 'container-start)))
                        props)))
                (body-end (if (pair? child-starts) (apply min child-starts) container-end))
                (slice (lambda (s e) (utf8->string (subu8vector bytes s e))))
                (header (slice container-start drawer-end))
                (body (slice drawer-end body-end))
                (subtree (slice container-start body-end))
                (subtree-digest (digest (list 'org-governed-subtree.v1
                                              target-property-id header body))))
           (.o property container-start drawer-end body-end container-end
               header body subtree subtree-digest)))))

(def (agentic-ai-lab-ai-agentic-context-org-subtree-digest source-cut target-property-id)
  (unless (and (org-source-cut? source-cut)
               (string? target-property-id) (< 0 (string-length target-property-id) 257))
    (error "Subtree digest requires an active Org source cut and property ID"))
  (let (located (locate-governed-section (.ref source-cut 'source) target-property-id))
    (unless located (error "Unknown governed Org section ID" target-property-id))
    (.ref located 'subtree-digest)))

(def (agentic-ai-lab-ai-agentic-context-subtree-mediation-init seed (revocation-epoch 0))
  (unless (and (string? seed) (< 0 (string-length seed) 257)
               (exact-integer? revocation-epoch) (>= revocation-epoch 0))
    (error "Invalid subtree mediation root seed"))
  (agentic-ai-lab-strict-mediation-state
   (digest (list 'context-subtree-execution-root.v1 seed)) 0 '() revocation-epoch))

(def (replacement-body-safe? header replacement-body target-property-id)
  (let (normalized (if (or (string-empty? replacement-body)
                           (char=? (string-ref replacement-body (- (string-length replacement-body) 1)) #\newline))
                     replacement-body
                     (string-append replacement-body "\n")))
    (with-catch
     (lambda (_) #f)
     (lambda ()
       (let* ((probe (string-append ":PROPERTIES:\n:ID: __probe_root__\n:CONTRACT_ID: probe.v1\n:CONTRACT_REVISION: 1\n:END:\n"
                                    header normalized))
              (sec-ids (filter (lambda (p)
                                 (and (eq? (.ref p 'container-kind) 'OrgSection)
                                      (agentic-ai-lab-ai-agentic-context-org-property-key? p "ID")))
                               (agentic-ai-lab-ai-agentic-context-org-properties probe))))
         (and (= (length sec-ids) 1)
              (equal? (.ref (car sec-ids) 'value) target-property-id)
              normalized))))))

(def (make-proposal-binding source-cut proposal policy-digest)
  (let* ((sid (.ref source-cut 'identity))
         (prop-id (.ref proposal 'target-property-id))
         (body (.ref proposal 'replacement-body))
         (payload-dig (digest (list 'org-subtree-body.v1 body)))
         (intent-dig (digest (list 'org-subtree-write-intent.v1
                                   sid prop-id (.ref proposal 'agent-id) (.ref proposal 'task-id)
                                   (.ref proposal 'expected-subtree-digest) payload-dig))))
    (agentic-ai-lab-effect-binding
     (.ref source-cut 'contract-identity) (.ref proposal 'base-generation)
     policy-digest (digest (list 'org-element.v1 sid prop-id))
     (.ref proposal 'expected-subtree-digest) intent-dig
     (.ref proposal 'task-id) 'org-subtree-body-replace "marlin-deck-vm"
     (.ref proposal 'session-id) 0 1 sid (.ref proposal 'base-generation)
     0 (u8vector-length (string->utf8 body)) payload-dig (.ref proposal 'lease-id))))

(def (matched-affinity gov-graph sid proposal)
  (find (lambda (it)
          (and (equal? (.ref it 'source-id) sid)
               (equal? (.ref it 'property-id) (.ref proposal 'target-property-id))
               (equal? (.ref it 'task-id) (.ref proposal 'task-id))))
        (.ref (agentic-ai-lab-ai-agentic-context-agent-affinities
               gov-graph (.ref proposal 'agent-id) #f #f)
              'affinities)))

(def (reject-token reason)
  (let ((accepted? #f))
    (.o accepted? reason)))

(def (agentic-ai-lab-ai-agentic-context-subtree-issue-token
      gov-graph source-cut proposal policy-digest now-tick expiry-tick revocation-epoch)
  (unless (and (agentic-ai-lab-ai-agentic-context-governance-graph-shape? gov-graph)
               (org-source-cut? source-cut)
               (agentic-ai-lab-ai-agentic-context-subtree-proposal-shape? proposal)
               (string? policy-digest) (< 0 (string-length policy-digest) 257)
               (exact-integer? now-tick) (exact-integer? expiry-tick) (<= now-tick expiry-tick))
    (error "Invalid subtree token issuance inputs"))
  (let* ((conflicts (agentic-ai-lab-ai-agentic-context-governance-conflicts gov-graph))
         (sid (.ref source-cut 'identity))
         (prop-id (.ref proposal 'target-property-id))
         (matched (matched-affinity gov-graph sid proposal))
         (located (locate-governed-section (.ref source-cut 'source) prop-id)))
    (cond
     ((pair? conflicts)
      (let ((accepted? #f) (reason 'governance-conflict-active))
        (.o accepted? reason conflicts)))
     ((not (and (equal? (.ref proposal 'source-id) sid)
                (= (.ref proposal 'base-generation) (.ref source-cut 'generation))))
      (reject-token 'source-cut-mismatch))
     ((not located)
      (reject-token 'unknown-target-anchor))
     ((not (equal? (.ref located 'subtree-digest) (.ref proposal 'expected-subtree-digest)))
      (reject-token 'subtree-digest-mismatch))
     ((not (and matched (.ref matched 'write-eligible?)))
      (reject-token 'gql-write-ineligible))
     ((not (replacement-body-safe? (.ref located 'header) (.ref proposal 'replacement-body) prop-id))
      (reject-token 'header-or-structure-escape))
     (else
      (let* ((binding (make-proposal-binding source-cut proposal policy-digest))
             (semantic-root (agentic-ai-lab-semantic-root
                             (.ref source-cut 'contract-identity) policy-digest
                             (.ref matched 'anchor-identity) (.ref located 'subtree-digest)
                             (.ref binding 'intent-digest)))
             (tok-id (digest (list 'org-subtree-token.v1 (.ref proposal 'nonce) (.ref semantic-root 'digest))))
             (token (agentic-ai-lab-authorized-effect-token
                     tok-id (.ref proposal 'nonce) semantic-root binding
                     (agentic-ai-lab-token-validity now-tick now-tick expiry-tick revocation-epoch)
                     'strict 1 "agentic-ai-lab/governance"
                     (digest (list 'lab-governance-issued tok-id (.ref binding 'intent-digest)))))
             (accepted? #t)
             (reason 'token-issued))
        (.o accepted? reason token semantic-root binding))))))

(def (reject-commit mediation-state proposal reason (mediation-receipt #f))
  (let ((accepted? #f)
        (source-id (.ref proposal 'source-id))
        (target-property-id (.ref proposal 'target-property-id))
        (agent-id (.ref proposal 'agent-id))
        (before-subtree-digest (.ref proposal 'expected-subtree-digest)))
    (.o (:: @ AiAgenticContextSubtreeCommitReceipt.)
        accepted? reason source-id target-property-id agent-id
        before-subtree-digest mediation-state mediation-receipt)))

(def (agentic-ai-lab-ai-agentic-context-subtree-commit
      mediation-state live-gov-graph live-source-cut proposal token policy-digest now-tick)
  (unless (and (agentic-ai-lab-ai-agentic-context-governance-graph-shape? live-gov-graph)
               (org-source-cut? live-source-cut)
               (agentic-ai-lab-ai-agentic-context-subtree-proposal-shape? proposal))
    (error "Invalid subtree commit arguments"))
  (let* ((source-id (.ref live-source-cut 'identity))
         (live-gen (.ref live-source-cut 'generation))
         (target-property-id (.ref proposal 'target-property-id)))
    (cond
     ((not (equal? (.ref proposal 'source-id) source-id))
      (reject-commit mediation-state proposal 'wrong-source))
     ((< live-gen (.ref proposal 'base-generation))
      (reject-commit mediation-state proposal 'generation-rollback))
     ((>= live-gen 65534)
      (reject-commit mediation-state proposal 'generation-exhausted))
     ((pair? (agentic-ai-lab-ai-agentic-context-governance-conflicts live-gov-graph))
      (reject-commit mediation-state proposal 'governance-conflict-active))
     (else
      (let ((located (locate-governed-section (.ref live-source-cut 'source) target-property-id))
            (matched (matched-affinity live-gov-graph source-id proposal)))
        (cond
         ((not located)
          (reject-commit mediation-state proposal 'target-anchor-missing))
         ((not (equal? (.ref located 'subtree-digest) (.ref proposal 'expected-subtree-digest)))
          (reject-commit mediation-state proposal 'concurrent-same-anchor-conflict))
         ((not (and matched (.ref matched 'write-eligible?)))
          (reject-commit mediation-state proposal 'live-gql-write-ineligible))
         (else
          (let (safe-body (replacement-body-safe? (.ref located 'header)
                                                  (.ref proposal 'replacement-body)
                                                  target-property-id))
            (if (not safe-body)
              (reject-commit mediation-state proposal 'header-or-structure-escape)
              (let* ((binding (make-proposal-binding live-source-cut proposal policy-digest))
                     (sem-root (agentic-ai-lab-semantic-root
                                (.ref live-source-cut 'contract-identity) policy-digest
                                (.ref matched 'anchor-identity) (.ref located 'subtree-digest)
                                (.ref binding 'intent-digest)))
                     (val-ctx (agentic-ai-lab-token-validation-context
                               sem-root binding now-tick
                               (.ref mediation-state 'revocation-epoch)
                               (.ref mediation-state 'consumed-nonces)))
                     (raw-bytes (string->utf8 (.ref live-source-cut 'source)))
                     (prefix (utf8->string (subu8vector raw-bytes 0 (.ref located 'drawer-end))))
                     (suffix (utf8->string (subu8vector raw-bytes (.ref located 'body-end)
                                                        (u8vector-length raw-bytes))))
                     (committed-generation (+ live-gen 1))
                     (next-source-cut (context-org-source source-id committed-generation
                                                          (string-append prefix safe-body suffix) #t))
                     (after-subtree-digest
                      (agentic-ai-lab-ai-agentic-context-org-subtree-digest next-source-cut target-property-id))
                     (obs (digest (list 'org-subtree-commit-observation.v1
                                        source-id committed-generation target-property-id
                                        after-subtree-digest (.ref next-source-cut 'semantic-digest))))
                     (med-res (agentic-ai-lab-strict-mediate
                               mediation-state token val-ctx (.ref mediation-state 'execution-root) obs))
                     (next-state (agentic-ai-lab-strict-mediation-result-state med-res))
                     (med-rec (agentic-ai-lab-strict-mediation-result-receipt med-res)))
                (if (not (and (.ref med-rec 'accepted?) (eq? (.ref med-rec 'outcome) 'committed)))
                  (reject-commit next-state proposal (.ref med-rec 'code) med-rec)
                  (let ((accepted? #t)
                        (reason 'committed)
                        (agent-id (.ref proposal 'agent-id))
                        (before-subtree-digest (.ref located 'subtree-digest))
                        (rebased? (> live-gen (.ref proposal 'base-generation)))
                        (mediation-state next-state)
                        (mediation-receipt med-rec))
                    (.o (:: @ AiAgenticContextSubtreeCommitReceipt.)
                        accepted? reason source-id committed-generation target-property-id
                        agent-id before-subtree-digest after-subtree-digest
                        rebased? mediation-state mediation-receipt next-source-cut)))))))))))))
