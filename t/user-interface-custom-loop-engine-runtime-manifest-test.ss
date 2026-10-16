;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: tests verify concrete loop-engine runtime manifest projection.
;;; Invariant: manifest rows are inert Marlin handoff data, not execution.

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        :core/module-system/selection/objects
        :poo-flow/modules/workflow/scenario/configuration/interface
        :poo-flow/modules/workflow/scenario/configuration/init-syntax
        (only-in :poo-flow/modules/loop-engine/control/governor-marlin
                 +loop-governor-marlin-loop-engine-discovery-schema+
                 loop-governor-marlin-loop-engine-discovery)
        (only-in :poo-flow/modules/cubeSandbox/config
                 poo-flow-cubeSandbox-module-bundles)
        (only-in :poo-flow/modules/nono-sandbox/config
                 poo-flow-nono-sandbox-module-bundles)
        (only-in "./support/loop-engine-runtime-manifest-receipts"
                 check-custom-loop-runtime-manifest-request-receipts)
        (only-in "../user-interface/custom/my-module/cases/loop-engine-owner"
                 poo-flow-custom-my-module-loop-engine-case))

(export user-interface-custom-loop-engine-runtime-manifest-test)

;;; Test lookup mirrors the public alist payload shape emitted by presentation;
;;; it intentionally avoids reaching back into POO objects or private helpers.
;; : (-> Alist Symbol MaybeValue)
(def (test-ref alist key)
  (let (entry (assoc key alist))
    (if entry (cdr entry) #f)))

;;; Field collection checks runtime request row order without coupling the test
;;; to each row's full payload.
;; : (-> [Alist] Symbol [Value])
(def (test-field-values rows key)
  (map (lambda (row) (test-ref row key)) rows))

;;; Expected manifest vocabularies pin the ABI-facing object families and agent
;;; names that Marlin can discover without guessing the entrypoint.
;; : [Symbol]
(def expected-loop-engine-agent-names
  '(ci-audit-agent
    build-verifier-agent
    ci-loop-governor
    human-audit))

;; : [Symbol]
(def expected-loop-engine-object-families
  '(agent-profile
    agent-harness
    agent-session
    session-agent-graph
    workflow-run
    dispatch-receipt
    agent-operation
    lineage-receipt
    selector-receipt
    resource-dispatch-receipt
    capability-receipt
    memory-receipt
    compression-receipt
    policy-extension-receipt
    spec-evolution-review-item
    spec-evolution-runtime-manifest-row
    runtime-capability-descriptor
    policy-profile-packet
    runtime-action-packet
    runtime-receipt-batch
    runtime-snapshot))

;; : Alist
(def expected-loop-engine-receipt-contracts
  '((lineage-receipt
     . poo-flow.loop-engine.lineage-receipt.v1)
    (selector-receipt
     . poo-flow.loop-engine.selector-receipt.v1)
    (session-agent-graph
     . poo-flow.modules.session.agent-graph.v1)
    (resource-dispatch-receipt
     . poo-flow.loop-engine.resource-dispatch-receipt.v1)
    (capability-receipt
     . poo-flow.loop-engine.capability-receipt.v1)
    (memory-receipt
     . poo-flow.loop-engine.memory-receipt.v1)
    (compression-receipt
     . poo-flow.loop-engine.compression-receipt.v1)
    (policy-extension-receipt
     . poo-flow.loop-engine.policy-extension-receipt.v1)
    (spec-evolution-review
     . poo-flow.spec-evolution.review-item.v1)
    (spec-evolution-runtime-manifest-row
     . poo-flow.spec-evolution.runtime-manifest-row.v1)
    (runtime-capability-descriptor
     . poo-flow.runtime.capability-descriptor.v1)
    (policy-profile-packet
     . poo-flow.runtime.policy-profile-packet.v1)
    (runtime-action-packet
     . poo-flow.runtime.action-packet.v1)
    (runtime-receipt-batch
     . poo-flow.runtime.receipt-batch.v1)
    (sandbox-handoff-agreement
     . poo-flow.loop-engine.sandbox-handoff-agreement.v1)))

