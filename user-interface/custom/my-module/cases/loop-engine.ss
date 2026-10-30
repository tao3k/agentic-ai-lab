;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: standalone downstream loop-engine case module.
;;; Invariant: pure use-module declaration; runtime work stays in Marlin.

;;; This case configures one concrete loop handoff story: an agent proposes a
;;; CI/CD repair, peer agents judge it, and a human node reviews release risk.
;; : [PooUserModuleSelection]
(import :agentic-ai-lab/modules/loop-engine/config
        :agentic-ai-lab/modules/session/syntax
        (only-in :agentic-ai-lab/modules/loop-engine/control/spec-evolution
                 external-feedback-receipt-prototype
                 spec-change-proposal-prototype
                 spec-evolution-review-item-prototype))

(export agentic-ai-lab-custom-my-module-loop-engine-case)

(def agentic-ai-lab-custom-my-module-loop-engine-case
  (agentic-ai-lab-loop-engine-configs
  (.def (current-system-build-loop @ loop-engine-use-case
                                   name level mode workflow)
    name: 'current-system-build-loop
    level: 'l2
    mode: 'guarded-handoff
    workflow: 'funflow-cicd)

  (.def (current-system-recovery-loop @ loop-engine-use-case
                                      name level mode workflow)
    name: 'current-system-recovery-loop
    level: 'l2
    mode: 'recovery-handoff
    workflow: 'funflow-cicd)

  (.def (current-system-build-governor @ loop-engine-governor
                                       capabilities)
    capabilities: '(+strategy +policy +collision-check))

  (.def (current-system-build-judges @ loop-engine-agent-judges
                                     auditor verifier governor)
    auditor: 'ci-audit-agent
    verifier: 'build-verifier-agent
    governor: 'ci-loop-governor)

  (.def (current-system-build-human-audit @ loop-engine-human-audit
                                          actions)
    actions: '(+manual-gate +changes-requested))

  (.def (current-system-build-feedback @ external-feedback-receipt-prototype
                                       receipt-id source signals summary)
    receipt-id: 'feedback/current-system-build-sandbox-profile
    source: 'external-feedback-loop
    signals: '((source . alpha-user)
               (signal . sandbox-profile-risk)
               (requested-profile . ci/build))
    summary: "Developers need an audited path before changing the CI sandbox profile.")

  (.def (current-system-build-spec-proposal @ spec-change-proposal-prototype
                                            proposal-id target-kind target-ref
                                            change-kind summary
                                            feedback-receipts)
    proposal-id: 'sandbox-profile-human-audit-before-ci-change
    target-kind: 'profile
    target-ref: 'ci/build
    change-kind: 'require-human-audit-before-profile-change
    summary: "Require Human Audit before changing the CI sandbox profile."
    feedback-receipts: (list current-system-build-feedback))

  (.def (current-system-build-spec-review @ spec-evolution-review-item-prototype
                                          proposal decision)
    proposal: current-system-build-spec-proposal
    decision: 'approved)

  (.def (current-system-build-schedule @ loop-engine-schedule
                                       trigger cadence)
    trigger: 'manual
    cadence: 'on-demand)

  (.def (current-system-build-state @ loop-engine-state store path)
    store: 'file
    path: "loop-state/current-system-build.org")

  (.def (current-system-build-sandbox @ loop-engine-sandbox
                                      profile isolation)
    profile: 'ci/build
    isolation: 'project-copy)

  (.def (current-system-build-budget @ loop-engine-budget
                                     max-actionable max-attempts)
    max-actionable: 1
    max-attempts: 1)

  (.def (current-system-build-result @ loop-engine-result
                                     default auditor verifier governor
                                     human-audit format required-fields)
    default: 'agentic-ai-lab.loop-governor.node-result.v1
    auditor: 'agentic-ai-lab.loop-governor.audit-result.v1
    verifier: 'agentic-ai-lab.loop-governor.review-result.v1
    governor: 'agentic-ai-lab.loop-governor.governor-result.v1
    human-audit: 'agentic-ai-lab.loop-governor.human-audit-decision.v1
    format: 'structured-alist
    required-fields: '(decision summary evidence))

  (.def (current-system-build-observability @ loop-engine-observability
                                            receipt)
    receipt: 'l2-guarded-handoff)

  (.def (current-system-build-runtime @ loop-engine-runtime capabilities)
    capabilities: '(+manifest-handoff))

  (.def (current-system-build-lineage @ loop-engine-lineage-policy
                                      parent-session-refs lineage-kind
                                      lineage-operator journal export)
    parent-session-refs: '(incoming-ci-request-session)
    lineage-kind: 'guarded-handoff
    lineage-operator: 'current-system-build-loop
    journal: 'report-only
    export: 'jsonl)

  (.def (current-system-build-selector @ loop-engine-selector-policy
                                       candidates judge-inputs fallback
                                       selected-branch)
    candidates: '(current-system-build-loop current-system-recovery-loop)
    judge-inputs: '(ci-audit-agent build-verifier-agent ci-loop-governor)
    fallback: 'current-system-build-loop
    selected-branch: 'current-system-build-loop)

  (.def (current-system-build-resource-policy @ loop-engine-resource-policy
                                              tool-refs resource-keys
                                              collision-classes
                                              dispatch-groups)
    tool-refs: '(run-shell-command write-workspace-file read-workspace-file)
    resource-keys: '((run-shell-command . exec)
                     (write-workspace-file . (fs:write build-log))
                     (read-workspace-file . (fs:read build-log)))
    collision-classes: '((exec . serial)
                         ((fs:write build-log) . serial)
                         ((fs:read build-log) . parallel))
    dispatch-groups: '(((run-shell-command) . serial)
                       ((write-workspace-file read-workspace-file) . serial)))

  (.def (current-system-build-capability-policy
         @ loop-engine-capability-policy
         backend isolation required optional unsupported-behavior)
    backend: 'nono
    isolation: 'project-copy
    required: '(command-run files-read files-write)
    optional: '(stream-events code-run)
    unsupported-behavior: 'handoff-diagnostic)

  (.def (current-system-build-memory-policy @ loop-engine-memory-policy
                                            use-case store state-path scope
                                            recall commit ranking retention)
    use-case: 'current-system-build-loop
    store: 'project-memory
    state-path: "loop-state/current-system-build.org"
    scope: 'session
    recall: '(last-user-message build-context prior-failure)
    commit: '(decision-summary evidence-index handoff-receipt)
    ranking: 'recency
    retention: 'report-only)

  (.def (current-system-recovery-memory-policy @ loop-engine-memory-policy
                                               use-case store state-path
                                               scope recall commit ranking
                                               retention)
    use-case: 'current-system-recovery-loop
    store: 'project-memory
    state-path: "loop-state/current-system-recovery.org"
    scope: 'recovery-session
    recall: '(last-good-build failed-commands verifier-notes)
    commit: '(recovery-plan retry-boundary human-escalation)
    ranking: 'risk-first
    retention: 'report-only)

  (.def (current-system-build-compression-policy
         @ loop-engine-compression-policy
         strategy trigger summary-format lineage-kind retention)
    strategy: 'handoff-summary
    trigger: 'after-human-audit
    summary-format: 'structured-alist
    lineage-kind: 'compressed-ci-session
    retention: 'report-only)

  (.def (current-system-build-profile @ loop-engine-profile
                                      use-case use-cases governor agent-judges
                                      human-audit schedule state sandbox budget
                                      result observability runtime
                                      lineage-policy selector-policy
                                      resource-policy capability-policy
                                      memory-policies compression-policy
                                      spec-evolution-review-items
                                      session-selector-receipts
                                      session-materialization-receipts)
    use-case: current-system-build-loop
    use-cases: (list current-system-recovery-loop)
    governor: current-system-build-governor
    agent-judges: current-system-build-judges
    human-audit: current-system-build-human-audit
    schedule: current-system-build-schedule
    state: current-system-build-state
    sandbox: current-system-build-sandbox
    budget: current-system-build-budget
    result: current-system-build-result
    observability: current-system-build-observability
    runtime: current-system-build-runtime
    lineage-policy: current-system-build-lineage
    selector-policy: current-system-build-selector
    resource-policy: current-system-build-resource-policy
    capability-policy: current-system-build-capability-policy
    memory-policies: (list current-system-build-memory-policy
                           current-system-recovery-memory-policy)
    compression-policy: current-system-build-compression-policy
    spec-evolution-review-items: (list current-system-build-spec-review)
    session-selector-receipts:
    (list
     (agentic-ai-lab-session-selector-receipt
      'selector/current-system-loop-router
      'custom/project
      'incoming-ci-request-session
      'incoming-ci-request-session
      (list
       (agentic-ai-lab-session-selector-candidate
        'candidate/current-build
        'workflow
        'workflow/current-system-build
        "Continue the current CI build loop."
        '(runtime-handoff build-context)
        '((source . loop-engine)
          (use-case . current-system-build-loop)))
       (agentic-ai-lab-session-selector-candidate
        'candidate/current-recovery
        'transform
        'transform/current-system-recovery
        "Derive a recovery session from the failing build state."
        '(prior-failure verifier-notes)
        '((source . loop-engine)
          (use-case . current-system-recovery-loop))))
      '((strategy . policy-first)
        (selected-branch . current-system-build-loop)
        (result-contract . workflow-or-transform-ref))
      'candidate/current-build
      '((source . loop-engine)
        (case . current-system-build))))
    session-materialization-receipts:
    (list
     (agentic-ai-lab-session-runtime-materialization-receipt
      'runtime/current-system-build-request
      'custom/project
      'incoming-ci-request-session
      'current-system-build-session
      '(incoming-ci-request-session)
      'pending
      'runtime/current-system-build-future
      'sandbox/current-system-build
      '()
      #f
      '((source . loop-engine)
        (use-case . current-system-build-loop)))
     (agentic-ai-lab-session-runtime-materialization-receipt
      'runtime/current-system-recovery-request
      'custom/project
      'incoming-ci-request-session
      'current-system-recovery-session
      '(incoming-ci-request-session current-system-build-session)
      'pending
      'runtime/current-system-recovery-future
      'sandbox/current-system-recovery
      '()
      #f
      '((source . loop-engine)
        (use-case . current-system-recovery-loop)))))
))
