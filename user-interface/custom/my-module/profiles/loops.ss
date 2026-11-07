;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream loop-engine profile declarations.
;;; Invariant: standalone module; it declares workflow loop intent only.

(import :agentic-ai-lab/modules/loop-engine/config)

(export agentic-ai-lab-custom-my-module-loops-module)

(def agentic-ai-lab-custom-my-module-loops-module
  (agentic-ai-lab-loop-engine-configs
  (.def (daily-triage-loop @ loop-engine-use-case
                           name level mode goal)
    name: 'daily-triage
    level: 'l1
    mode: 'report-only
    goal: 'prioritize-repo-attention)

  (.def (ci-sweeper-loop @ loop-engine-use-case
                         name level mode goal)
    name: 'ci-sweeper
    level: 'l2
    mode: 'assisted-worktree-fix
    goal: 'classify-and-handoff-ci-failures)

  (.def (issue-triage-loop @ loop-engine-use-case
                           name level mode goal)
    name: 'issue-triage
    level: 'l1
    mode: 'proposal-only
    goal: 'prioritize-and-label-issues)

  (.def (dependency-sweeper-loop @ loop-engine-use-case
                                 name level mode goal)
    name: 'dependency-sweeper
    level: 'l2
    mode: 'patch-only-human-gated
    goal: 'watch-manifests-and-lockfiles)

  (.def (post-merge-cleanup-loop @ loop-engine-use-case
                                 name level mode goal)
    name: 'post-merge-cleanup
    level: 'l1
    mode: 'report-only
    goal: 'track-small-cleanup-after-merges)

  (.def (repo-loop-governor-config @ loop-engine-governor capabilities)
    capabilities: '(+strategy +policy +node-graph))

  (.def (repo-loop-judges @ loop-engine-agent-judges
                          auditor verifier governor)
    auditor: 'repo-audit-agent
    verifier: 'repo-verifier-agent
    governor: 'repo-governor)

  (.def (repo-loop-human-audit @ loop-engine-human-audit actions)
    actions: '(+approval +rejection +changes-requested))

  (.def (repo-loop-result @ loop-engine-result
                          default auditor verifier governor human-audit
                          format required-fields)
    default: 'agentic-ai-lab.loop-governor.profile-node-result.v1
    auditor: 'agentic-ai-lab.loop-governor.profile-audit-result.v1
    verifier: 'agentic-ai-lab.loop-governor.profile-review-result.v1
    governor: 'agentic-ai-lab.loop-governor.profile-governor-result.v1
    human-audit: 'agentic-ai-lab.loop-governor.profile-human-audit-decision.v1
    format: 'structured-alist
    required-fields: '(decision summary evidence action-items))

  (.def (repo-loop-schedule @ loop-engine-schedule entries)
    entries: '((daily-triage . daily)
               (ci-sweeper . workflow-run-failure)
               (issue-triage . issues-or-2h)
               (dependency-sweeper . six-hourly)
               (post-merge-cleanup . post-merge-or-daily)))

  (.def (repo-loop-state @ loop-engine-state store path acting-on)
    store: 'file
    path: "loop-state/custom-my-module.org"
    acting-on: 'project-workspace)

  (.def (repo-loop-sandbox @ loop-engine-sandbox case-profile-refs)
    case-profile-refs: '((daily-triage . agent/task)
                         (ci-sweeper . ci/build)
                         (issue-triage . agent/task)
                         (dependency-sweeper . agent/task-cache)
                         (post-merge-cleanup . agent/task)))

  (.def (repo-loop-budget @ loop-engine-budget
                          max-actionable max-attempts weekly-runs)
    max-actionable: 1
    max-attempts: 2
    weekly-runs: 20)

  (.def (repo-loop-observability @ loop-engine-observability
                                 receipt run-log)
    receipt: 'loop-engine-intent
    run-log: "loop-run-log/custom-my-module.org")

  (.def (repo-loop-runtime @ loop-engine-runtime capabilities)
    capabilities: '(+manifest-handoff +l1-receipts))

  (.def (repo-loop-lineage @ loop-engine-lineage-policy
                           parent-session-refs lineage-kind
                           lineage-operator journal export)
    parent-session-refs: '(repo-root-session)
    lineage-kind: 'profile-loop
    lineage-operator: 'repo-loop-profile
    journal: 'report-only
    export: 'jsonl)

  (.def (repo-loop-selector @ loop-engine-selector-policy
                            candidates judge-inputs fallback selected-branch)
    candidates: '(daily-triage
                  ci-sweeper
                  issue-triage
                  dependency-sweeper
                  post-merge-cleanup)
    judge-inputs: '(repo-audit-agent repo-verifier-agent repo-governor)
    fallback: 'daily-triage
    selected-branch: 'daily-triage)

  (.def (repo-loop-resource-policy @ loop-engine-resource-policy
                                   tool-refs resource-keys
                                   collision-classes dispatch-groups)
    tool-refs: '(inspect-policy run-harness write-report)
    resource-keys: '((inspect-policy . repo-state)
                     (run-harness . exec)
                     (write-report . repo-state))
    collision-classes: '((repo-state . serial)
                         (exec . serial))
    dispatch-groups: '(((inspect-policy write-report) . serial)
                       ((run-harness) . serial)))

  (.def (repo-loop-capability-policy @ loop-engine-capability-policy
                                     backend isolation required optional
                                     unsupported-behavior)
    backend: 'cube-sandbox
    isolation: 'profile-selected
    required: '(command-run files-read files-write)
    optional: '(stream-events memory-recall compression-handoff)
    unsupported-behavior: 'report-only-warning)

  (.def (daily-triage-memory @ loop-engine-memory-policy
                             use-case store state-path scope recall commit
                             ranking retention)
    use-case: 'daily-triage
    store: 'state-file
    state-path: "STATE.md"
    scope: 'project-day
    recall: '(state-spine ci-summary issue-summary prior-high-priority
              human-overrides)
    commit: '(last-run high-priority watch-list recent-noise human-overrides)
    ranking: 'priority
    retention: 'rolling-report)

  (.def (ci-sweeper-memory @ loop-engine-memory-policy
                           use-case store state-path scope recall commit
                           ranking retention)
    use-case: 'ci-sweeper
    store: 'state-file
    state-path: "ci-sweeper-state.md"
    scope: 'branch-failure
    recall: '(ci-status failing-job flake-history attempt-count
              branch-allowlist)
    commit: '(failure-classification attempt-count worktree-ref
              verifier-result escalation-reason)
    ranking: 'risk-first
    retention: 'last-seven-days)

  (.def (issue-triage-memory @ loop-engine-memory-policy
                             use-case store state-path scope recall commit
                             ranking retention)
    use-case: 'issue-triage
    store: 'state-file
    state-path: "issue-triage-state.md"
    scope: 'issue-backlog
    recall: '(open-issues prior-top-five label-policy possible-duplicates
              human-overrides)
    commit: '(top-five proposed-labels possible-duplicates needs-human
              ignored-noise)
    ranking: 'loop-score
    retention: 'rolling-backlog)

  (.def (dependency-sweeper-memory @ loop-engine-memory-policy
                                   use-case store state-path scope recall
                                   commit ranking retention)
    use-case: 'dependency-sweeper
    store: 'state-file
    state-path: "dependency-sweeper-state.md"
    scope: 'manifest-watch
    recall: '(watched-manifests lockfile-drift denylist-packages
              human-overrides)
    commit: '(in-flight-updates denylist-decisions verifier-result
              escalation-reason)
    ranking: 'patch-safety
    retention: 'sprint-scoped)

  (.def (post-merge-cleanup-memory @ loop-engine-memory-policy
                                   use-case store state-path scope recall
                                   commit ranking retention)
    use-case: 'post-merge-cleanup
    store: 'state-file
    state-path: "post-merge-state.md"
    scope: 'recent-merges
    recall: '(recent-merges pending-cleanup denylist-paths
              deferred-decisions)
    commit: '(pending-cleanup completed-cleanup deferred-human-decisions)
    ranking: 'cleanup-risk
    retention: 'last-fourteen-days)

  (.def (repo-loop-compression-policy @ loop-engine-compression-policy
                                      strategy trigger summary-format
                                      lineage-kind retention)
    strategy: 'session-summary
    trigger: 'before-release-approval
    summary-format: 'structured-alist
    lineage-kind: 'compressed-profile-loop
    retention: 'profile-scoped)

  (.def (repo-loop-coordination @ loop-engine-coordination-policy-extension
                                name scope priority state-files acting-on-key
                                conflict-action branch-lock-scope human-inbox)
    name: 'repo-loop-coordination
    scope: 'profile
    priority: '(ci-sweeper
                dependency-sweeper
                post-merge-cleanup
                issue-triage
                daily-triage)
    state-files: '((daily-triage . "STATE.md")
                   (ci-sweeper . "ci-sweeper-state.md")
                   (issue-triage . "issue-triage-state.md")
                   (dependency-sweeper . "dependency-sweeper-state.md")
                   (post-merge-cleanup . "post-merge-state.md"))
    acting-on-key: 'acting_on
    conflict-action: 'skip-and-log
    branch-lock-scope: 'branch-or-pr
    human-inbox: "STATE.md#Human Inbox")

  (.def (repo-loop-observability-policy
         @ loop-engine-observability-policy-extension
         name scope run-log run-log-schema budget-path metric-keys
         retention-window slow-signals pause-signals kill-signals)
    name: 'repo-loop-observability
    scope: 'profile
    run-log: "loop-run-log.md"
    run-log-schema: '((run_id . symbol)
                      (pattern . symbol)
                      (duration_s . integer)
                      (items_found . integer)
                      (actions_taken . integer)
                      (escalations . integer)
                      (tokens_estimate . integer)
                      (outcome . symbol))
    budget-path: "STATE.md#Loop Budget"
    metric-keys: '(duration_s items_found actions_taken escalations
                   tokens_estimate outcome)
    retention-window: 'rolling-fourteen-days
    slow-signals: '(budget-over-80 repeated-false-positive)
    pause-signals: '(main-red reviewer-absence repeated-escalation)
    kill-signals: '(incident cost-exceeds-value))

  (.def (repo-loop-safety-policy @ loop-engine-safety-policy-extension
                                 name scope denylist-paths allowlist-paths
                                 human-gates connector-scopes auto-merge
                                 max-attempts)
    name: 'repo-loop-safety
    scope: 'profile
    denylist-paths: '(".env"
                      ".env.local"
                      "secrets/"
                      ".github/workflows/release.yml")
    allowlist-paths: '("src/"
                       "t/"
                       "docs/"
                       "user-interface/")
    human-gates: '(red-ci-handoff release-risk secrets-touch
                   protected-branch)
    connector-scopes: '(issues-read pull-requests-read actions-read)
    auto-merge: 'never
    max-attempts: 2)

  (.def (repo-loop-profile @ loop-engine-profile
                           use-cases governor agent-judges human-audit
                           result schedule state sandbox budget
                           observability runtime lineage-policy
                           selector-policy resource-policy
                           capability-policy memory-policies
                           compression-policy policy-extensions)
    use-cases: (list daily-triage-loop
                     ci-sweeper-loop
                     issue-triage-loop
                     dependency-sweeper-loop
                     post-merge-cleanup-loop)
    governor: repo-loop-governor-config
    agent-judges: repo-loop-judges
    human-audit: repo-loop-human-audit
    result: repo-loop-result
    schedule: repo-loop-schedule
    state: repo-loop-state
    sandbox: repo-loop-sandbox
    budget: repo-loop-budget
    observability: repo-loop-observability
    runtime: repo-loop-runtime
    lineage-policy: repo-loop-lineage
    selector-policy: repo-loop-selector
    resource-policy: repo-loop-resource-policy
    capability-policy: repo-loop-capability-policy
    memory-policies: (list daily-triage-memory
                           ci-sweeper-memory
                           issue-triage-memory
                           dependency-sweeper-memory
                           post-merge-cleanup-memory)
    compression-policy: repo-loop-compression-policy
    policy-extensions: (list repo-loop-coordination
                             repo-loop-observability-policy
                             repo-loop-safety-policy))))