;; : Alist
(def expected-loop-engine-runtime-packet-contracts
  '((runtime-capability-descriptor
     . poo-flow.runtime.capability-descriptor.v1)
    (policy-profile-packet
     . poo-flow.runtime.policy-profile-packet.v1)
    (runtime-action-packet
     . poo-flow.runtime.action-packet.v1)
    (runtime-receipt-batch
     . poo-flow.runtime.receipt-batch.v1)))

;; : Symbol
(def expected-loop-engine-human-audit-result-contract
  'poo-flow.loop-governor.human-audit-decision.v1)

;; : Symbol
(def expected-loop-engine-spec-evolution-proposal-id
  'sandbox-profile-human-audit-before-ci-change)

;;; Presentation construction goes through the facade because the ABI manifest
;;; must be discoverable from normal `use-module` configuration.
;; : (-> PooUserModuleSelection POOObject)
(def (custom-loop-presentation module-bundle)
  (pooFlowUserConfigPresentation
   (pooFlowUserConfig
    (poo-flow-user-module-bundles->modules
     (append poo-flow-nono-sandbox-module-bundles
             poo-flow-cubeSandbox-module-bundles
             (list module-bundle)))
    (poo-flow-settings))))

;;; Manifest descriptor assertions prove the adapter row is inert command data,
;;; not evidence that Scheme launched Marlin.
;; : (-> Alist Alist)
(def (check-custom-loop-runtime-manifest-descriptor runtime-manifest
                                                    runtime-manifest-summary)
  (check-equal? (test-ref runtime-manifest 'schema)
                'poo-flow.runtime-command-descriptor.v1)
  (check-equal? (test-ref runtime-manifest 'request-schema)
                'poo-flow.runtime-request.v1)
  (check-equal? (test-ref runtime-manifest 'operation)
                'loop-engine-handoff)
  (check-equal? (test-ref runtime-manifest 'executable)
                "marlin-agent-core")
  (check-equal? (test-ref runtime-manifest 'argv)
                '("marlin-agent-core"
                  "poo-flow"
                  "runtime"
                  "loop-engine-handoff"))
  (check-equal? (test-ref (test-ref runtime-manifest 'metadata) 'contract)
                'poo-flow.loop-governor.runtime-command-manifest.v1)
  (check-equal? (test-ref runtime-manifest-summary 'kind)
                'runtime-command-manifest-summary)
  (check-equal? (test-ref runtime-manifest-summary 'operation)
                'loop-engine-handoff)
  (check-equal? (test-ref runtime-manifest-summary 'object-families)
                expected-loop-engine-object-families)
  (check-equal? (test-ref runtime-manifest-summary 'receipt-contracts)
                expected-loop-engine-receipt-contracts)
  (check-equal? (test-ref runtime-manifest-summary
                          'runtime-packet-contracts)
                expected-loop-engine-runtime-packet-contracts))

;;; Discovery assertions keep the legacy govern-loop ABI manifest and the newer
;;; runtime handoff manifest on one vocabulary surface for Marlin consumers.
;; : (-> Alist Alist Alist)
(def (check-custom-loop-runtime-manifest-discovery runtime-manifest
                                                   runtime-manifest-request
                                                   runtime-manifest-summary)
  (let (discovery (loop-governor-marlin-loop-engine-discovery))
    (check-equal? (test-ref discovery 'schema)
                  +loop-governor-marlin-loop-engine-discovery-schema+)
    (check-equal? (test-ref discovery 'kind)
                  'loop-engine-marlin-discovery)
    (check-equal? (test-ref discovery 'runtime-command-contract)
                  (test-ref runtime-manifest-request 'contract))
    (check-equal? (test-ref discovery 'runtime-command-executable)
                  (test-ref runtime-manifest 'executable))
    (check-equal? (test-ref discovery 'object-families)
                  expected-loop-engine-object-families)
    (check-equal? (test-ref discovery 'object-families)
                  (test-ref runtime-manifest-request 'object-families))
    (check-equal? (test-ref discovery 'object-families)
                  (test-ref runtime-manifest-summary 'object-families))
    (check-equal? (test-ref discovery 'receipt-contracts)
                  expected-loop-engine-receipt-contracts)
    (check-equal? (test-ref discovery 'receipt-contracts)
                  (test-ref runtime-manifest-request 'receipt-contracts))
    (check-equal? (test-ref discovery 'receipt-contracts)
                  (test-ref runtime-manifest-summary 'receipt-contracts))
    (check-equal? (test-ref discovery 'runtime-packet-contracts)
                  expected-loop-engine-runtime-packet-contracts)
    (check-equal? (test-ref discovery 'runtime-packet-contracts)
                  (test-ref runtime-manifest-request
                            'runtime-packet-contracts))
    (check-equal? (test-ref discovery 'runtime-packet-contracts)
                  (test-ref runtime-manifest-summary
                            'runtime-packet-contracts))
    (check-equal? (test-ref discovery 'control-owner) 'gerbil)
    (check-equal? (test-ref discovery 'execution-owner) 'marlin-agent-core)
    (check-equal? (test-ref discovery 'runtime-executed) #f)))

;;; Manifest request contract assertions keep result and object-family schema
;;; checks separate from concrete policy receipt checks.
;; : (-> Alist)
(def (check-custom-loop-runtime-manifest-request-contracts
      runtime-manifest-request)
  (check-equal? (test-ref runtime-manifest-request 'kind)
                'loop-engine-runtime-handoff-request)
  (check-equal? (test-ref runtime-manifest-request 'contract)
                'poo-flow.loop-governor.runtime-command-manifest.v1)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'result-contract)
                          'human-audit)
                expected-loop-engine-human-audit-result-contract)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'result-contract)
                          'valid?)
                #t)
  (check-equal? (test-ref runtime-manifest-request 'object-families)
                expected-loop-engine-object-families)
  (check-equal? (test-ref runtime-manifest-request 'receipt-contracts)
                expected-loop-engine-receipt-contracts)
  (check-equal? (test-ref runtime-manifest-request
                          'runtime-packet-contracts)
                expected-loop-engine-runtime-packet-contracts)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'lineage-receipt)
                          'lineage-kind)
                'guarded-handoff)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'selector-receipt)
                          'selected-branch)
                'current-system-build-loop))

;;; Runtime packets are the Marlin pressure-relief layer: Scheme projects
;;; normalized policy/action facts, while execution receipts remain empty.
;; : (-> Alist)
(def (check-custom-loop-runtime-manifest-runtime-packets
      runtime-manifest-request)
  (let* ((runtime-capability-descriptor
          (test-ref runtime-manifest-request
                    'runtime-capability-descriptor))
         (policy-profile-packet
          (test-ref runtime-manifest-request 'policy-profile-packet))
         (runtime-action-packet
          (car (test-ref runtime-manifest-request
                         'runtime-action-packets)))
         (runtime-receipt-batch-template
          (test-ref runtime-manifest-request
                    'runtime-receipt-batch-template)))
    (check-equal? (test-ref runtime-capability-descriptor 'contract)
                  'poo-flow.runtime.capability-descriptor.v1)
    (check-equal? (test-ref runtime-capability-descriptor 'runtime-language)
                  'rust)
    (check-equal? (test-ref runtime-capability-descriptor 'transport-class)
                  'manifest)
    (check-equal? (test-ref runtime-capability-descriptor
                            'runtime-packet-contracts)
                  expected-loop-engine-runtime-packet-contracts)
    (check-equal? (test-ref runtime-capability-descriptor
                            'supports-readiness-gates?)
                  #t)
    (check-equal? (test-ref runtime-capability-descriptor
                            'runtime-executed)
                  #f)
    (check-equal? (test-ref policy-profile-packet 'contract)
                  'poo-flow.runtime.policy-profile-packet.v1)
    (check-equal? (test-ref policy-profile-packet 'profile-id)
                  'loop-engine/current-system-build-loop/policy-profile)
    (check-equal? (test-ref policy-profile-packet 'source-refs)
                  '(current-system-build-loop))
    (check-equal? (test-ref (test-ref policy-profile-packet
                                       'queue-policy)
                            'prioritize-steering)
                  #t)
    (check-equal? (test-ref policy-profile-packet 'runtime-executed)
                  #f)
    (check-equal? (test-ref runtime-action-packet 'contract)
                  'poo-flow.runtime.action-packet.v1)
    (check-equal? (test-ref runtime-action-packet 'action-kind)
                  'ask-owner)
    (check-equal? (test-ref runtime-action-packet 'profile-id)
                  'loop-engine/current-system-build-loop/policy-profile)
    (check-equal? (test-ref runtime-action-packet 'candidate-refs)
                  '(current-system-build-loop current-system-recovery-loop))
    (check-equal? (test-ref (test-ref runtime-action-packet 'gate-state)
                            'sandbox-handoff-ready?)
                  #f)
    (check-equal? (test-field-values
                   (test-ref runtime-action-packet 'readiness-receipts)
                   'status)
                  '(ready))
    (check-equal? (test-ref runtime-action-packet 'runtime-executed)
                  #f)
    (check-equal? (test-ref runtime-receipt-batch-template 'contract)
                  'poo-flow.runtime.receipt-batch.v1)
    (check-equal? (test-ref runtime-receipt-batch-template 'status)
                  'not-executed)
    (check-equal? (test-ref runtime-receipt-batch-template
                            'accepted-packet-ids)
                  '())
    (check-equal? (test-ref runtime-receipt-batch-template
                            'runtime-executed)
                  #f)))

;;; Manifest graph assertions verify agent and sandbox rows keep the same
;;; public shape after entering the handoff request payload.
;; : (-> Alist)
(def (check-custom-loop-runtime-manifest-request-graph
      runtime-manifest-request)
  (check-equal? (test-field-values (test-ref runtime-manifest-request
                                             'agent-profiles)
                                   'name)
                expected-loop-engine-agent-names)
  (check-equal? (test-field-values (test-ref runtime-manifest-request
                                             'agent-sessions)
                                   'workflow-run?)
                '(#f #f #f #f))
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'session-agent-graph)
                          'kind)
                'poo-flow.session.agent-graph)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'session-agent-graph)
                          'schema)
                'poo-flow.modules.session.agent-graph.v1)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'session-agent-graph)
                          'agent-count)
                4)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'session-agent-graph)
                          'communication-receipt-count)
                8)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'session-agent-topology-trace)
                          'valid?)
                #t)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'session-agent-topology-trace)
                          'diagnostic-count)
                0)
  (check-equal? (test-ref runtime-manifest-request 'sandbox-profile-refs)
                '(ci/build))
  (check-equal? (test-ref runtime-manifest-request 'sandbox-runtime-summaries)
                '())
  (check-equal? (test-ref runtime-manifest-request
                          'sandbox-unresolved-profile-refs)
                '(ci/build))
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'sandbox-handoff-agreement)
                          'valid?)
                #f)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'agent-operation)
                          'operation-kind)
                'human-audit)
  (check-equal? (test-ref (test-ref runtime-manifest-request
                                     'delegated-operation)
                          'reviewer-agent)
                'build-verifier-agent))

;;; Runtime handoff facts are a projection bundle around the request payload.
;;; The sandbox agreement inside the bundle stays explicit validation logic.
;; : (-> Alist Alist)
(def (check-custom-loop-runtime-handoff-facts intent
                                              runtime-manifest-request)
  (let* ((runtime-handoff-facts
          (test-ref intent 'runtime-handoff-facts))
         (sandbox-handoff-agreement
          (test-ref runtime-handoff-facts
                    'sandbox-handoff-agreement))
         (runtime-action-packet
          (car (test-ref runtime-handoff-facts
                         'runtime-action-packets))))
    (check-equal? (test-ref runtime-handoff-facts 'kind)
                  'loop-engine-runtime-handoff)
    (check-equal? (test-ref runtime-handoff-facts 'contract)
                  'poo-flow.loop-governor.runtime-handoff.v1)
    (check-equal? (test-ref runtime-handoff-facts 'runtime-owner)
                  "marlin-agent-core")
    (check-equal? (test-ref runtime-handoff-facts 'runtime-handoff)
                  'loop-governor-marlin-runtime-manifest)
    (check-equal? (test-ref runtime-handoff-facts
                            'runtime-command-contract)
                  (test-ref runtime-manifest-request 'contract))
    (check-equal? (test-ref runtime-handoff-facts 'object-families)
                  expected-loop-engine-object-families)
    (check-equal? (test-ref runtime-handoff-facts 'receipt-contracts)
                  expected-loop-engine-receipt-contracts)
    (check-equal? (test-ref runtime-handoff-facts
                            'runtime-packet-contracts)
                  expected-loop-engine-runtime-packet-contracts)
    (check-equal? (test-ref (test-ref runtime-handoff-facts
                                       'runtime-capability-descriptor)
                            'contract)
                  'poo-flow.runtime.capability-descriptor.v1)
    (check-equal? (test-ref (test-ref runtime-handoff-facts
                                       'policy-profile-packet)
                            'profile-id)
                  'loop-engine/current-system-build-loop/policy-profile)
    (check-equal? (test-ref runtime-action-packet 'action-kind)
                  'ask-owner)
    (check-equal? (test-ref (test-ref runtime-handoff-facts
                                       'runtime-receipt-batch-template)
                            'status)
                  'not-executed)
    (check-equal? (test-ref (test-ref runtime-handoff-facts
                                       'lineage-receipt)
                            'contract)
                  'poo-flow.loop-engine.lineage-receipt.v1)
    (check-equal? (test-ref (test-ref runtime-handoff-facts
                                       'selector-receipt)
                            'candidates)
                  '(current-system-build-loop current-system-recovery-loop))
    (check-equal? (test-ref (test-ref runtime-handoff-facts
                                       'selector-receipt)
                            'selected-branch)
                  'current-system-build-loop)
    (check-equal? (test-ref (test-ref runtime-handoff-facts
                                       'capability-receipt)
                            'valid?)
                  #t)
    (check-equal? (test-ref (test-ref runtime-handoff-facts
                                       'memory-receipt)
                            'runtime-executed)
                  #f)
    (check-equal? (test-ref (test-ref runtime-handoff-facts
                                       'compression-receipt)
                            'runtime-executed)
                  #f)
    (check-equal? (test-field-values
                   (test-ref runtime-handoff-facts
                             'spec-evolution-human-audit-review-items)
                   'pattern)
                  (list expected-loop-engine-spec-evolution-proposal-id))
    (check-equal? (test-field-values
                   (test-ref runtime-handoff-facts
                             'spec-evolution-runtime-manifest-rows)
                   'eligible-for-checked-mutation)
                  '(#t))
    (check-equal? (test-ref (test-ref runtime-handoff-facts
                                       'session-agent-topology-trace)
                            'valid?)
                  #t)
    (check-equal? (test-field-values
                   (test-ref runtime-handoff-facts
                             'session-selector-receipts)
                   'selector-id)
                  '(selector/current-system-loop-router))
    (check-equal? (test-field-values
                   (test-ref runtime-handoff-facts
                             'session-materialization-receipts)
                   'session-ref)
                  '(current-system-build-session
                    current-system-recovery-session))
    (check-equal? (test-field-values
                   (test-ref runtime-handoff-facts
                             'spec-evolution-human-audit-review-items)
                   'decision)
                  '(approved))
    (check-equal? (test-field-values
                   (test-ref runtime-handoff-facts
                             'spec-evolution-runtime-manifest-rows)
                   'eligible-for-checked-mutation)
                  '(#t))
    (check-equal? (test-field-values
                   (test-ref runtime-handoff-facts
                             'spec-evolution-runtime-manifest-rows)
                   'runtime-executed)
                  '(#f))
    (check-equal? (test-ref sandbox-handoff-agreement 'contract)
                  'poo-flow.loop-engine.sandbox-handoff-agreement.v1)
    (check-equal? (test-ref sandbox-handoff-agreement 'handoff-ready?)
                  #f)
    (check-equal? (test-ref runtime-handoff-facts
                            'sandbox-unresolved-profile-refs)
                  '(ci/build))
    (check-equal? (test-ref runtime-handoff-facts 'descriptor-realized?)
                  #f)
    (check-equal? (test-ref runtime-handoff-facts 'runtime-executed)
                  #f)))

;;; Proof manifests are Scheme-side normalized obligations. Lean/AXLE can prove
;;; these small rows without modelling the full Gerbil control plane.
;; : (-> Alist Alist Alist)
(def (check-custom-loop-proof-manifest intent
                                       runtime-manifest
                                       runtime-manifest-request)
  (let* ((runtime-handoff-facts
          (test-ref intent 'runtime-handoff-facts))
         (proof-manifest
          (test-ref intent 'proof-manifest))
         (handoff-proof-manifest
          (test-ref runtime-handoff-facts 'proof-manifest)))
    (check-equal? proof-manifest handoff-proof-manifest)
    (check-equal? (test-ref proof-manifest 'kind)
                  'loop-engine-proof-manifest)
    (check-equal? (test-ref proof-manifest 'contract)
                  'poo-flow.loop-engine.proof-manifest.v1)
    (check-equal? (test-ref proof-manifest 'source)
                  'user-config-loop-engine)
    (check-equal? (test-ref proof-manifest 'proof-owner) 'lean)
    (check-equal? (test-ref proof-manifest 'proof-checker) 'axle)
    (check-equal? (test-ref proof-manifest 'runtime-owner)
                  "marlin-agent-core")
    (check-equal? (test-ref proof-manifest 'scheme-projection)
                  'poo-flow-user-loop-engine-intent-runtime-command-manifest)
    (check-equal? (test-ref proof-manifest 'proof-scope)
                  '(user-interface profile policy strategy workflow sandbox
                                   runtime-handoff))
    (check-equal? (test-ref proof-manifest 'request-id)
                  (test-ref runtime-manifest 'request-id))
    (check-equal? (test-ref proof-manifest 'artifact-handle)
                  (test-ref runtime-manifest 'artifact-handle))
    (check-equal? (test-ref proof-manifest 'runtime-command-contract)
                  (test-ref runtime-manifest-request 'contract))
    (check-equal? (test-ref proof-manifest 'object-families)
                  expected-loop-engine-object-families)
    (check-equal? (test-ref proof-manifest 'receipt-contracts)
                  expected-loop-engine-receipt-contracts)
    (check-equal? (test-ref proof-manifest 'runtime-packet-contracts)
                  expected-loop-engine-runtime-packet-contracts)
    (check-equal? (test-ref (test-ref proof-manifest 'c-abi)
                            'version)
                  1)
    (check-equal? (test-ref (test-ref proof-manifest 'c-abi)
                            'required-obligation-mask)
                  1023)
    (check-equal? (test-ref (test-ref proof-manifest 'c-abi)
                            'obligation-count)
                  10)
    (check-equal? (test-ref (test-ref proof-manifest 'c-abi)
                            'tag-width)
                  'uint32)
    (check-equal? (test-ref proof-manifest 'obligation-tags)
                  '((ui-config-well-formed . 1)
                    (ui-profile-policy-linked . 2)
                    (loop-strategy-plan-well-formed . 4)
                    (execution-policy-capability-bounded . 8)
                    (policy-strategy-deterministic . 16)
                    (runtime-command-inert . 32)
                    (workflow-agreement-linked . 64)
                    (sandbox-boundary-linked . 128)
                    (runtime-handoff-owner-linked . 256)
                    (proof-case-vector-complete . 512)))
    (check-equal? (test-field-values
                   (test-ref proof-manifest 'obligations)
                   'name)
                  '(ui-config-well-formed
                    ui-profile-policy-linked
                    loop-strategy-plan-well-formed
                    execution-policy-capability-bounded
                    runtime-command-inert
                    policy-strategy-deterministic
                    workflow-agreement-linked
                    sandbox-boundary-linked
                    runtime-handoff-owner-linked
                    proof-case-vector-complete))
    (check-equal? (test-ref proof-manifest 'lean-artifact-kind)
                  'theorem-stubs)
    (check-equal? (test-ref proof-manifest 'runtime-executed) #f)))

;;; Runtime manifest is the ABI handoff surface that Marlin can consume without
;;; guessing the loop-engine entrypoint or request shape.
;; : TestCase
(def (user-interface-custom-loop-engine-runtime-manifest-case)
  (poo-flow-test-case "projects custom loop-engine runtime manifest"
    (let* ((presentation
            (custom-loop-presentation
             poo-flow-custom-my-module-loop-engine-case))
           (intent
            (car (.ref presentation 'loop-engine-intents)))
           (runtime-manifest
            (test-ref intent 'runtime-command-manifest))
           (runtime-manifest-request
            (test-ref runtime-manifest 'request))
           (runtime-manifest-summary
            (test-ref intent 'runtime-command-manifest-summary)))
      (check-custom-loop-runtime-manifest-descriptor
       runtime-manifest
       runtime-manifest-summary)
      (check-custom-loop-runtime-manifest-discovery
       runtime-manifest
       runtime-manifest-request
       runtime-manifest-summary)
      (check-custom-loop-runtime-manifest-request-contracts
       runtime-manifest-request)
      (check-custom-loop-runtime-manifest-runtime-packets
       runtime-manifest-request)
      (check-custom-loop-runtime-manifest-request-receipts
       runtime-manifest-request)
      (check-custom-loop-runtime-manifest-request-graph
       runtime-manifest-request)
      (check-custom-loop-runtime-handoff-facts
       intent
       runtime-manifest-request)
      (check-custom-loop-proof-manifest
       intent
       runtime-manifest
       runtime-manifest-request)
      ;; Retained-memory contract: presentation, manifest, and handoff views
      ;; share the single materialized request graph instead of rebuilding
      ;; equal deep copies.
      (check-equal? (eq? (test-ref intent 'session-agent-graph)
                         (test-ref runtime-manifest-request
                                   'session-agent-graph))
                    #t)
      (check-equal? (eq? (test-ref intent 'runtime-snapshot)
                         (test-ref runtime-manifest-request
                                   'runtime-snapshot))
                    #t)
      (check-equal? (eq? (test-ref (test-ref intent
                                             'runtime-handoff-facts)
                                   'agent-profiles)
                         (test-ref runtime-manifest-request 'agent-profiles))
                    #t)
      (check-equal? (test-ref intent 'runtime-executed) #f))))

;;; The suite keeps ABI handoff assertions separate from profile projection so
;;; changes in Marlin-facing request shape are reviewed against their own case.
;; : TestSuite
(def user-interface-custom-loop-engine-runtime-manifest-test
  (test-suite "poo-flow custom loop-engine runtime manifest"
    (user-interface-custom-loop-engine-runtime-manifest-case)))
