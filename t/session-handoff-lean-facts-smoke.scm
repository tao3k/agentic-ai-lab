;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: smoke validates Lean fact projection tables, not runtime behavior.
;;; Invariant: Scheme manufactures proof facts only; runtime execution stays
;;; behind the Marlin handoff boundary.
(import (only-in :clan/poo/object .o)
        :agentic-ai-lab/modules/loop-engine/session-agent-graph
        :agentic-ai-lab/modules/session/objects-handoff)

;; : (-> Alist Symbol Object)
(def (fact-ref facts key)
  (let ((cell (assq key facts)))
    (and cell (cdr cell))))

;; : (-> Object Object String Void)
(def (check-equal! actual expected label)
  (unless (equal? actual expected)
    (error "check failed" label actual expected)))

;; : (-> Alist Symbol Object Symbol Void)
(def (check-fact! facts key expected label)
  (check-equal! (fact-ref facts key) expected label))

;; : (-> Alist [List] Void)
(def (check-facts! facts expected-facts)
  (for-each
   (lambda (entry)
     (check-fact! facts (car entry) (cadr entry) (caddr entry)))
   expected-facts))

;; : (-> Alist Alist String Void)
(def (check-lean-fact-contract! contracts facts label)
  (check-equal!
   (agentic-ai-lab-lean-fact-contract-complete? contracts facts)
   #t
   label))

