;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: Marlin-facing loop governor ABI projections live here.
;;; Responsibility: publish ABI manifests from validated governor contracts.
;;; Responsibility: publish Marlin request envelopes for =govern-loop=.
;;; Responsibility: publish L1 report receipts with no write effects.
;;; Responsibility: publish runtime discovery manifests for Marlin.
;;; Import boundary: this module may depend on =:agentic-ai-lab/modules/loop-engine/control/governor=.
;;; Import boundary: this module may depend on =:yuanxu/modules/funflow/control-plane/failure=.
;;; Import boundary: the core governor must not import Marlin wrappers.
;;; Export boundary: =:agentic-ai-lab/modules/loop-engine/control/agent= re-exports this owner for callers.
;;; Runtime boundary: this module never polls or schedules loops.
;;; Runtime boundary: this module never locks or writes state.
;;; Runtime boundary: this module never executes connectors or starts loops.
;;; Parser evidence: owner-items expose schemas and projection functions here.
;;; Policy evidence: tests assert schemas, envelopes, receipts, and manifests.

(import :yuanxu/modules/funflow/control-plane/failure
        (only-in :agentic-ai-lab/modules/loop-engine/core
                 +agentic-ai-lab-user-loop-engine-handoff-contracts+
                 +agentic-ai-lab-user-loop-engine-receipt-contracts+
                 +agentic-ai-lab-user-loop-engine-runtime-command-arguments+
                 +agentic-ai-lab-user-loop-engine-runtime-command-contract+
                 +agentic-ai-lab-user-loop-engine-runtime-command-executable+
                 +agentic-ai-lab-user-loop-engine-runtime-command-name+
                 +agentic-ai-lab-user-loop-engine-runtime-object-families+
                 +agentic-ai-lab-user-loop-engine-runtime-packet-contracts+)
        :agentic-ai-lab/modules/loop-engine/control/governor)

(export +loop-governor-marlin-request-schema+
        +loop-governor-marlin-abi-schema+
        +loop-governor-l1-run-receipt-schema+
        +loop-governor-marlin-runtime-manifest-schema+
        +loop-governor-marlin-loop-engine-discovery-schema+
        loop-governor-marlin-loop-engine-discovery
        loop-governor-marlin-abi-manifest
        loop-governor-marlin-request-envelope-validation-errors
        validate-loop-governor-marlin-request-envelope
        loop-governor->marlin-request-envelope
        loop-governor->l1-run-receipt
        loop-governor->marlin-runtime-manifest)

