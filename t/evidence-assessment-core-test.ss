;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :std/test test-suite check check-exception)
        (only-in :clan/poo/object .o .ref .slot?)
        (only-in :agentic-ai-lab/modules/query/interface
                 AgenticAILabQuery. AgenticAILabGqlQueryProgram.
                 AgenticAILabSchemeGqlQueryLanguage.
                 GraphSyntaxNode. GraphSyntaxPath. GraphSyntaxProperty.
                 GraphSyntaxProjection. agentic-ai-lab-query-result-contract)
        (only-in :agentic-ai-lab/modules/evidence-assessment/interface
                 AgenticAILabEvidenceAssessmentCase.
                 agentic-ai-lab-evidence-reference
                 agentic-ai-lab-evidence-claim
                 agentic-ai-lab-evidence-step
                 agentic-ai-lab-evidence-hypothesis
                 agentic-ai-lab-evidence-branch
                 agentic-ai-lab-evidence-assessment-evaluate
                 agentic-ai-lab-evidence-hypothesis-result
                 agentic-ai-lab-evidence-assessment-explore))

(export evidence-assessment-core-test)

(def ClaimProgram
  (.o (:: @ AgenticAILabGqlQueryProgram.)
      identity: 'evidence-assessment-core-claims
      match:
      (.o (:: @ GraphSyntaxPath.)
          start: (.o (:: @ GraphSyntaxNode.)
                     binding: 'claim label: 'EvidenceClaim))
      project:
      (.o (:: @ GraphSyntaxProjection.)
          expression:
          (.o (:: @ GraphSyntaxProperty.) binding: 'claim property: 'identity)
          next:
          (.o (:: @ GraphSyntaxProjection.)
              expression:
              (.o (:: @ GraphSyntaxProperty.) binding: 'claim property: 'value)
              next:
              (.o (:: @ GraphSyntaxProjection.)
                  expression:
                  (.o (:: @ GraphSyntaxProperty.)
                      binding: 'claim property: 'evidenceSource))))))

