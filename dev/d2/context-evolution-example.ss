;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Illustrative admitted inputs, not authenticated real-world evidence.
(export context-evolution-example)
(def (context-evolution-example)
  (.o
    windows:
    (list (.o (:: @ ExperienceWindow.) identity: 'early label: "Earlier view\nknown by t=15" revision: 'r1 scope: 'project
              start: 0 end: 20 as-of: 15)
          (.o (:: @ ExperienceWindow.) identity: 'later label: "Later view\nknown by t=40" revision: 'r1 scope: 'project
              start: 0 end: 40 as-of: 40))
    observations:
    (list (.o identity: 'clean-run label: "Clean rebuild passed\nobserved at t=10" scope: 'project event-time: 10 known-time: 10 cut: 'source-v1)
          ;; It happened inside the first interval, but was not yet known.
          (.o identity: 'counterexample label: "Control run still failed\narrived at t=30" scope: 'project event-time: 12 known-time: 30 cut: 'source-v1))
    current-cuts: (list (.o scope: 'project cut: 'source-v1))
    hypotheses:
    (list (.o identity: 'stale-inputs label: "Stale generated inputs?" scope: 'project)
          (.o identity: 'compiler-abi label: "Compiler / ABI mismatch?" scope: 'project))
    supports:
    (list (.o evidence: 'clean-run hypothesis: 'stale-inputs)
          (.o evidence: 'counterexample hypothesis: 'compiler-abi))
    contradicts: (list (.o evidence: 'counterexample hypothesis: 'stale-inputs))
    dependencies:
    (list (.o subject: 'diagnosis premise: 'clean-run)
          (.o subject: 'diagnostic-method premise: 'diagnosis))
    changes: '()
    proposals: (list (.o identity: 'diagnostic-method label: "Proposed diagnostic method" hypothesis: 'stale-inputs scope: 'project))
    requirements: (list (.o proposal: 'diagnostic-method requirement: 'scoped-control))
    meets: (list (.o evidence: 'clean-run proposal: 'diagnostic-method requirement: 'scoped-control))
    complete-inventories: (list (.o proposal: 'diagnostic-method))
    scope-checks: (list (.o proposal: 'diagnostic-method scope: 'project))))