;;; Boundary: request schema names the ABI wrapper that Marlin consumes.
;;; Intent: keep the nested governor contract stable and separately typed.
;; : (-> Unit LoopGovernorMarlinRequestSchema)
(def +loop-governor-marlin-request-schema+
  'agentic-ai-lab.loop-governor.marlin-request.v1)

;;; Boundary: ABI schema names Rust-side discovery, not a request instance.
;;; Intent: Marlin can pin fields without executing or constructing Scheme data.
;; : (-> Unit LoopGovernorMarlinAbiSchema)
(def +loop-governor-marlin-abi-schema+
  'agentic-ai-lab.loop-governor.marlin-abi.v1)

;;; Boundary: L1 receipts are report-only proof objects.
;;; Invariant: the receipt records handoff readiness without state writes.
;; : (-> Unit LoopGovernorL1RunReceiptSchema)
(def +loop-governor-l1-run-receipt-schema+
  'agentic-ai-lab.loop-governor.l1-run-receipt.v1)

;;; Boundary: runtime manifest schema is the Marlin discovery entry.
;;; Intent: consumers bind to data fields instead of guessing Scheme constructors.
;; : (-> Unit LoopGovernorMarlinRuntimeManifestSchema)
(def +loop-governor-marlin-runtime-manifest-schema+
  'agentic-ai-lab.loop-governor.marlin-runtime-manifest.v1)

;;; Boundary: loop-engine discovery is metadata for Marlin handoff consumers.
;;; Intent: consumers find receipt families without guessing Scheme internals.
;; : (-> Unit LoopGovernorMarlinLoopEngineDiscoverySchema)
(def +loop-governor-marlin-loop-engine-discovery-schema+
  'agentic-ai-lab.loop-engine.marlin-discovery.v1)

;;; Boundary: Marlin projections keep alist probing local to avoid exporting
;;; core governor internals only for ABI wrapper assembly.
;; : (-> Alist Symbol AlistValue AlistValue)
(def (loop-governor-marlin-alist-ref alist key default)
  (let (found (and (list? alist) (assoc key alist)))
    (if found (cdr found) default)))

;;; Boundary: request-envelope validation reports wrapper shape errors without
;;; coupling Marlin-specific schemas back into the core governor module.
;; : (-> Symbol FieldValue [ValidationError])
(def (loop-governor-marlin-required-field-error/tail field value tail)
  (if value
    tail
    (cons (list (cons 'field field)
                (cons 'code 'required))
          tail)))

;; : (-> Symbol FieldValue [ValidationError])
(def (loop-governor-marlin-required-field-error field value)
  (loop-governor-marlin-required-field-error/tail field value '()))

;;; Boundary: this table is shared discovery for the newer loop-engine handoff.
;;; Invariant: it references the loop-engine constants instead of duplicating
;;; receipt contracts, object families, or command-shape vocabulary.
;; : (-> Unit Alist)
(def (loop-governor-marlin-loop-engine-discovery)
  (list
   (cons 'schema +loop-governor-marlin-loop-engine-discovery-schema+)
   (cons 'kind 'loop-engine-marlin-discovery)
   (cons 'operation 'loop-engine-runtime-handoff)
   (cons 'runtime-command-contract
         +agentic-ai-lab-user-loop-engine-runtime-command-contract+)
   (cons 'runtime-command-name
         +agentic-ai-lab-user-loop-engine-runtime-command-name+)
   (cons 'runtime-command-executable
         +agentic-ai-lab-user-loop-engine-runtime-command-executable+)
   (cons 'runtime-command-arguments
         +agentic-ai-lab-user-loop-engine-runtime-command-arguments+)
   (cons 'handoff-contracts
         +agentic-ai-lab-user-loop-engine-handoff-contracts+)
   (cons 'object-families
         +agentic-ai-lab-user-loop-engine-runtime-object-families+)
   (cons 'receipt-contracts
         +agentic-ai-lab-user-loop-engine-receipt-contracts+)
   (cons 'runtime-packet-contracts
         +agentic-ai-lab-user-loop-engine-runtime-packet-contracts+)
   (cons 'control-owner 'gerbil)
   (cons 'execution-owner 'marlin-agent-core)
   (cons 'runtime-executed #f)))

;;; Boundary: ABI manifest publishes the stable marlin-agent-core field set.
;;; Invariant: this metadata describes contract shape and never runs a loop.
;; : (-> Unit Alist)
(def (loop-governor-marlin-abi-manifest)
  (list (cons 'schema +loop-governor-marlin-abi-schema+)
        (cons 'producer 'agentic-ai-lab)
        (cons 'consumer 'marlin-agent-core)
        (cons 'transport 'scheme-abi)
        (cons 'operation 'govern-loop)
        (cons 'request-schema +loop-governor-marlin-request-schema+)
        (cons 'governor-schema +loop-governor-schema+)
        (cons 'l1-run-receipt-schema
              +loop-governor-l1-run-receipt-schema+)
        (cons 'runtime-manifest-schema
              +loop-governor-marlin-runtime-manifest-schema+)
        (cons 'loop-engine-discovery-schema
              +loop-governor-marlin-loop-engine-discovery-schema+)
        (cons 'loop-engine-discovery
              (loop-governor-marlin-loop-engine-discovery))
        (cons 'required-fields
              '(schema governor-schema operation target transport governor))
        (cons 'optional-fields
              '(request-id abi-manifest contract state-facts open-patterns
                blocked-patterns agent-judges agent-judge-nodes
                human-inbox-items runtime-boundary loop-engine-discovery
                object-families receipt-contracts runtime-command-contract
                control-owner execution-owner metadata))
        (cons 'runtime-boundary
              '((local-execution . validation-only)
                (production-execution . marlin-agent-core)))
        (cons 'control-owner 'gerbil)
        (cons 'execution-owner 'marlin-agent-core)))

;;; Boundary: request validation checks only the Marlin ABI wrapper.
;;; Intent: governor policy validation stays owned by the nested contract.
;; : (-> Alist [ValidationError])
(def (loop-governor-marlin-request-envelope-validation-errors envelope)
  (if (list? envelope)
    (loop-governor-marlin-required-field-error/tail
     'schema
     (and (eq? (loop-governor-marlin-alist-ref envelope 'schema #f)
               +loop-governor-marlin-request-schema+)
          #t)
     (loop-governor-marlin-required-field-error/tail
      'governor-schema
      (and (eq? (loop-governor-marlin-alist-ref envelope 'governor-schema #f)
                +loop-governor-schema+)
           #t)
      (loop-governor-marlin-required-field-error/tail
       'operation
       (loop-governor-marlin-alist-ref envelope 'operation #f)
       (loop-governor-marlin-required-field-error/tail
        'target
        (loop-governor-marlin-alist-ref envelope 'target #f)
        (loop-governor-marlin-required-field-error/tail
         'transport
         (loop-governor-marlin-alist-ref envelope 'transport #f)
         (loop-governor-marlin-required-field-error/tail
          'governor
          (loop-governor-marlin-alist-ref envelope 'governor #f)
          '()))))))
    (list '((field . marlin-request-envelope) (code . not-alist)))))

;; : (-> [Symbol] [Symbol] [Symbol])
(def (loop-governor-marlin-blocked-patterns conflicting-patterns
                                             denied-patterns)
  (if (null? conflicting-patterns)
    denied-patterns
    (cons (car conflicting-patterns)
          (loop-governor-marlin-blocked-patterns
           (cdr conflicting-patterns)
           denied-patterns))))

;;; Boundary: invalid envelopes fail before leaving the Scheme control plane.
;;; Intent: downstream tests inspect typed failures, not malformed strings.
;; : (-> Alist MarlinRequestEnvelope)
(def (validate-loop-governor-marlin-request-envelope envelope)
  (let (errors
        (loop-governor-marlin-request-envelope-validation-errors envelope))
    (if (null? errors)
      envelope
      (raise-control-plane-failure
       'loop-governor
       'invalid-loop-governor-marlin-request-envelope
       "invalid loop governor Marlin request envelope"
       (list (cons 'errors errors)
             (cons 'marlin-request-envelope envelope))))))

;;; Boundary: request projection packages governor facts for marlin-agent-core.
;;; Invariant: projection never submits, schedules, locks, mutates, or persists.
;; : (-> LoopGovernor [Alist] [RequestId] MarlinRequestEnvelope)
(def (loop-governor->marlin-request-envelope
      governor
      states
      . maybe-request-id)
  (let* ((contract (loop-governor->contract governor states))
         (handoff (loop-governor-marlin-alist-ref contract 'handoff '()))
         (request-id (if (null? maybe-request-id)
                       #f
                       (car maybe-request-id))))
    (validate-loop-governor-marlin-request-envelope
     (list (cons 'schema +loop-governor-marlin-request-schema+)
           (cons 'governor-schema
                 (loop-governor-marlin-alist-ref contract 'schema #f))
           (cons 'operation 'govern-loop)
           (cons 'request-id request-id)
           (cons 'abi-manifest
                 (loop-governor-marlin-abi-manifest))
           (cons 'loop-engine-discovery
                 (loop-governor-marlin-loop-engine-discovery))
           (cons 'target
                 (loop-governor-marlin-alist-ref handoff 'target #f))
           (cons 'transport
                 (loop-governor-marlin-alist-ref handoff 'transport #f))
           (cons 'contract
                 (loop-governor-marlin-alist-ref handoff 'contract #f))
           (cons 'governor contract)
           (cons 'state-facts states)
           (cons 'open-patterns
                 (loop-governor-marlin-alist-ref contract 'open-patterns '()))
           (cons 'blocked-patterns
                 (loop-governor-marlin-blocked-patterns
                  (loop-governor-marlin-alist-ref
                   contract
                   'conflicting-patterns
                   '())
                  (loop-governor-marlin-alist-ref
                   contract
                   'denied-patterns
                   '())))
           (cons 'agent-judges
                 (loop-governor-marlin-alist-ref
                  contract
                  'agent-judges
                  '()))
           (cons 'agent-judge-nodes
                 (loop-governor-marlin-alist-ref
                  contract
                  'agent-judge-nodes
                  '()))
           (cons 'human-inbox-items
                 (loop-governor-marlin-alist-ref
                  contract
                  'human-inbox-items
                  '()))
           (cons 'runtime-boundary
                 (loop-governor-marlin-alist-ref
                  contract
                  'runtime-boundary
                  '()))
           (cons 'control-owner
                 (loop-governor-marlin-alist-ref contract 'control-owner #f))
           (cons 'execution-owner
                 (loop-governor-marlin-alist-ref contract 'execution-owner #f))
           (cons 'metadata
                 (loop-governor-marlin-alist-ref contract 'metadata '()))))))

;;; Boundary: L1 receipt projects report-only handoff outcome for a governor.
;;; Invariant: no schedule, state write, or external effect is represented.
;; : (-> LoopGovernor [Alist] [RequestId] Alist)
(def (loop-governor->l1-run-receipt governor states . maybe-request-id)
  (let* ((request-id (if (null? maybe-request-id)
                       #f
                       (car maybe-request-id)))
         (envelope
          (loop-governor->marlin-request-envelope
           governor
           states
           request-id))
         (contract
          (loop-governor-marlin-alist-ref envelope 'governor '())))
    (list (cons 'schema +loop-governor-l1-run-receipt-schema+)
          (cons 'kind 'loop-run-receipt)
          (cons 'level 'l1)
          (cons 'mode 'report-only)
          (cons 'operation 'govern-loop)
          (cons 'status 'handoff-ready)
          (cons 'request-id request-id)
          (cons 'governor-schema
                (loop-governor-marlin-alist-ref envelope 'governor-schema #f))
          (cons 'request-schema
                (loop-governor-marlin-alist-ref envelope 'schema #f))
          (cons 'target
                (loop-governor-marlin-alist-ref envelope 'target #f))
          (cons 'transport
                (loop-governor-marlin-alist-ref envelope 'transport #f))
          (cons 'open-patterns
                (loop-governor-marlin-alist-ref envelope 'open-patterns '()))
          (cons 'blocked-patterns
                (loop-governor-marlin-alist-ref envelope 'blocked-patterns '()))
          (cons 'agent-judges
                (loop-governor-marlin-alist-ref envelope 'agent-judges '()))
          (cons 'agent-judge-nodes
                (loop-governor-marlin-alist-ref
                 envelope
                 'agent-judge-nodes
                 '()))
          (cons 'human-inbox-items
                (loop-governor-marlin-alist-ref
                 envelope
                 'human-inbox-items
                 '()))
          (cons 'handoff
                (loop-governor-marlin-alist-ref contract 'handoff '()))
          (cons 'request-envelope envelope)
          (cons 'state-facts states)
          (cons 'state-writes '())
          (cons 'effects '())
          (cons 'schedules '())
          (cons 'runtime-boundary
                (loop-governor-marlin-alist-ref
                 envelope
                 'runtime-boundary
                 '()))
          (cons 'control-owner
                (loop-governor-marlin-alist-ref envelope 'control-owner #f))
          (cons 'execution-owner
                (loop-governor-marlin-alist-ref envelope 'execution-owner #f))
          (cons 'metadata
                '((receipt . l1-report-only)
                  (handoff . marlin-agent-core)
                  (writes . none))))))

;;; Boundary: runtime manifest exposes the govern-loop request for discovery.
;;; Intent: Marlin decides if and when to consume the inert request envelope.
;; : (-> LoopGovernor [Alist] [RequestId] Alist)
(def (loop-governor->marlin-runtime-manifest
      governor
      states
      . maybe-request-id)
  (let* ((request-id (if (null? maybe-request-id)
                       #f
                       (car maybe-request-id)))
         (envelope
          (loop-governor->marlin-request-envelope
           governor
           states
           request-id)))
    (list (cons 'schema +loop-governor-marlin-runtime-manifest-schema+)
          (cons 'kind 'loop-governor-runtime-manifest)
          (cons 'bridge 'runtime-manifest)
          (cons 'producer 'agentic-ai-lab)
          (cons 'consumer 'marlin-agent-core)
          (cons 'operation 'govern-loop)
          (cons 'request-id request-id)
          (cons 'request-schema
                (loop-governor-marlin-alist-ref envelope 'schema #f))
          (cons 'request-envelope envelope)
          (cons 'abi-manifest
                (loop-governor-marlin-alist-ref envelope 'abi-manifest '()))
          (cons 'loop-engine-discovery
                (loop-governor-marlin-loop-engine-discovery))
          (cons 'object-families
                +agentic-ai-lab-user-loop-engine-runtime-object-families+)
          (cons 'receipt-contracts
                +agentic-ai-lab-user-loop-engine-receipt-contracts+)
          (cons 'runtime-command-contract
                +agentic-ai-lab-user-loop-engine-runtime-command-contract+)
          (cons 'receipt-schema +loop-governor-l1-run-receipt-schema+)
          (cons 'target
                (loop-governor-marlin-alist-ref envelope 'target #f))
          (cons 'transport
                (loop-governor-marlin-alist-ref envelope 'transport #f))
          (cons 'runtime-boundary
                (loop-governor-marlin-alist-ref
                 envelope
                 'runtime-boundary
                 '()))
          (cons 'control-owner
                (loop-governor-marlin-alist-ref envelope 'control-owner #f))
          (cons 'execution-owner
                (loop-governor-marlin-alist-ref envelope 'execution-owner #f)))))
