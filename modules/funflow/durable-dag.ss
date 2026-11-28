;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Tweag-inspired FunFlow CAS DAG engine with C4-derivable OrchestratorStrategy
;;; prototypes, Tarjan SCC cycle validation, transitive CAS node fingerprinting,
;;; crash-resumable skip planning, epoch-bounded dynamic replanning, and
;;; pluggable Governance/lease frontier admission.

(import (only-in :clan/poo/object .def .o .ref .slot? .call object?)
        (only-in :clan/poo/mop .defgeneric .defmethod .defmethod-bundle
                 clos-call clos-compose-method-bundles
                 clos-generic-function clos-generic-protocol)
        (only-in :std/crypto/digest sha256)
        (only-in :std/encoding/hex hex-encode)
        (only-in :std/list/list every filter find delete-duplicates/hash))

(export FunflowNode.
        EffectClass.
        PureCAS.
        VerifiedEpistemic.
        FencedEffect.
        ExternalSandboxProfile.
        funflow-admit-external-task-sandbox
        EffectAdmissionProtocol
        FunflowEffectMethods
        admit-node-effect
        funflow-admit-node-effect
        funflow-envelope-meet
        WorkspaceTopology.
        funflow-workspace-plan
        funflow-invalidate-premises
        OrchestratorStrategy.
        ParallelFrontierStrategy.
        TieredModelStrategy.
        DurableGovernedStrategy.
        strategy-admit-node
        strategy-admit-frontier
        strategy-cas-fingerprint
        strategy-archive-guard
        funflow-dag-node
        funflow-dag-build
        funflow-dag?
        funflow-cas-fingerprint
        funflow-pure-cas-content-key
        funflow-canonical-sha256
        funflow-admit-frontier-with
        funflow-resume-plan
        funflow-replan-epoch
        FunflowDurableDagExports)

(.defgeneric (strategy-admit-node strategy node context)
  slot: .admit-node)

(.defgeneric (strategy-admit-frontier strategy frontier context)
  slot: .admit-frontier)

(.defgeneric (strategy-cas-fingerprint strategy node dep-fingerprints)
  slot: .cas-fingerprint)

(.defgeneric (strategy-archive-guard strategy dag resume-plan journal-state)
  slot: .archive-guard)

(def (canonical-join sep strs)
  (if (null? strs)
    ""
    (let loop ((rest (cdr strs)) (acc (car strs)))
      (if (null? rest)
        acc
        (loop (cdr rest) (string-append acc sep (car rest)))))))

;; Deterministic canonical encoder (Slice 52 / BUG-F3a):
;; Replaces raw `(write payload port)` so hash-tables, pairs, vectors, strings,
;; symbols, numbers, booleans, and nested structures hash identically regardless
;; of insertion or hash-bucket order.
(def (canonical-encode value)
  (cond
   ((null? value) "()")
   ((boolean? value) (if value "#t" "#f"))
   ((number? value) (string-append "num:" (number->string value)))
   ((symbol? value) (string-append "sym:" (symbol->string value)))
   ((string? value)
    (string-append "str:" (number->string (string-length value)) ":" value))
   ((hash-table? value)
    (let* ((pairs (map (lambda (kv)
                         (cons (canonical-encode (car kv))
                               (canonical-encode (cdr kv))))
                       (hash->list value)))
           (sorted (list-sort (lambda (a b) (string<? (car a) (car b))) pairs)))
      (string-append
       "hash{"
       (canonical-join "," (map (lambda (p) (string-append (car p) "=>" (cdr p))) sorted))
       "}")))
   ((vector? value)
    (string-append
     "vec["
     (canonical-join "," (map canonical-encode (vector->list value)))
     "]"))
   ((list? value)
    (string-append
     "list("
     (canonical-join "," (map canonical-encode value))
     ")"))
   ((pair? value)
    (string-append
     "pair("
     (canonical-encode (car value))
     "."
     (canonical-encode (cdr value))
     ")"))
   (else
    (string-append
     "opaque:"
     (call-with-output-string (lambda (port) (write value port)))))))

(def (canonical-sha256 payload)
  (string-append
   "sha256:"
   (hex-encode
    (sha256
     (string->utf8 (canonical-encode payload))))))

(def funflow-canonical-sha256 canonical-sha256)

(def (opt-ref obj key default)
  (if (and (object? obj) (.slot? obj key))
    (.ref obj key)
    default))

(def (node-id-symbol value)
  (cond
   ((symbol? value) value)
   ((string? value) (string->symbol value))
   (else (error "FunFlow DAG node id must be a symbol or string" value))))

;;; Three-State FunFlow Effect Prototypes & Fail-Closed CLOS Multi-Dispatch (Slice 49)