;; : (-> Void)
(def (check-static-handoff-boundary!)
  (let* ((handoff
          (.o kind: 'agentic-ai-lab.session.handoff
              schema: 'agentic-ai-lab.session.handoff.v1
              source: 'agentic-ai-lab-session-presentation
              session-id: "session-1"
              chunk-count: 2
              placement-profile-ref: "profile/default"
              placement-resolved?: #t
              placement-diagnostics: '()
              runtime-owner: "marlin-agent-core"
              handoff-required: #t
              runtime-executed: #f
              runtime-parses-scheme-source: #f
              scheme-manufactures-runtime-handlers: #f
              metadata: (agentic-ai-lab-session-topology->handoff-metadata
                         (.o agent-registered?: #t
                             subagent-registered?: #t
                             channel-authorized?: #t))))
         (facts (agentic-ai-lab-session-handoff->lean-facts handoff)))
    (check-lean-fact-contract!
     agentic-ai-lab-session-handoff-lean-fact-key-contracts
     facts
     'session-handoff-lean-fact-contract)
    (check-facts!
     facts
     '((session.lifecycle/chunk-present #t chunk-present)
       (session.lifecycle/placement-resolved #t placement-resolved)
       (session.lifecycle/placement-missing-profile #f
        placement-missing-profile)
       (session.lifecycle/runtime-summary-present #t
        runtime-summary-present)
       (session.lifecycle/handoff-receipt-present #t
        handoff-receipt-present)
       (session.lifecycle/runtime-executed-false #t
        runtime-executed-false)
       (session.lifecycle/handoff-required-true #t
        handoff-required-true)
       (session.lifecycle/runtime-owner-marlin #t runtime-owner-marlin)
       (session.lifecycle/runtime-parses-scheme-source-false #t
        runtime-parses-scheme-source-false)
       (session.lifecycle/scheme-manufactures-runtime-handlers-false #t
        scheme-manufactures-runtime-handlers-false)
       (scenario.bridge/s3-handoff-receipt #t
        scenario-bridge-s3-handoff-receipt)
       (scenario.bridge/s11-agent-registered #t
        scenario-bridge-s11-agent-registered)
       (scenario.bridge/s11-subagent-registered #t
        scenario-bridge-s11-subagent-registered)
       (scenario.bridge/s11-channel-authorized #t
        scenario-bridge-s11-channel-authorized)
       (scenario.bridge/s14-placement-missing-profile #f
        scenario-bridge-s14-placement-missing-profile)))))

;; : (-> Void)
(def (check-missing-profile-diagnostics!)
  (let* ((handoff
          (.o kind: 'agentic-ai-lab.session.handoff
              schema: 'agentic-ai-lab.session.handoff.v1
              source: 'agentic-ai-lab-session-presentation
              session-id: "session-2"
              chunk-count: 1
              placement-profile-ref: #f
              placement-resolved?: #f
              placement-diagnostics: '(missing-profile)
              runtime-owner: "marlin-agent-core"
              handoff-required: #t
              runtime-executed: #f
              runtime-parses-scheme-source: #f
              scheme-manufactures-runtime-handlers: #f
              metadata: '()))
         (facts (agentic-ai-lab-session-handoff->lean-facts handoff)))
    (check-lean-fact-contract!
     agentic-ai-lab-session-handoff-lean-fact-key-contracts
     facts
     'missing-profile-lean-fact-contract)
    (check-facts!
     facts
     '((session.lifecycle/placement-resolved #f
        missing-profile-placement-resolved)
       (session.lifecycle/placement-missing-profile #t
        missing-profile-diagnostic)
       (scenario.bridge/s14-placement-missing-profile #t
        scenario-bridge-missing-profile)))))

;; : (-> Void)
(def (check-topology-channel-denial!)
  (let* ((handoff
          (.o kind: 'agentic-ai-lab.session.handoff
              schema: 'agentic-ai-lab.session.handoff.v1
              source: 'agentic-ai-lab-session-presentation
              session-id: "session-3"
              chunk-count: 1
              placement-profile-ref: "profile/default"
              placement-resolved?: #t
              placement-diagnostics: '()
              runtime-owner: "marlin-agent-core"
              handoff-required: #t
              runtime-executed: #f
              runtime-parses-scheme-source: #f
              scheme-manufactures-runtime-handlers: #f
              metadata: (agentic-ai-lab-session-topology->handoff-metadata
                         (.o agent-registered?: #t
                             subagent-registered?: #t
                             channel-authorized?: #f))))
         (facts (agentic-ai-lab-session-handoff->lean-facts handoff)))
    (check-lean-fact-contract!
     agentic-ai-lab-session-handoff-lean-fact-key-contracts
     facts
     'topology-denial-lean-fact-contract)
    (check-facts!
     facts
     '((scenario.bridge/s11-agent-registered #t
        topology-denial-agent-registered)
       (scenario.bridge/s11-subagent-registered #t
        topology-denial-subagent-registered)
       (scenario.bridge/s11-channel-authorized #f
        topology-denial-channel-authorized)))))

;; : (-> Void)
(def (check-ui-scenario-lean-facts!)
  (let* ((facts
          (agentic-ai-lab-ui-scenario->lean-facts
           (.o use-case-declared?: #t
               profile-declared?: #t
               governor-configured?: #t
               lineage-policy-done?: #t
               selector-policy-done?: #t
               resource-policy-done?: #t
               capability-policy-done?: #t
               memory-policy-done?: #t
               compression-policy-done?: #t
               strategy-plan-done?: #t
               local-validation-done?: #t
               runtime-manifest-done?: #t
               marlin-handoff-done?: #t
               l1-report-done?: #t
               scenario-matrix-done?: #t
               scenario-benchmark-done?: #t
               performance-fixture-bound?: #t))))
    (check-lean-fact-contract!
     agentic-ai-lab-ui-scenario-lean-fact-key-contracts
     facts
     'ui-scenario-lean-fact-contract)
    (check-facts!
     facts
     '((ui.scenario/strategy-plan-done #t
        ui-scenario-strategy-plan-done)
       (ui.scenario/runtime-manifest-done #t
        ui-scenario-runtime-manifest-done)
       (ui.scenario/scenario-benchmark-done #t
        ui-scenario-benchmark-done)
       (ui.failure/runtime-manifest-missing-memory-policy #f
        ui-scenario-runtime-memory-not-missing)
       (ui.failure/benchmark-missing-performance-fixture #f
        ui-scenario-fixture-not-missing)))))

;; : (-> Void)
(def (check-ui-scenario-denial-lean-facts!)
  (let* ((facts
          (agentic-ai-lab-ui-scenario->lean-facts
           (.o use-case-declared?: #t
               profile-declared?: #t
               governor-configured?: #t
               lineage-policy-done?: #t
               selector-policy-done?: #f
               resource-policy-done?: #t
               capability-policy-done?: #t
               memory-policy-done?: #f
               compression-policy-done?: #f
               strategy-plan-done?: #f
               local-validation-done?: #f
               runtime-manifest-done?: #f
               marlin-handoff-done?: #f
               l1-report-done?: #f
               scenario-matrix-done?: #f
               scenario-benchmark-done?: #f
               performance-fixture-bound?: #f))))
    (check-lean-fact-contract!
     agentic-ai-lab-ui-scenario-lean-fact-key-contracts
     facts
     'ui-denial-lean-fact-contract)
    (check-facts!
     facts
     '((ui.scenario/selector-policy-done #f
        ui-denial-selector-policy-done)
       (ui.failure/strategy-missing-selector-policy #t
        ui-denial-strategy-missing-selector)
       (ui.failure/runtime-manifest-missing-memory-policy #t
        ui-denial-runtime-missing-memory)
       (ui.failure/runtime-manifest-missing-compression-policy #t
        ui-denial-runtime-missing-compression)
       (ui.failure/handoff-missing-runtime-manifest #t
        ui-denial-handoff-missing-runtime)
       (ui.failure/benchmark-missing-performance-fixture #t
        ui-denial-benchmark-missing-fixture)))))

;; : (-> Void)
(def (check-loop-engine-agent-graph-topology-metadata!)
  (let* ((graph
         (agentic-ai-lab-user-loop-engine-intent-session-agent-graph
          '((use-case . s11-agent-topology)
            (agent-judges . ((planner . planner-agent)
                             (builder . builder-agent))))))
         (metadata (fact-ref graph 'metadata)))
    (check-facts!
     metadata
     '((agent-registered #t loop-engine-agent-registered)
       (subagent-registered #t loop-engine-subagent-registered)
       (channel-authorized #t loop-engine-channel-authorized)))
    (check-fact! graph
                 'communication-channel-receipt-count
                 2
                 'loop-engine-channel-receipt-count)))

(check-static-handoff-boundary!)
(check-missing-profile-diagnostics!)
(check-topology-channel-denial!)
(check-ui-scenario-lean-facts!)
(check-ui-scenario-denial-lean-facts!)
(check-loop-engine-agent-graph-topology-metadata!)
