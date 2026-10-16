;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        (only-in :clan/poo/object .ref)
        (only-in :core/graph/types
                 poo-flow-graph poo-flow-graph-edge poo-flow-graph-node)
        :poo-flow/modules/temporal-causality/interface)

(export temporal-causality-core-test)

(def temporal-causality-core-test
  (test-suite
   "Temporal Causality core"

   (poo-flow-test-case "structural Impact returns relation trajectory witnesses"
     (let* ((graph
             (poo-flow-graph
              'medication-change
              (list (poo-flow-graph-node 'case)
                    (poo-flow-graph-node 'profile)
                    (poo-flow-graph-node 'source)
                    (poo-flow-graph-node 'unrelated))
              (list (poo-flow-graph-edge
                     'case 'profile 'HAS_EFFECTIVE_PROFILE)
                    (poo-flow-graph-edge
                     'profile 'source 'DECLARES_SOURCE))))
            (receipt
             (poo-flow-structural-impact-analyze
              graph
              '(source)
              '(HAS_EFFECTIVE_PROFILE DECLARES_SOURCE)
              'dependents
              #t))
            (case-witness
             (car
              (filter
               (lambda (witness)
                 (eq? (.ref witness 'target-node-id) 'case))
               (.ref receipt 'relation-trajectories)))))
       (check (poo-flow-structural-impact-receipt? receipt) => #t)
       (check (.ref receipt 'status) => 'snapshot-scoped-impact)
       (check (.ref receipt 'affected-node-ids)
              => '(source profile case))
       (check (.ref case-witness 'node-path)
              => '(source profile case))
       (check (.ref case-witness 'relation-path)
              => '(DECLARES_SOURCE HAS_EFFECTIVE_PROFILE))
       (check (.ref receipt 'temporal-impact-assessed?) => #f)
       (check (.ref receipt 'release-authorized?) => #f)))

   (poo-flow-test-case "incomplete inventory cannot claim scoped completeness"
     (let* ((graph
             (poo-flow-graph
              'partial
              (list (poo-flow-graph-node 'changed))
              '()))
            (receipt
             (poo-flow-structural-impact-analyze
              graph '(changed) '(dependency) 'dependents #f)))
       (check (.ref receipt 'status) => 'partial-impact)))

   (poo-flow-test-case "structural Impact terminates on relation cycles"
     (let* ((graph
             (poo-flow-graph
              'cyclic-software-structure
              (list (poo-flow-graph-node 'requirement)
                    (poo-flow-graph-node 'verification))
              (list (poo-flow-graph-edge
                     'requirement 'verification 'VERIFIES)
                    (poo-flow-graph-edge
                     'verification 'requirement 'TRACES_BACK))))
            (receipt
             (poo-flow-structural-impact-analyze
              graph '(requirement) '(VERIFIES TRACES_BACK)
              'dependencies #t)))
       (check (.ref receipt 'status) => 'snapshot-scoped-impact)
       (check (.ref receipt 'affected-node-ids)
              => '(requirement verification))
       (check (length (.ref receipt 'relation-trajectories)) => 2)))

   (poo-flow-test-case "causal cut classifies bounded past present and future"
     (let* ((subject "patient-1")
            (event
             (lambda (identity kind position parents modality committed?)
               (poo-flow-causal-event
                identity subject kind
                (poo-flow-temporal-observation
                 (string-append identity "/observation")
                 'logical-version position "clinical-ledger")
                (string-append identity "/payload")
                parents modality committed?)))
            (prescription
             (event "prescription-1" 'prescription 1 '() 'observed #t))
            (administration
             (event "administration-1" 'administration 2
                    '("prescription-1") 'observed #t))
            (observation
             (event "observation-1" 'clinical-observation 3
                    '("administration-1") 'observed #t))
            (discovery
             (event "error-discovery-1" 'prescription-error-discovered 4
                    '("observation-1") 'observed #t))
            (future-dose
             (event "scheduled-dose-2" 'scheduled-administration 5
                    '("prescription-1") 'declared #f))
            (counterfactual
             (event "corrected-prescription-1" 'corrected-prescription 5
                    '("error-discovery-1") 'counterfactual #f))
            (outside
             (event "follow-up-1" 'follow-up 9
                    '("error-discovery-1") 'declared #f))
            (event-graph
             (poo-flow-causal-event-graph
              subject
              (list prescription administration observation discovery
                    future-dose counterfactual outside)))
            (cut (poo-flow-causal-cut event-graph 4))
            (receipt
             (poo-flow-temporal-causal-classify
              event-graph cut "prescription-1" 6)))
       (check (poo-flow-causal-event-graph? event-graph) => #t)
       (check (poo-flow-causal-cut? cut) => #t)
       (check (.ref cut 'complete?) => #t)
       (check (map (lambda (event) (.ref event 'identity))
                   (.ref cut 'events))
              => '("prescription-1" "administration-1"
                   "observation-1" "error-discovery-1"))
       (check (poo-flow-temporal-classification-receipt? receipt) => #t)
       (check (.ref receipt 'status) => 'bounded-temporal-classification)
       (check (.ref receipt 'past-event-ids)
              => '("prescription-1" "administration-1" "observation-1"))
       (check (.ref receipt 'current-event-ids)
              => '("error-discovery-1"))
       (check (.ref receipt 'future-event-ids)
              => '("scheduled-dose-2"))
       (check (.ref receipt 'hypothesized-event-ids) => '())
       (check (.ref receipt 'counterfactual-event-ids)
              => '("corrected-prescription-1"))
       (check (.ref receipt 'outside-horizon-event-ids)
              => '("follow-up-1"))
       (check (.ref receipt 'unknown-frontier) => '())
       (check (.ref receipt 'assurance-closed?) => #f)
       (check (.ref receipt 'release-authorized?) => #f)))

   (poo-flow-test-case "trajectory contract separates intended error and Impact layers"
     (let* ((subject "patient-1")
            (event
             (lambda (identity position parents modality committed?)
               (poo-flow-causal-event
                identity subject 'clinical-event
                (poo-flow-temporal-observation
                 (string-append identity "/time")
                 'logical-version position "clinical-ledger")
                (string-append identity "/payload")
                parents modality committed?)))
            (events
             (list
              (event "request" 1 '() 'observed #t)
              (event "evidence" 2 '("request") 'observed #t)
              (event "hold" 3 '("evidence") 'observed #t)
              (event "review" 4 '("hold") 'observed #t)
              (event "ready" 5 '("review") 'declared #f)
              (event "auto-approval" 3 '("evidence") 'counterfactual #f)
              (event "wrong-effect" 4 '("auto-approval")
                     'counterfactual #f)
              (event "benefit" 6 '("ready") 'hypothesized #f)
              (event "harm" 5 '("wrong-effect") 'hypothesized #f)))
            (event-graph (poo-flow-causal-event-graph subject events))
            (contract
             (poo-flow-causal-trajectory-contract
              "clinical-safety" "request"
              '("evidence" "hold" "review" "ready")
              '(("auto-approval" "wrong-effect"))
              '("benefit") '("harm")))
            (assessment
             (poo-flow-causal-trajectory-assess contract event-graph)))
       (check (poo-flow-causal-trajectory-contract? contract) => #t)
       (check (poo-flow-causal-trajectory-assessment? assessment) => #t)
       (check (.ref assessment 'status) => 'causal-trajectory-admitted)
       (check (.ref assessment 'accepted?) => #t)
       (check (.ref assessment 'error-event-paths)
              => '(("auto-approval" "wrong-effect")))
       (check (.ref assessment 'intended-impact-event-ids)
              => '("benefit"))
       (check (.ref assessment 'error-impact-event-ids) => '("harm"))
       (check (.ref assessment 'release-authorized?) => #f)))

   (poo-flow-test-case "observed error branch is rejected instead of becoming fact"
     (let* ((subject "patient-1")
            (event
             (lambda (identity position parents modality committed?)
               (poo-flow-causal-event
                identity subject 'clinical-event
                (poo-flow-temporal-observation
                 (string-append identity "/time")
                 'logical-version position "clinical-ledger")
                (string-append identity "/payload")
                parents modality committed?)))
            (event-graph
             (poo-flow-causal-event-graph
              subject
              (list (event "request" 1 '() 'observed #t)
                    (event "review" 2 '("request") 'observed #t)
                    (event "unsafe-auto-approval" 2 '("request")
                           'observed #t)
                    (event "harm" 3 '("unsafe-auto-approval")
                           'hypothesized #f))))
            (contract
             (poo-flow-causal-trajectory-contract
              "reject-observed-error" "request" '("review")
              '(("unsafe-auto-approval")) '() '("harm")))
            (assessment
             (poo-flow-causal-trajectory-assess contract event-graph)))
       (check (.ref assessment 'accepted?) => #f)
       (check (map car (.ref assessment 'diagnostics))
              => '(invalid-error-modality))
       (check (.ref assessment 'release-authorized?) => #f)))

   (poo-flow-test-case "missing parents keep temporal classification partial"
     (let* ((event
             (poo-flow-causal-event
              "observation-1" "patient-1" 'clinical-observation
              (poo-flow-temporal-observation
               "observation-1/time" 'logical-version 2 "clinical-ledger")
              "observation-1/payload"
              '("missing-administration") 'observed #t))
            (event-graph
             (poo-flow-causal-event-graph "patient-1" (list event)))
            (cut (poo-flow-causal-cut event-graph 2))
            (receipt
             (poo-flow-temporal-causal-classify
              event-graph cut "observation-1" 4)))
       (check (.ref event-graph 'complete?) => #f)
       (check (.ref cut 'complete?) => #f)
       (check (.ref receipt 'status) => 'partial-temporal-classification)
       (check (.ref receipt 'unknown-frontier)
              => '("missing-administration"))))

   (poo-flow-test-case "parent-after-child ordering invalidates the causal cut"
     (let* ((parent
             (poo-flow-causal-event
              "late-parent" "patient-1" 'late-parent
              (poo-flow-temporal-observation
               "late-parent/time" 'logical-version 3 "clinical-ledger")
              "late-parent/payload" '() 'observed #t))
            (child
             (poo-flow-causal-event
              "early-child" "patient-1" 'early-child
              (poo-flow-temporal-observation
               "early-child/time" 'logical-version 2 "clinical-ledger")
              "early-child/payload" '("late-parent") 'observed #t))
            (event-graph
             (poo-flow-causal-event-graph
              "patient-1" (list parent child)))
            (cut (poo-flow-causal-cut event-graph 3))
            (receipt
             (poo-flow-temporal-causal-classify
              event-graph cut "late-parent" 4)))
       (check (.ref event-graph 'temporal-order-violations)
              => '(("late-parent" "early-child")))
       (check (.ref cut 'complete?) => #f)
       (check (.ref receipt 'status) => 'invalid-causal-cut)
       (check (.ref receipt 'assurance-closed?) => #f)))

   (poo-flow-test-case "same-time causal cycle cannot qualify as complete"
     (let* ((event
             (lambda (identity parent)
               (poo-flow-causal-event
                identity "cycle-probe" 'proposed-event
                (poo-flow-temporal-observation
                 (string-append identity "/time")
                 'logical-version 1 "cycle-probe")
                identity (list parent) 'counterfactual #f)))
            (graph
             (poo-flow-causal-event-graph
              "cycle-probe"
              (list (event "a" "b") (event "b" "a")))))
       (check (.ref graph 'complete?) => #f)
       (check (.ref graph 'temporal-order-violations)
              => '(("b" "a") ("a" "b")))))))
