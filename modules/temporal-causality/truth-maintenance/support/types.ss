;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type.)
        (only-in :std/list/list every))
(export AgenticAILabTemporalSupportPremise AgenticAILabTemporalSupport
        AgenticAILabTemporalSupportProgram AgenticAILabTemporalSupportEvaluation
        AgenticAILabTemporalSupportPolicy AgenticAILabTemporalSupportGuard AgenticAILabTemporalSupportClaim)
(def (shape? x kind names)
  (and (object? x) (.slot? x 'kind) (eq? (.ref x 'kind) kind)
       (every (lambda (name) (.slot? x name)) names)))
(define-type (AgenticAILabTemporalSupportPremise @ Type.)
  .element?: (lambda (x) (shape? x 'agentic-ai-lab.temporal-causality.support-premise
                                '(subject-identity revision-identity))))
(define-type (AgenticAILabTemporalSupport @ Type.)
  .element?: (lambda (x) (shape? x 'agentic-ai-lab.temporal-causality.support
                                '(identity conclusion-identity proof-identity premises conclusion-premises))))
(define-type (AgenticAILabTemporalSupportProgram @ Type.)
  .element?: (lambda (x) (shape? x 'agentic-ai-lab.temporal-causality.support-program
                                '(identity policy-identity inventory-complete? conclusion-identities supports semantic-digest))))
(define-type (AgenticAILabTemporalSupportEvaluation @ Type.)
  .element?: (lambda (x) (shape? x 'agentic-ai-lab.temporal-causality.support-evaluation
                                '(semantic-digest program-digest cut-digest projection-digest conclusions
                                  evaluated-support-count budget-exhausted? proof-admitted? action-authorized? durable?))))

(define-type (AgenticAILabTemporalSupportPolicy @ Type.)
  .element?: (lambda (x) (shape? x 'agentic-ai-lab.temporal-causality.support-policy
                          '(identity revision-identity start end semantic-digest))))
(define-type (AgenticAILabTemporalSupportGuard @ Type.)
  .element?: (lambda (x) (shape? x 'agentic-ai-lab.temporal-causality.support-guard
                          '(semantic-digest policy policy-digest expected-policy-digest effective-at
                            policy-status policy-applicable? evaluation as-of valid-at budget
                            proof-admitted? source-authenticated? selection-admitted? action-authorized? durable?))))

(define-type (AgenticAILabTemporalSupportClaim @ Type.)
  .element?: (lambda (x) (shape? x 'agentic-ai-lab.temporal-causality.support-claim
    '(claim status context-status binding-digest guard proof-admitted? source-authenticated?
      selection-admitted? action-authorized? durable?))))
