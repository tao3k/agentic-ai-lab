;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/graph/types
                 yuanxu-graph yuanxu-graph-edge yuanxu-graph-node)
        :agentic-ai-lab/modules/temporal-causality/interface)

(export temporal-causality-core-test)

(def temporal-causality-core-test
  (test-suite
   "Temporal Causality core"

   (yuanxu-test-case "structural Impact returns relation trajectory witnesses"
     (let* ((graph
             (yuanxu-graph
              'medication-change
              (list (yuanxu-graph-node 'case)
                    (yuanxu-graph-node 'profile)
                    (yuanxu-graph-node 'source)
                    (yuanxu-graph-node 'unrelated))
              (list (yuanxu-graph-edge
                     'case 'profile 'HAS_EFFECTIVE_PROFILE)
                    (yuanxu-graph-edge
                     'profile 'source 'DECLARES_SOURCE))))
            (receipt
             (agentic-ai-lab-structural-impact-analyze
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
       (check (agentic-ai-lab-structural-impact-receipt? receipt) => #t)
       (check (.ref receipt 'status) => 'snapshot-scoped-impact)
       (check (.ref receipt 'affected-node-ids)
              => '(source profile case))
       (check (.ref case-witness 'node-path)
              => '(source profile case))
       (check (.ref case-witness 'relation-path)
              => '(DECLARES_SOURCE HAS_EFFECTIVE_PROFILE))
       (check (.ref receipt 'temporal-impact-assessed?) => #f)
       (check (.ref receipt 'release-authorized?) => #f)))

   (yuanxu-test-case "incomplete inventory cannot claim scoped completeness"
     (let* ((graph
             (yuanxu-graph
              'partial
              (list (yuanxu-graph-node 'changed))
              '()))
            (receipt
             (agentic-ai-lab-structural-impact-analyze
              graph '(changed) '(dependency) 'dependents #f)))
       (check (.ref receipt 'status) => 'partial-impact)))

   (yuanxu-test-case "structural Impact terminates on relation cycles"
     (let* ((graph
             (yuanxu-graph
              'cyclic-software-structure
              (list (yuanxu-graph-node 'requirement)
                    (yuanxu-graph-node 'verification))
              (list (yuanxu-graph-edge
                     'requirement 'verification 'VERIFIES)
                    (yuanxu-graph-edge
                     'verification 'requirement 'TRACES_BACK))))
            (receipt
             (agentic-ai-lab-structural-impact-analyze
              graph '(requirement) '(VERIFIES TRACES_BACK)
              'dependencies #t)))
       (check (.ref receipt 'status) => 'snapshot-scoped-impact)
       (check (.ref receipt 'affected-node-ids)
              => '(requirement verification))
       (check (length (.ref receipt 'relation-trajectories)) => 2)))

   (yuanxu-test-case "causal cut classifies bounded past present and future"
     (let* ((subject "patient-1")
            (event
             (lambda (identity kind position parents modality committed?)
               (agentic-ai-lab-causal-event
                identity subject kind
                (agentic-ai-lab-temporal-observation
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
             (agentic-ai-lab-causal-event-graph
              subject
              (list prescription administration observation discovery
                    future-dose counterfactual outside)))
            (cut (agentic-ai-lab-causal-cut event-graph 4))
            (receipt
             (agentic-ai-lab-temporal-causal-classify
              event-graph cut "prescription-1" 6)))
       (check (agentic-ai-lab-causal-event-graph? event-graph) => #t)
       (check (agentic-ai-lab-causal-cut? cut) => #t)
       (check (.ref cut 'complete?) => #t)
       (check (map (lambda (event) (.ref event 'identity))
                   (.ref cut 'events))
              => '("prescription-1" "administration-1"
                   "observation-1" "error-discovery-1"))
       (check (agentic-ai-lab-temporal-classification-receipt? receipt) => #t)
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

   (yuanxu-test-case "trajectory contract separates intended error and Impact layers"
     (let* ((subject "patient-1")
            (event
             (lambda (identity position parents modality committed?)
               (agentic-ai-lab-causal-event
                identity subject 'clinical-event
                (agentic-ai-lab-temporal-observation
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
            (event-graph (agentic-ai-lab-causal-event-graph subject events))
            (contract
             (agentic-ai-lab-causal-trajectory-contract
              "clinical-safety" "request"
              '("evidence" "hold" "review" "ready")
              '(("auto-approval" "wrong-effect"))
              '("benefit") '("harm")))
            (assessment
             (agentic-ai-lab-causal-trajectory-assess contract event-graph)))
       (check (agentic-ai-lab-causal-trajectory-contract? contract) => #t)
       (check (agentic-ai-lab-causal-trajectory-assessment? assessment) => #t)
       (check (.ref assessment 'status) => 'causal-trajectory-admitted)
       (check (.ref assessment 'accepted?) => #t)
       (check (.ref assessment 'error-event-paths)
              => '(("auto-approval" "wrong-effect")))
       (check (.ref assessment 'intended-impact-event-ids)
              => '("benefit"))
       (check (.ref assessment 'error-impact-event-ids) => '("harm"))
       (check (.ref assessment 'release-authorized?) => #f)))

   (yuanxu-test-case "observed error branch is rejected instead of becoming fact"
     (let* ((subject "patient-1")
            (event
             (lambda (identity position parents modality committed?)
               (agentic-ai-lab-causal-event
                identity subject 'clinical-event
                (agentic-ai-lab-temporal-observation
                 (string-append identity "/time")
                 'logical-version position "clinical-ledger")
                (string-append identity "/payload")
                parents modality committed?)))
            (event-graph
             (agentic-ai-lab-causal-event-graph
              subject
              (list (event "request" 1 '() 'observed #t)
                    (event "review" 2 '("request") 'observed #t)
                    (event "unsafe-auto-approval" 2 '("request")
                           'observed #t)
                    (event "harm" 3 '("unsafe-auto-approval")
                           'hypothesized #f))))
            (contract
             (agentic-ai-lab-causal-trajectory-contract
              "reject-observed-error" "request" '("review")
              '(("unsafe-auto-approval")) '() '("harm")))
            (assessment
             (agentic-ai-lab-causal-trajectory-assess contract event-graph)))
       (check (.ref assessment 'accepted?) => #f)
       (check (map car (.ref assessment 'diagnostics))
              => '(invalid-error-modality))
       (check (.ref assessment 'release-authorized?) => #f)))

   (yuanxu-test-case "missing parents keep temporal classification partial"
     (let* ((event
             (agentic-ai-lab-causal-event
              "observation-1" "patient-1" 'clinical-observation
              (agentic-ai-lab-temporal-observation
               "observation-1/time" 'logical-version 2 "clinical-ledger")
              "observation-1/payload"
              '("missing-administration") 'observed #t))
            (event-graph
             (agentic-ai-lab-causal-event-graph "patient-1" (list event)))
            (cut (agentic-ai-lab-causal-cut event-graph 2))
            (receipt
             (agentic-ai-lab-temporal-causal-classify
              event-graph cut "observation-1" 4)))
       (check (.ref event-graph 'complete?) => #f)
       (check (.ref cut 'complete?) => #f)
       (check (.ref receipt 'status) => 'partial-temporal-classification)
       (check (.ref receipt 'unknown-frontier)
              => '("missing-administration"))))

   (yuanxu-test-case "parent-after-child ordering invalidates the causal cut"
     (let* ((parent
             (agentic-ai-lab-causal-event
              "late-parent" "patient-1" 'late-parent
              (agentic-ai-lab-temporal-observation
               "late-parent/time" 'logical-version 3 "clinical-ledger")
              "late-parent/payload" '() 'observed #t))
            (child
             (agentic-ai-lab-causal-event
              "early-child" "patient-1" 'early-child
              (agentic-ai-lab-temporal-observation
               "early-child/time" 'logical-version 2 "clinical-ledger")
              "early-child/payload" '("late-parent") 'observed #t))
            (event-graph
             (agentic-ai-lab-causal-event-graph
              "patient-1" (list parent child)))
            (cut (agentic-ai-lab-causal-cut event-graph 3))
            (receipt
             (agentic-ai-lab-temporal-causal-classify
              event-graph cut "late-parent" 4)))
       (check (.ref event-graph 'temporal-order-violations)
              => '(("late-parent" "early-child")))
       (check (.ref cut 'complete?) => #f)
       (check (.ref receipt 'status) => 'invalid-causal-cut)
       (check (.ref receipt 'assurance-closed?) => #f)))

   (yuanxu-test-case "same-time causal cycle cannot qualify as complete"
     (let* ((event
             (lambda (identity parent)
               (agentic-ai-lab-causal-event
                identity "cycle-probe" 'proposed-event
                (agentic-ai-lab-temporal-observation
                 (string-append identity "/time")
                 'logical-version 1 "cycle-probe")
                identity (list parent) 'counterfactual #f)))
            (graph
             (agentic-ai-lab-causal-event-graph
              "cycle-probe"
              (list (event "a" "b") (event "b" "a")))))
       (check (.ref graph 'complete?) => #f)
       (check (.ref graph 'temporal-order-violations)
              => '(("b" "a") ("a" "b")))))))