(.def FunflowNode.
  kind: 'agentic-ai-lab.funflow.dag-node.v1)

(.def EffectClass.
  effect-kind: 'abstract-effect)

(.def (PureCAS. @ EffectClass.)
  effect-kind: 'pure-cas
  requires-endorsement?: #f
  requires-exhaustiveness?: #f
  requires-token?: #f)

(.def (VerifiedEpistemic. @ EffectClass.)
  effect-kind: 'verified-epistemic
  requires-endorsement?: #t
  requires-exhaustiveness?: #f
  requires-token?: #f)

(.def (FencedEffect. @ EffectClass.)
  effect-kind: 'fenced-effect
  requires-endorsement?: #t
  requires-exhaustiveness?: #t
  requires-token?: #t)

;;; ExternalTask Sandbox Profile & Lethal-Trifecta / Lease Gate (Slice 46 & Slice 52 / BUG-F4)

(.def ExternalSandboxProfile.
  kind: 'agentic-ai-lab.funflow.external-sandbox-profile.v1
  env-digest: ""
  has-untrusted-input?: #f
  has-private-data?: #f
  egress-enabled?: #f
  egress-endorsed?: #f
  lease-valid?: #t)

(def (funflow-admit-external-task-sandbox profile (now-tick #f))
  (let* ((env-dig (opt-ref profile 'env-digest ""))
         (env-pinned? (and (string? env-dig) (> (string-length env-dig) 0)))
         (lease-flag (opt-ref profile 'lease-valid? #t))
         (l-start (opt-ref profile 'lease-start #f))
         (l-end (opt-ref profile 'lease-end #f))
         (lease-bounds-ok?
          (and lease-flag
               (if (and (exact-integer? l-start) (exact-integer? l-end))
                 (and (<= l-start l-end)
                      (or (not (exact-integer? now-tick))
                          (and (<= l-start now-tick) (<= now-tick l-end))))
                 #t)))
         (untrusted? (and (opt-ref profile 'has-untrusted-input? #f) #t))
         (private? (and (opt-ref profile 'has-private-data? #f) #t))
         (egress? (and (opt-ref profile 'egress-enabled? #f) #t))
         (endorsed? (and (opt-ref profile 'egress-endorsed? #f) #t))
         (trifecta-exposed? (and untrusted? private? egress? (not endorsed?)))
         (reason
          (cond
           ((not env-pinned?) 'unpinned-external-env-digest)
           ((not lease-bounds-ok?) 'restriction-lease-invalid-or-expired)
           (trifecta-exposed? 'lethal-trifecta-sandbox-blocked)
           (else 'external-sandbox-admitted))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.funflow.external-sandbox-admission.v1
        admitted?: (eq? reason 'external-sandbox-admitted)
        reason: reason
        env-pinned?: env-pinned?
        lease-valid?: lease-bounds-ok?
        lethal-trifecta-exposed?: trifecta-exposed?)))

(def (envelope-lease-ok? envelope)
  (let ((flag (opt-ref envelope 'lease-valid? #t))
        (l-start (opt-ref envelope 'lease-start #f))
        (l-end (opt-ref envelope 'lease-end #f))
        (now-tick (opt-ref envelope 'now-tick #f)))
    (and flag
         (if (and (exact-integer? l-start) (exact-integer? l-end))
           (and (<= l-start l-end)
                (or (not (exact-integer? now-tick))
                    (and (<= l-start now-tick) (<= now-tick l-end))))
           #t))))

(def EffectAdmissionProtocol
  (clos-generic-protocol 'funflow/node-effect-admission))

(.defgeneric admit-node-effect (node effect-class envelope)
  (protocol EffectAdmissionProtocol))

(.defmethod-bundle FunflowEffectMethods EffectAdmissionProtocol
  ;; Fail-closed default base method for unsupported crossings.
  (.defmethod (admit-node-effect node effect-class envelope)
    (.o bind-these: #f
        kind: 'agentic-ai-lab.funflow.effect-admission.v1
        admitted?: #f
        effect-kind: (opt-ref effect-class 'effect-kind 'unknown)
        reason: 'unsupported-effect-crossing))
  ;; PureCAS: deterministic computation admitted unconditionally.
  (.defmethod (admit-node-effect (node (prototype FunflowNode.))
                                 (effect-class (prototype PureCAS.))
                                 envelope)
    (.o bind-these: #f
        kind: 'agentic-ai-lab.funflow.effect-admission.v1
        admitted?: #t
        effect-kind: 'pure-cas
        reason: 'pure-cas-deterministic))
  ;; VerifiedEpistemic: Semantic CAS requires Verifier/Endorsement on live cut + valid lease.
  (.defmethod (admit-node-effect (node (prototype FunflowNode.))
                                 (effect-class (prototype VerifiedEpistemic.))
                                 envelope)
    (let* ((endorsed? (opt-ref envelope 'has-endorsement? #f))
           (live-cut (opt-ref envelope 'live-cut #f))
           (node-cut (opt-ref node 'source-cut ""))
           (cut-ok? (or (not live-cut) (equal? live-cut node-cut)))
           (lease-ok? (envelope-lease-ok? envelope))
           (sandbox (opt-ref node 'sandbox-profile #f))
           (sandbox-res (and sandbox (funflow-admit-external-task-sandbox sandbox (opt-ref envelope 'now-tick #f))))
           (sandbox-ok? (or (not sandbox-res) (.ref sandbox-res 'admitted?)))
           (reason (cond
                    ((not cut-ok?) 'stale-source-cut)
                    ((not lease-ok?) 'restriction-lease-invalid-or-expired)
                    ((not sandbox-ok?) (.ref sandbox-res 'reason))
                    ((not endorsed?) 'missing-endorsement-or-verifier-receipt)
                    (else 'verified-epistemic-admitted))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.funflow.effect-admission.v1
          admitted?: (eq? reason 'verified-epistemic-admitted)
          effect-kind: 'verified-epistemic
          reason: reason)))
  ;; FencedEffect: Asymmetric safety gate (Slice 43, Slice 49 & Slice 52).
  (.defmethod (admit-node-effect (node (prototype FunflowNode.))
                                 (effect-class (prototype FencedEffect.))
                                 envelope)
    (let* ((exhaustive? (opt-ref envelope 'claims-exhaustive? #f))
           (has-token? (opt-ref envelope 'has-authorized-token? #f))
           (endorsed? (opt-ref envelope 'has-endorsement? #f))
           (live-cut (opt-ref envelope 'live-cut #f))
           (node-cut (opt-ref node 'source-cut ""))
           (cut-ok? (or (not live-cut) (equal? live-cut node-cut)))
           (lease-ok? (envelope-lease-ok? envelope))
           (sandbox (opt-ref node 'sandbox-profile #f))
           (sandbox-res (and sandbox (funflow-admit-external-task-sandbox sandbox (opt-ref envelope 'now-tick #f))))
           (sandbox-ok? (or (not sandbox-res) (.ref sandbox-res 'admitted?)))
           (idem (opt-ref node 'idempotency-key #f))
           (idem-ok? (and (string? idem) (> (string-length idem) 0)))
           (reason (cond
                    ((not cut-ok?) 'stale-source-cut)
                    ((not lease-ok?) 'restriction-lease-invalid-or-expired)
                    ((not sandbox-ok?) (.ref sandbox-res 'reason))
                    ((not exhaustive?) 'fenced-effect-blocked-by-omitted-alternatives)
                    ((not has-token?) 'missing-authorized-effect-token)
                    ((not endorsed?) 'missing-endorsement-receipt)
                    ((not idem-ok?) 'missing-idempotency-key)
                    (else 'fenced-effect-admitted))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.funflow.effect-admission.v1
          admitted?: (eq? reason 'fenced-effect-admitted)
          effect-kind: 'fenced-effect
          reason: reason))))

(def funflow-effect-dispatcher
  (clos-compose-method-bundles
   (clos-generic-function 'admit-node-effect 3 protocol: EffectAdmissionProtocol)
   (list FunflowEffectMethods)))

(def (funflow-admit-node-effect node
                                effect-class: (effect-class #f)
                                envelope: (envelope (.o)))
  (let ((eff (or effect-class (opt-ref node 'effect-class PureCAS.))))
    (clos-call funflow-effect-dispatcher node eff envelope)))

;;; Monotonic RestrictionEnvelope Lower-Semilattice Meet (Slice 40 & Slice 49)

(def (list-intersect a b)
  (filter (lambda (x) (member x b)) a))

(def (funflow-envelope-meet parent overlay)
  (cond
   ((not overlay) parent)
   ((not parent) overlay)
   (else
    (let* ((p-trust (opt-ref parent 'trust-ceiling 4))
           (o-trust (opt-ref overlay 'trust-ceiling p-trust))
           (p-start (opt-ref parent 'lease-start 0))
           (o-start (opt-ref overlay 'lease-start p-start))
           (p-end (opt-ref parent 'lease-end 1000000000))
           (o-end (opt-ref overlay 'lease-end p-end))
           (p-write (opt-ref parent 'can-write? #t))
           (o-write (opt-ref overlay 'can-write? p-write))
           (p-push (opt-ref parent 'can-push? #f))
           (o-push (opt-ref overlay 'can-push? p-push))
           (p-scopes (opt-ref parent 'allowed-scopes #f))
           (o-scopes (opt-ref overlay 'allowed-scopes #f))
           (next-scopes
            (cond
             ((and (list? p-scopes) (list? o-scopes)) (list-intersect p-scopes o-scopes))
             ((list? p-scopes) p-scopes)
             ((list? o-scopes) o-scopes)
             (else #f)))
           (p-readers (opt-ref parent 'readers #f))
           (o-readers (opt-ref overlay 'readers #f))
           (next-readers
            (cond
             ((and (list? p-readers) (list? o-readers)) (list-intersect p-readers o-readers))
             ((list? p-readers) p-readers)
             ((list? o-readers) o-readers)
             (else #f)))
           (next-trust (min p-trust o-trust))
           (next-start (max p-start o-start))
           (next-end (min p-end o-end))
           (p-valid (opt-ref parent 'lease-valid? (<= p-start p-end)))
           (o-valid (opt-ref overlay 'lease-valid? (<= o-start o-end)))
           (next-lease-valid (and p-valid o-valid (<= next-start next-end) #t))
           (next-write (and p-write o-write next-lease-valid #t))
           (next-push (and p-push o-push next-lease-valid #t)))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.funflow.restriction-envelope.v1
          domain: (opt-ref parent 'domain (opt-ref overlay 'domain "default"))
          trust-ceiling: next-trust
          lease-start: next-start
          lease-end: next-end
          lease-valid?: next-lease-valid
          can-write?: next-write
          can-push?: next-push
          allowed-scopes: next-scopes
          readers: next-readers
          digest: (canonical-sha256
                   (list 'restriction-envelope-meet.v2
                         next-trust next-start next-end next-lease-valid
                         next-write next-push next-scopes next-readers)))))))

(def (funflow-dag-node id
                       needs: (needs '())
                       after-start: (after-start #f)
                       source-cut: (source-cut "cut-0")
                       schema-version: (schema-version "agentic-ai-lab.funflow.cas-node.v2")
                       step-code-digest: (step-code-digest "")
                       env-digest: (env-digest "")
                       input-digest: (input-digest "")
                       input-hashes: (input-hashes '())
                       contract-digest: (contract-digest "")
                       policy-digest: (policy-digest "")
                       effect-class: (effect-class PureCAS.)
                       premise-digests: (premise-digests '())
                       idempotency-key: (idempotency-key #f)
                       sandbox-profile: (sandbox-profile #f)
                       status: (status 'todo)
                       checklists-done?: (checklists-done? #t)
                       span: (span #f)
                       scope: (scope #f)
                       model-tier: (model-tier 'builder)
                       disclosure-depth: (disclosure-depth 2)
                       facets: (facets '())
                       metadata: (metadata '()))
  (let ((id-sym (node-id-symbol id))
        (needs-syms (map node-id-symbol needs))
        (after-sym (and after-start (node-id-symbol after-start)))
        (cut-val (if (string? source-cut) (string-copy source-cut) (object->string source-cut)))
        (ver-val (if (string? schema-version) (string-copy schema-version) "agentic-ai-lab.funflow.cas-node.v2"))
        (code-dig (if (string? step-code-digest) (string-copy step-code-digest) ""))
        (env-dig (if (string? env-digest) (string-copy env-digest) ""))
        (in-dig (if (string? input-digest) (string-copy input-digest) ""))
        (in-hashes (if (list? input-hashes) input-hashes '()))
        (con-dig (if (string? contract-digest) (string-copy contract-digest) ""))
        (pol-dig (if (string? policy-digest) (string-copy policy-digest) ""))
        (eff-val effect-class)
        (prem-val premise-digests)
        (idem-val idempotency-key)
        (sbx-val sandbox-profile)
        (st-val status)
        (chk-val (and checklists-done? #t))
        (span-val span)
        (scope-val scope)
        (tier-val model-tier)
        (depth-val disclosure-depth)
        (facets-val facets)
        (meta-val metadata))
    (.o (:: @ FunflowNode.)
        bind-these: #f
        kind: 'agentic-ai-lab.funflow.dag-node.v1
        id: id-sym
        needs: needs-syms
        after-start: after-sym
        source-cut: cut-val
        schema-version: ver-val
        step-code-digest: code-dig
        env-digest: env-dig
        input-digest: in-dig
        input-hashes: in-hashes
        contract-digest: con-dig
        policy-digest: pol-dig
        effect-class: eff-val
        premise-digests: prem-val
        idempotency-key: idem-val
        sandbox-profile: sbx-val
        status: st-val
        checklists-done?: chk-val
        span: span-val
        scope: scope-val
        model-tier: tier-val
        disclosure-depth: depth-val
        facets: facets-val
        metadata: meta-val)))

(def (canonical-sort-strings xs)
  (list-sort string<?
             (map (lambda (x)
                    (cond ((string? x) x)
                          ((symbol? x) (symbol->string x))
                          (else (canonical-encode x))))
                  xs)))

(def (canonical-sort-kv-pairs pairs)
  (list-sort (lambda (a b)
               (or (string<? (car a) (car b))
                   (and (equal? (car a) (car b))
                        (string<? (canonical-encode (cdr a))
                                  (canonical-encode (cdr b))))))
             (map (lambda (pair)
                    (cons (if (symbol? (car pair)) (symbol->string (car pair)) (car pair))
                          (cdr pair)))
                  pairs)))

;; Label-free canonical 5-tuple PureCAS content key (Slice 52 / BUG-F3a):
;; `(schemaVersion, stepCodeDigest, envDigest, sortedInputHashes, sortedPremiseDigests)`
;; Enables cross-DAG pure deduplication independent of node label `id`.
(def (funflow-pure-cas-content-key node dep-fingerprints)
  (let ((sorted-inputs (canonical-sort-strings
                        (append (if (> (string-length (opt-ref node 'input-digest "")) 0)
                                  (list (opt-ref node 'input-digest ""))
                                  '())
                                (opt-ref node 'input-hashes '())
                                (map cdr dep-fingerprints))))
        (sorted-premises (canonical-sort-kv-pairs (opt-ref node 'premise-digests '()))))
    (canonical-sha256
     (list (opt-ref node 'schema-version "agentic-ai-lab.funflow.cas-node.v2")
           (opt-ref node 'step-code-digest "")
           (opt-ref node 'env-digest "")
           sorted-inputs
           sorted-premises))))

(def (funflow-cas-fingerprint node dep-fingerprints)
  (let ((sorted-deps (canonical-sort-kv-pairs dep-fingerprints))
        (sorted-inputs (canonical-sort-strings (opt-ref node 'input-hashes '())))
        (sorted-premises (canonical-sort-kv-pairs (opt-ref node 'premise-digests '()))))
    (canonical-sha256
     (list (opt-ref node 'schema-version "agentic-ai-lab.funflow.cas-node.v2")
           (symbol->string (.ref node 'id))
           (opt-ref node 'step-code-digest "")
           (opt-ref node 'env-digest "")
           (.ref node 'source-cut)
           (.ref node 'input-digest)
           sorted-inputs
           (.ref node 'contract-digest)
           (.ref node 'policy-digest)
           (opt-ref (opt-ref node 'effect-class PureCAS.) 'effect-kind 'pure-cas)
           sorted-premises
           (if (.ref node 'after-start)
             (symbol->string (.ref node 'after-start))
             #f)
           sorted-deps))))

(def (spans-disjoint? a b)
  (let ((sa (opt-ref a 'span #f))
        (sb (opt-ref b 'span #f)))
    (cond
     ((or (not sa) (not sb)) #t)
     ((and (pair? sa) (pair? sb)
           (exact-integer? (car sa)) (exact-integer? (cdr sa))
           (exact-integer? (car sb)) (exact-integer? (cdr sb)))
      (or (<= (cdr sa) (car sb)) (<= (cdr sb) (car sa))))
     (else #t))))

(def (funflow-admit-frontier-with frontier node-admit? pair-compatible? max-concurrency)
  (let ((admitted-candidates
         (filter (lambda (node) (and (node-admit? node) #t)) frontier)))
    (let loop ((rest admitted-candidates) (selected '()) (deferred '()))
      (cond
       ((null? rest)
        (let ((sel (reverse selected))
              (def-list (reverse deferred)))
          (.o kind: 'agentic-ai-lab.funflow.frontier-admission.v1
              selected: sel
              deferred: def-list)))
       ((and max-concurrency (>= (length selected) max-concurrency))
        (loop (cdr rest) selected (cons (car rest) deferred)))
       (else
        (let ((candidate (car rest)))
          (if (every (lambda (chosen) (pair-compatible? chosen candidate)) selected)
            (loop (cdr rest) (cons candidate selected) deferred)
            (loop (cdr rest) selected (cons candidate deferred)))))))))

;;; C4-derivable POO OrchestratorStrategy hierarchy.
(def OrchestratorStrategy.
  (.o (:: self)
      kind: 'agentic-ai-lab.funflow.orchestrator-strategy.v1
      name: 'base-orchestrator
      max-concurrency: 1
      cache-policy: 'cas-journal
      failure-policy: 'fail-closed
      focused-tab-archive: 'on-blur
      scratch-promotion: 'on-plan
      reopen-mode: 'peek-until-edit
      require-sod-reviewer: #f
      .cas-fingerprint: (lambda (node dep-fingerprints)
                          (funflow-cas-fingerprint node dep-fingerprints))
      .admit-node: (lambda (node context)
                     (let ((pred (opt-ref context 'node-admit? #f)))
                       (if (procedure? pred)
                         (and (pred node) #t)
                         #t)))
      .admit-frontier: (lambda (frontier context)
                         (let ((max-c (.ref self 'max-concurrency))
                               (pair-ok? (or (opt-ref context 'pair-compatible? #f)
                                             spans-disjoint?)))
                           (funflow-admit-frontier-with
                            frontier
                            (lambda (node) (strategy-admit-node self node context))
                            pair-ok?
                            max-c)))
      .archive-guard: (lambda (dag resume-plan journal-state)
                        (let ((in-flight (opt-ref journal-state 'in-flight-ids '()))
                              (pending-effects (opt-ref journal-state 'pending-effects '())))
                          (and (.ref dag 'valid?)
                               (.ref resume-plan 'complete?)
                               (null? (.ref resume-plan 'pending-finalizers))
                               (null? in-flight)
                               (null? pending-effects))))))

(def ParallelFrontierStrategy.
  (.o (:: @ OrchestratorStrategy.)
      name: 'parallel-frontier
      max-concurrency: 4))

(def TieredModelStrategy.
  (.o (:: self ParallelFrontierStrategy.)
      name: 'tiered-model
      model-tiers: (.o architect: 'frontier builder: 'mid flash: 'fast)
      .route-node: (lambda (node)
                     (let ((facets (opt-ref node 'facets '()))
                           (explicit (opt-ref node 'model-tier #f)))
                       (cond
                        ((or (memq 'invariant-section facets)
                             (memq 'competing-hypotheses facets))
                         'architect)
                        ((and (null? facets) (eq? explicit 'flash))
                         'flash)
                        (explicit explicit)
                        (else 'builder))))))

(def DurableGovernedStrategy.
  (.o (:: self TieredModelStrategy.)
      name: 'durable-governed
      (.admit-node =>
        (lambda (base-admit)
          (lambda (node context)
            (let ((base-ok? (base-admit node context))
                  (gov-ok? (opt-ref context 'governance-admit? #f))
                  (need-sod? (.ref self 'require-sod-reviewer)))
              (and base-ok?
                   (if (procedure? gov-ok?) (and (gov-ok? node) #t) #t)
                   (if need-sod?
                     (let ((scope (opt-ref node 'scope #f)))
                       (and (object? scope)
                            (opt-ref scope 'reviewer-id #f)
                            (not (equal? (opt-ref scope 'actor #f)
                                         (opt-ref scope 'reviewer-id #f)))))
                     #t))))))
      (.archive-guard =>
        (lambda (base-guard)
          (lambda (dag resume-plan journal-state)
            (and (base-guard dag resume-plan journal-state)
                 (not (opt-ref journal-state 'recovery-required? #f))))))))

(def (find-cycle-nodes unique-ids node-map dep-map)
  ;; Pure Tarjan SCC (O(V+E)): returns nodes in any SCC of size > 1 or self-loop.
  (let ((index-counter 0)
        (indices (make-hash-table-eq))
        (lowlinks (make-hash-table-eq))
        (on-stack (make-hash-table-eq))
        (stack '())
        (cycle-set (make-hash-table-eq)))
    (def (strongconnect v)
      (hash-put! indices v index-counter)
      (hash-put! lowlinks v index-counter)
      (set! index-counter (+ index-counter 1))
      (set! stack (cons v stack))
      (hash-put! on-stack v #t)
      (for-each
       (lambda (w)
         (when (hash-key? node-map w)
           (cond
            ((eq? w v)
             (hash-put! cycle-set v #t))
            ((not (hash-key? indices w))
             (strongconnect w)
             (hash-put! lowlinks v (min (hash-ref lowlinks v) (hash-ref lowlinks w))))
            ((hash-get on-stack w)
             (hash-put! lowlinks v (min (hash-ref lowlinks v) (hash-ref indices w)))))))
       (hash-ref dep-map v '()))
      (when (= (hash-ref lowlinks v) (hash-ref indices v))
        (let pop-loop ((comp '()))
          (let ((w (car stack)))
            (set! stack (cdr stack))
            (hash-put! on-stack w #f)
            (let ((next-comp (cons w comp)))
              (if (eq? w v)
                (when (> (length next-comp) 1)
                  (for-each (lambda (m) (hash-put! cycle-set m #t)) next-comp))
                (pop-loop next-comp)))))))
    (for-each
     (lambda (v)
       (unless (hash-key? indices v)
         (strongconnect v)))
     unique-ids)
    (filter (lambda (v) (hash-get cycle-set v)) unique-ids)))

(def (funflow-dag? value)
  (and (object? value)
       (.slot? value 'kind)
       (eq? (.ref value 'kind) 'agentic-ai-lab.funflow.dag.v1)))

(def (topological-order names dep-map)
  (let ((indeg (make-hash-table-eq))
        (dependents (make-hash-table-eq)))
    (for-each (lambda (n) (hash-put! indeg n 0)) names)
    (for-each
     (lambda (n)
       (for-each
        (lambda (dep)
          (when (hash-key? indeg dep)
            (hash-put! indeg n (+ 1 (hash-ref indeg n 0)))
            (hash-put! dependents dep (cons n (hash-ref dependents dep '())))))
        (hash-ref dep-map n '())))
     names)
    (let loop ((ready (filter (lambda (n) (= (hash-ref indeg n 0) 0)) names))
               (acc '()))
      (if (null? ready)
        (reverse acc)
        (let* ((curr (car ready))
               (rest (cdr ready))
               (unlocked
                (filter
                 (lambda (child)
                   (let ((next (- (hash-ref indeg child 0) 1)))
                     (hash-put! indeg child next)
                     (= next 0)))
                 (reverse (hash-ref dependents curr '())))))
          (loop (append rest unlocked) (cons curr acc)))))))

(def (funflow-dag-build nodes strategy: (strategy DurableGovernedStrategy.))
  (let* ((node-list (if (list? nodes) nodes (error "funflow-dag-build expects node list" nodes)))
         (id-list (map (lambda (n) (.ref n 'id)) node-list))
         (unique-ids (delete-duplicates/hash id-list))
         (duplicate-ids
          (if (= (length id-list) (length unique-ids))
            '()
            (let ((seen (make-hash-table-eq)) (dups '()))
              (for-each (lambda (id)
                          (if (hash-key? seen id)
                            (set! dups (cons id dups))
                            (hash-put! seen id #t)))
                        id-list)
              (delete-duplicates/hash (reverse dups)))))
         (node-map (make-hash-table-eq))
         (dep-map (make-hash-table-eq))
         (order-edge-map (make-hash-table-eq)))
    (for-each (lambda (n)
                (let ((id (.ref n 'id))
                      (needs (.ref n 'needs))
                      (after (.ref n 'after-start)))
                  (unless (hash-key? node-map id)
                    (hash-put! node-map id n)
                    (hash-put! dep-map id needs)
                    ;; BUG-F1 fix: include `after-start` edges in cycle detection and
                    ;; topological order so triggers always precede finalizers and
                    ;; `after-start` cycles cannot bypass Tarjan SCC!
                    (hash-put! order-edge-map id
                               (if after (cons after needs) needs)))))
              node-list)
    (let* ((unresolved-edges
            (let ((missing '()))
              (for-each
               (lambda (n)
                 (let ((id (.ref n 'id)))
                   (for-each
                    (lambda (dep)
                      (unless (hash-key? node-map dep)
                        (set! missing (cons (cons id dep) missing))))
                    (.ref n 'needs))
                   (let ((trig (.ref n 'after-start)))
                     (when (and trig (not (hash-key? node-map trig)))
                       (set! missing (cons (cons id trig) missing))))))
               node-list)
              (reverse missing)))
           (invalid-finalizers
            (filter
             (lambda (n)
               (and (.ref n 'after-start) (pair? (.ref n 'needs))))
             node-list))
           (cycle-nodes (find-cycle-nodes unique-ids node-map order-edge-map))
           (valid? (and (null? duplicate-ids)
                        (null? unresolved-edges)
                        (null? invalid-finalizers)
                        (null? cycle-nodes)))
           (topo (if valid? (topological-order unique-ids order-edge-map) '()))
           (fingerprints (make-hash-table-eq)))
      (when valid?
        (for-each
         (lambda (id)
           (let* ((node (hash-ref node-map id))
                  (dep-fps
                   (map (lambda (dep) (cons dep (hash-ref fingerprints dep "")))
                        (.ref node 'needs)))
                  (fp (strategy-cas-fingerprint strategy node dep-fps)))
             (hash-put! fingerprints id fp)))
         topo))
      (let* ((fp-alist
              (map (lambda (id) (cons id (hash-ref fingerprints id ""))) topo))
             (dag-digest (canonical-sha256 (list 'agentic-ai-lab.funflow.dag.v1 fp-alist)))
             (nodes-val node-list)
             (ids-val unique-ids)
             (topo-val topo)
             (valid-val valid?)
             (dups-val duplicate-ids)
             (unres-val unresolved-edges)
             (inv-fin-val (map (lambda (n) (.ref n 'id)) invalid-finalizers))
             (cyc-val cycle-nodes))
        (.o bind-these: #f
            kind: 'agentic-ai-lab.funflow.dag.v1
            valid?: valid-val
            nodes: nodes-val
            node-ids: ids-val
            node-map: node-map
            topological-order: topo-val
            fingerprints: fp-alist
            fingerprint-table: fingerprints
            dag-digest: dag-digest
            duplicate-nodes: dups-val
            unresolved-edges: unres-val
            invalid-finalizers: inv-fin-val
            cycle-nodes: cyc-val)))))

(def (raw-cas-hit? node fp completed-cas-table)
  (and completed-cas-table
       (let ((id (.ref node 'id)))
         (cond
          ((hash-table? completed-cas-table)
           (or (equal? (hash-get completed-cas-table id) fp)
               (and (hash-get completed-cas-table fp) #t)))
          ((list? completed-cas-table)
           (let ((entry (assq id completed-cas-table)))
             (and entry (equal? (cdr entry) fp))))
          (else #f)))))

(def (idempotency-committed? idem-key idempotency-commits)
  (and (string? idem-key)
       (> (string-length idem-key) 0)
       idempotency-commits
       (cond
        ((hash-table? idempotency-commits) (and (hash-get idempotency-commits idem-key) #t))
        ((list? idempotency-commits) (and (member idem-key idempotency-commits) #t))
        (else #f))))

;; BUG-F3b fix (Slice 52): EffectClass-gated CAS skip admission.
;; - PureCAS.: settled by plain CAS fingerprint hit.
;; - VerifiedEpistemic.: requires plain CAS hit + endorsement on live cut + zero premise drift.
;; - FencedEffect.: NEVER bypassed by plain CAS hit; requires authoritative idempotency commit receipt.
(def (cas-hit? node fp completed-cas-table (idempotency-commits #f) (context (.o)))
  (let ((eff-kind (opt-ref (opt-ref node 'effect-class PureCAS.) 'effect-kind 'pure-cas)))
    (case eff-kind
      ((pure-cas)
       (raw-cas-hit? node fp completed-cas-table))
      ((verified-epistemic)
       (and (raw-cas-hit? node fp completed-cas-table)
            (and (opt-ref context 'has-endorsement? #f) #t)
            (not (opt-ref context 'premise-drifted? #f))
            (let ((live-cut (opt-ref context 'live-cut #f)))
              (or (not live-cut) (equal? live-cut (.ref node 'source-cut))))))
      ((fenced-effect)
       (idempotency-committed? (opt-ref node 'idempotency-key #f) idempotency-commits))
      (else #f))))

(def (node-settled? node fp completed-cas-table (idempotency-commits #f) (context (.o)))
  (or (and (eq? (.ref node 'status) 'done)
           (.ref node 'checklists-done?))
      (cas-hit? node fp completed-cas-table idempotency-commits context)))

(def (funflow-resume-plan dag
                          completed-cas-table: (completed-cas-table #f)
                          idempotency-commits: (idempotency-commits #f)
                          in-flight-ids: (in-flight-ids '())
                          strategy: (strategy DurableGovernedStrategy.)
                          context: (context (.o)))
  (unless (funflow-dag? dag)
    (error "Expected FunFlow DAG" dag))
  (let* ((node-map (.ref dag 'node-map))
         (fp-table (.ref dag 'fingerprint-table))
         (valid? (.ref dag 'valid?))
         (in-flight-syms (map node-id-symbol in-flight-ids))
         (settled-set (make-hash-table-eq))
         (failed-set (make-hash-table-eq))
         (skipped-rev '())
         (done-rev '())
         (failed-rev '())
         (in-flight-rev '())
         (raw-ready-rev '())
         (blocked-rev '())
         (pending-fin-rev '()))
    (when valid?
      ;; Pass 1 (BUG-F1 defense-in-depth): collect all failed/cancelled triggers first
      ;; so finalizer scheduling is order-independent even on hand-constructed DAGs.
      (for-each
       (lambda (id)
         (let ((st (.ref (hash-ref node-map id) 'status)))
           (when (memq st '(failed cancelled))
             (hash-put! failed-set id #t))))
       (.ref dag 'topological-order))
      (for-each
       (lambda (id)
         (let* ((node (hash-ref node-map id))
                (fp (hash-ref fp-table id ""))
                (st (.ref node 'status))
                (fin-trigger (.ref node 'after-start)))
           (cond
            (fin-trigger
             (when (and (hash-key? failed-set fin-trigger)
                        (not (node-settled? node fp completed-cas-table idempotency-commits context)))
               (set! pending-fin-rev (cons id pending-fin-rev))))
            ((memq id in-flight-syms)
             (set! in-flight-rev (cons id in-flight-rev)))
            ((memq st '(failed cancelled))
             (set! failed-rev (cons id failed-rev)))
            ((cas-hit? node fp completed-cas-table idempotency-commits context)
             (hash-put! settled-set id #t)
             (set! skipped-rev (cons id skipped-rev)))
            ((and (eq? st 'done) (.ref node 'checklists-done?))
             (hash-put! settled-set id #t)
             (set! done-rev (cons id done-rev)))
            (else
             (if (every (lambda (dep) (hash-key? settled-set dep)) (.ref node 'needs))
               (set! raw-ready-rev (cons node raw-ready-rev))
               (set! blocked-rev (cons id blocked-rev)))))))
       (.ref dag 'topological-order)))
    (let* ((raw-ready (reverse raw-ready-rev))
           (admission (strategy-admit-frontier strategy raw-ready context))
           (selected-nodes (.ref admission 'selected))
           (deferred-nodes (.ref admission 'deferred))
           (selected-ids (map (lambda (n) (.ref n 'id)) selected-nodes))
           (deferred-ids (map (lambda (n) (.ref n 'id)) deferred-nodes))
           (skipped (reverse skipped-rev))
           (done-ids (reverse done-rev))
           (failed (reverse failed-rev))
           (in-flight (reverse in-flight-rev))
           (blocked (reverse blocked-rev))
           (pending-fin (reverse pending-fin-rev))
           (complete? (and valid?
                           (null? selected-ids)
                           (null? deferred-ids)
                           (null? blocked)
                           (null? failed)
                           (null? in-flight)
                           (null? pending-fin))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.funflow.resume-plan.v1
          valid?: valid?
          dag-digest: (.ref dag 'dag-digest)
          skipped-nodes: skipped
          done-nodes: done-ids
          ready-frontier: selected-ids
          ready-frontier-nodes: selected-nodes
          deferred-frontier: deferred-ids
          in-flight-nodes: in-flight
          blocked-nodes: blocked
          failed-nodes: failed
          pending-finalizers: pending-fin
          complete?: complete?))))

(def (funflow-replan-epoch prior-dag
                           next-dag
                           completed-cas-table: (completed-cas-table #f)
                           idempotency-commits: (idempotency-commits #f)
                           in-flight-ids: (in-flight-ids '())
                           strategy: (strategy DurableGovernedStrategy.)
                           context: (context (.o)))
  (let* ((prior-fps (if (funflow-dag? prior-dag) (.ref prior-dag 'fingerprint-table) (make-hash-table-eq)))
         (next-fps (.ref next-dag 'fingerprint-table))
         (preserved-rev '())
         (invalidated-rev '())
         (added-rev '()))
    (when (.ref next-dag 'valid?)
      (for-each
       (lambda (id)
         (let ((new-fp (hash-ref next-fps id ""))
               (old-fp (hash-get prior-fps id))
               (node (hash-ref (.ref next-dag 'node-map) id)))
           (cond
            ((not old-fp)
             (set! added-rev (cons id added-rev)))
            ((and (equal? old-fp new-fp)
                  (cas-hit? node new-fp completed-cas-table idempotency-commits context))
             (set! preserved-rev (cons id preserved-rev)))
            ((not (equal? old-fp new-fp))
             (set! invalidated-rev (cons id invalidated-rev)))
            (else (void)))))
       (.ref next-dag 'topological-order)))
    (let ((plan (funflow-resume-plan next-dag
                                     completed-cas-table: completed-cas-table
                                     idempotency-commits: idempotency-commits
                                     in-flight-ids: in-flight-ids
                                     strategy: strategy
                                     context: context))
          (preserved (reverse preserved-rev))
          (invalidated (reverse invalidated-rev))
          (added (reverse added-rev)))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.funflow.epoch-replan.v1
          valid?: (.ref next-dag 'valid?)
          prior-dag-digest: (if (funflow-dag? prior-dag) (.ref prior-dag 'dag-digest) #f)
          next-dag-digest: (.ref next-dag 'dag-digest)
          preserved-cas-nodes: preserved
          invalidated-nodes: invalidated
          added-nodes: added
          resume-plan: plan))))

;;; Zero-Token Premise Invalidation (Slice 49)
(def (funflow-invalidate-premises dag live-premise-alist)
  (let ((stale-set (make-hash-table-eq))
        (reasons-rev '())
        (node-map (.ref dag 'node-map)))
    (for-each
     (lambda (id)
       (let* ((node (hash-ref node-map id))
              (premises (opt-ref node 'premise-digests '()))
              (direct-drift
               (filter
                (lambda (pair)
                  (let* ((k (car pair))
                         (expected (cdr pair))
                         (live (or (assoc k live-premise-alist)
                                   (and (symbol? k) (assoc (symbol->string k) live-premise-alist))
                                   (and (string? k) (assoc (string->symbol k) live-premise-alist)))))
                    ;; BUG-F2 fix (Slice 52): Fail-closed on retracted/missing premise!
                    ;; When `live` is `#f`, the premise was deleted/retracted and MUST invalidate.
                    (or (not live) (not (equal? (cdr live) expected)))))
                premises))
              (dep-stale?
               (let loop ((ds (.ref node 'needs)))
                 (cond
                  ((null? ds) #f)
                  ((hash-get stale-set (car ds)) #t)
                  (else (loop (cdr ds)))))))
         (when (or (pair? direct-drift) dep-stale?)
           (hash-put! stale-set id #t)
           (set! reasons-rev
                 (cons (cons id (if (pair? direct-drift)
                                  (map car direct-drift)
                                  '(transitive-premise-drift)))
                       reasons-rev)))))
     (.ref dag 'topological-order))
    (let* ((stale-nodes (filter (lambda (id) (hash-get stale-set id)) (.ref dag 'topological-order)))
           (unaffected-nodes (filter (lambda (id) (not (hash-get stale-set id))) (.ref dag 'topological-order))))
      (.o bind-these: #f
          kind: 'agentic-ai-lab.funflow.premise-invalidation.v1
          stale-nodes: stale-nodes
          unaffected-nodes: unaffected-nodes
          invalidated-reasons: (reverse reasons-rev)))))

;;; Multi-Repo WorkspaceTopology & PreFlightRemoteDriftProbe (Slice 49)
(.def WorkspaceTopology.
  kind: 'agentic-ai-lab.funflow.workspace-topology.v1
  workspace-id: "workspace-default"
  repos: '()
  pin-edges: '()
  declassification-required?: #t)

(def (funflow-workspace-plan topology remote-heads: (remote-heads '()))
  ;; Each repo entry: (.o repo-id: "repo" local-head: "sha" branch: "main" ...)
  ;; Each pin-edge: (cons downstream-repo-id upstream-repo-id)
  (let* ((repos (opt-ref topology 'repos '()))
         (pin-edges (opt-ref topology 'pin-edges '()))
         (drift-reports
          (map
           (lambda (repo)
             (let* ((rid (opt-ref repo 'repo-id "repo"))
                    (local-sha (opt-ref repo 'local-head ""))
                    (remote-entry (assoc rid remote-heads))
                    (remote-sha (and remote-entry (cdr remote-entry)))
                    (drifted? (and remote-sha (not (equal? local-sha remote-sha)))))
               (.o bind-these: #f
                   repo-id: rid
                   local-head: local-sha
                   remote-head: remote-sha
                   drift-detected?: (and drifted? #t))))
           repos))
         (dag-nodes
          (map
           (lambda (repo)
             (let* ((rid (opt-ref repo 'repo-id "repo"))
                    (upstreams
                     (map cdr
                          (filter (lambda (edge) (equal? (car edge) rid)) pin-edges))))
               (funflow-dag-node rid
                                 needs: upstreams
                                 source-cut: (opt-ref repo 'local-head "HEAD")
                                 effect-class: FencedEffect.
                                 idempotency-key: (string-append "push:" rid ":" (opt-ref repo 'local-head "HEAD")))))
           repos))
         (dag (funflow-dag-build dag-nodes))
         (any-drift? (let loop ((ds drift-reports))
                       (cond
                        ((null? ds) #f)
                        ((.ref (car ds) 'drift-detected?) #t)
                        (else (loop (cdr ds)))))))
    (.o bind-these: #f
        kind: 'agentic-ai-lab.funflow.workspace-plan.v1
        workspace-id: (opt-ref topology 'workspace-id "workspace-default")
        valid?: (.ref dag 'valid?)
        any-remote-drift?: any-drift?
        replan-required?: any-drift?
        push-order: (.ref dag 'topological-order)
        drift-reports: drift-reports
        dag: dag)))

(def FunflowDurableDagExports
  (.o bind-these: #f
      FunflowNode: FunflowNode.
      EffectClass: EffectClass.
      PureCAS: PureCAS.
      VerifiedEpistemic: VerifiedEpistemic.
      FencedEffect: FencedEffect.
      ExternalSandboxProfile: ExternalSandboxProfile.
      admit-external-task-sandbox: funflow-admit-external-task-sandbox
      EffectAdmissionProtocol: EffectAdmissionProtocol
      FunflowEffectMethods: FunflowEffectMethods
      admit-node-effect: funflow-admit-node-effect
      envelope-meet: funflow-envelope-meet
      WorkspaceTopology: WorkspaceTopology.
      workspace-plan: funflow-workspace-plan
      invalidate-premises: funflow-invalidate-premises
      OrchestratorStrategy: OrchestratorStrategy.
      ParallelFrontierStrategy: ParallelFrontierStrategy.
      TieredModelStrategy: TieredModelStrategy.
      DurableGovernedStrategy: DurableGovernedStrategy.
      admit-node: strategy-admit-node
      admit-frontier: strategy-admit-frontier
      cas-fingerprint: strategy-cas-fingerprint
      archive-guard: strategy-archive-guard
      dag-node: funflow-dag-node
      dag-build: funflow-dag-build
      dag?: funflow-dag?
      node-cas-fingerprint: funflow-cas-fingerprint
      pure-cas-content-key: funflow-pure-cas-content-key
      canonical-sha256: funflow-canonical-sha256
      admit-frontier-with: funflow-admit-frontier-with
      resume-plan: funflow-resume-plan
      replan-epoch: funflow-replan-epoch))
