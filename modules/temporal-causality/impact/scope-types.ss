;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every)
        (only-in :agentic-ai-lab/modules/temporal-causality/time/types
                 agentic-ai-lab-temporal-instant?)
        (only-in :agentic-ai-lab/modules/temporal-causality/impact/types
                 agentic-ai-lab-temporal-intervention-window-audit?))
(export AgenticAILabTemporalImpactScope AgenticAILabTemporalImpactScopeAudit
        agentic-ai-lab-temporal-impact-scope?
        agentic-ai-lab-temporal-impact-scope-audit?)

(def (text? value) (and (string? value) (> (string-length value) 0)))
(def (slots? value names)
  (and (object? value) (every (lambda (name) (.slot? value name)) names)))

(def (scope-shape? value)
  (and (slots? value '(kind identity semantic-digest intervention-identity
                             subject-identity source-cut-digest
                             source-projection-digest time-domain-identity
                             onset end direct-target-outcomes
                             protected-outcomes))
       (eq? (.ref value 'kind) 'agentic-ai-lab.temporal-causality.impact-scope)
       (every text? (map (lambda (slot) (.ref value slot))
                         '(identity semantic-digest intervention-identity
                           subject-identity source-cut-digest
                           source-projection-digest time-domain-identity)))
       (agentic-ai-lab-temporal-instant? (.ref value 'onset))
       (agentic-ai-lab-temporal-instant? (.ref value 'end))
       (list? (.ref value 'direct-target-outcomes))
       (pair? (.ref value 'direct-target-outcomes))
       (every text? (.ref value 'direct-target-outcomes))
       (list? (.ref value 'protected-outcomes))
       (every text? (.ref value 'protected-outcomes))))
(define-type (AgenticAILabTemporalImpactScope @ Type.)
  .element?: scope-shape?)
(def (agentic-ai-lab-temporal-impact-scope? value)
  (element? AgenticAILabTemporalImpactScope value))

(def (scope-audit-shape? value)
  (and (slots? value '(kind identity semantic-digest scope-digest
                             candidate-scenario-identity
                             baseline-scenario-identity audited-outcomes
                             window-audits prefix-status protected-status
                             status causal-impact-admitted?
                             runtime-executed?))
       (eq? (.ref value 'kind)
            'agentic-ai-lab.temporal-causality.impact-scope-audit)
       (every text? (map (lambda (slot) (.ref value slot))
                         '(identity semantic-digest scope-digest
                           candidate-scenario-identity
                           baseline-scenario-identity)))
       (list? (.ref value 'audited-outcomes))
       (pair? (.ref value 'audited-outcomes))
       (every text? (.ref value 'audited-outcomes))
       (list? (.ref value 'window-audits))
       (= (length (.ref value 'audited-outcomes))
          (length (.ref value 'window-audits)))
       (every agentic-ai-lab-temporal-intervention-window-audit?
              (.ref value 'window-audits))
       (memq (.ref value 'prefix-status)
             '(consistent diverged unobserved))
       (memq (.ref value 'protected-status)
             '(consistent diverged unobserved))
       (memq (.ref value 'status)
             '(consistent-with-declaration violated unknown))
       (eq? (.ref value 'causal-impact-admitted?) #f)
       (eq? (.ref value 'runtime-executed?) #f)))
(define-type (AgenticAILabTemporalImpactScopeAudit @ Type.)
  .element?: scope-audit-shape?)
(def (agentic-ai-lab-temporal-impact-scope-audit? value)
  (element? AgenticAILabTemporalImpactScopeAudit value))