(def ClaimQuery
  (.o (:: @ AgenticAILabQuery.)
      identity: 'evidence-assessment-core-claims
      version: "1"
      semantic-revision: "sha256:evidence-assessment-core"
      element-space-identity: 'test/evidence-assessment
      selected-element-identities: '(outcome target-a target-b alternate)
      language: AgenticAILabSchemeGqlQueryLanguage.
      program: ClaimProgram
      result-bound: 16
      completeness-requirement: 'complete
      evidence-requirements:
      '(source-content-identity provenance-root result-digest)
      result-contract:
      (agentic-ai-lab-query-result-contract
       'test/evidence-assessment-rows 'relation-row
       '(claim value evidenceSource) 16)))

(def CoreCase.
  (.o (:: @ AgenticAILabEvidenceAssessmentCase.)
      query: ClaimQuery
      claims:
      (list (agentic-ai-lab-evidence-claim 'outcome 'present 'source-a)
            (agentic-ai-lab-evidence-claim
             'target-a 'destination-1 'source-b
             (agentic-ai-lab-evidence-reference
              'source-b "fixture://independent-source-b" 'owner-b
              "sha256:fixture-content-b"))
            (agentic-ai-lab-evidence-claim 'target-b 'destination-1 'source-c))
      steps:
      (list (agentic-ai-lab-evidence-step
             'result 'candidate 'outcome 'target-a)
            (agentic-ai-lab-evidence-step
             'candidate 'origin 'target-a 'target-b 'equal-value)
            (agentic-ai-lab-evidence-step
             'result 'alternative 'outcome 'alternate))
      hypotheses:
      (list (agentic-ai-lab-evidence-hypothesis
             'matched-source 'result 'origin
             '(outcome target-a target-b))
            (agentic-ai-lab-evidence-hypothesis
             'alternative-source 'result 'alternative
             '(outcome alternate)))))

(def (result-status receipt hypothesis-id)
  (.ref (agentic-ai-lab-evidence-hypothesis-result receipt hypothesis-id)
        'status))

(def evidence-assessment-core-test
  (test-suite "generic evidence assessment over POO evidence"
    (yuanxu-test-case "matching sources support one candidate only"
      (let (receipt (agentic-ai-lab-evidence-assessment-evaluate CoreCase.))
        (check (.ref receipt 'query-executed-in-scheme?) => #t)
        (check (result-status receipt 'matched-source) => 'supported)
        (check (result-status receipt 'alternative-source)
               => 'needs-evidence)
        (check
         (length
          (.ref (agentic-ai-lab-evidence-hypothesis-result
                 receipt 'matched-source) 'witness-path))
         => 2)
        (check (length (.ref receipt 'evidence-references)) => 1)
        (check (.ref receipt 'evidence-without-content-digest)
               => '(outcome target-b))
        (check (.ref receipt 'source-authenticity-verified?) => #f)))
    (yuanxu-test-case "multiple proposed directions retain every hypothesis"
      (let* ((exploration
              (agentic-ai-lab-evidence-assessment-explore
               CoreCase.
               (list
                (agentic-ai-lab-evidence-branch
                 'support-alternative
                 (list (agentic-ai-lab-evidence-claim
                        'alternate 'present 'source-x))
                 '() 'test-competing-origin)
                (agentic-ai-lab-evidence-branch
                 'contradict-target
                 (list (agentic-ai-lab-evidence-claim
                        'target-b 'destination-2 'source-d))
                 '() 'test-value-conflict)
                (agentic-ai-lab-evidence-branch
                 'withhold-source '() '(target-a)
                 'test-source-dependence))))
             (branches (.ref exploration 'branch-results))
             (support (.ref (car branches) 'hypothesis-transitions))
             (contradict (.ref (cadr branches) 'hypothesis-transitions))
             (withhold (.ref (caddr branches) 'hypothesis-transitions)))
        (check (length branches) => 3)
        (check (.ref (cadr support) 'after-status) => 'supported)
        (check (.ref (car contradict) 'after-status) => 'conflicted)
        (check (.ref (car withhold) 'after-status) => 'needs-evidence)
        (check (.slot? exploration 'recommended-branch) => #f)
        (check (.ref exploration 'historical-attribution-verified?) => #f)
        (check (.ref exploration 'action-authority?) => #f)))
    (yuanxu-test-case "a conflicting source defeats the matching pair"
      (let* ((case-value
              (.o (:: @ CoreCase.)
                  claims:
                  (cons (agentic-ai-lab-evidence-claim
                         'target-b 'destination-2 'source-d)
                        (.ref CoreCase. 'claims))))
             (receipt (agentic-ai-lab-evidence-assessment-evaluate case-value)))
        (check (.ref receipt 'evidence-consistent?) => #f)
        (check (result-status receipt 'matched-source) => 'conflicted)
        (check (result-status receipt 'alternative-source)
               => 'needs-evidence)))
    (yuanxu-test-case "a cyclic candidate graph reaches a finite fixed point"
      (let* ((case-value
              (.o (:: @ CoreCase.)
                  steps:
                  (cons (agentic-ai-lab-evidence-step
                         'origin 'result 'target-a 'target-b 'equal-value)
                        (.ref CoreCase. 'steps))))
             (receipt (agentic-ai-lab-evidence-assessment-evaluate case-value)))
        (check (result-status receipt 'matched-source) => 'supported)
        (check (< (length (.ref receipt 'reachable-candidates)) 16)
               => #t)))
    (yuanxu-test-case "negative claims are rejected"
      (check-exception
       (agentic-ai-lab-evidence-assessment-evaluate
        (.o (:: @ CoreCase.)
            claims: (list (agentic-ai-lab-evidence-claim
                           'outcome 'absent 'source-a))))
       true))
    (yuanxu-test-case "a source reference cannot impersonate another claim"
      (check-exception
       (agentic-ai-lab-evidence-assessment-evaluate
        (.o (:: @ CoreCase.)
            claims:
            (list (agentic-ai-lab-evidence-claim
                   'outcome 'present 'source-a
                   (agentic-ai-lab-evidence-reference
                    'source-b "fixture://wrong-source" 'owner-b)))))
       true))
    (yuanxu-test-case "agent branches require distinct bounded identities"
      (let (branch-value
            (agentic-ai-lab-evidence-branch
             'same-direction
             (list (agentic-ai-lab-evidence-claim
                    'alternate 'present 'source-x))
             '() 'test-alternative))
        (check-exception
         (agentic-ai-lab-evidence-assessment-explore
          CoreCase. (list branch-value branch-value))
         true)))))
