;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every)
        (only-in :agentic-ai-lab/modules/temporal-causality/admission/interface
                 agentic-ai-lab-temporal-family-admission?)
        (only-in :agentic-ai-lab/modules/temporal-causality/conclusions/types
                 agentic-ai-lab-temporal-conclusion-revision? agentic-ai-lab-temporal-conclusion-journal?)
        (only-in :agentic-ai-lab/modules/temporal-causality/truth-maintenance/types
                 agentic-ai-lab-temporal-invalidation-plan?))
(export AgenticAILabTemporalFamilyRevision agentic-ai-lab-temporal-family-revision?
        AgenticAILabTemporalFamilyArchive agentic-ai-lab-temporal-family-archive?)
(def (shape? value)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot))
              '(kind semantic-digest admission revision predecessor frontier
                runtime-executed? source-authenticated? action-authorized?))
       (eq? (.ref value 'kind) 'agentic-ai-lab.temporal-causality.family-revision.v1)
       (string? (.ref value 'semantic-digest))
       (agentic-ai-lab-temporal-family-admission? (.ref value 'admission))
       (agentic-ai-lab-temporal-conclusion-revision? (.ref value 'revision))
       (or (and (not (.ref value 'predecessor)) (not (.ref value 'frontier)))
           (and (object? (.ref value 'predecessor))
                (agentic-ai-lab-temporal-invalidation-plan? (.ref value 'frontier))))
       (every (lambda (slot) (eq? (.ref value slot) #f))
              '(runtime-executed? source-authenticated? action-authorized?))))
(define-type (AgenticAILabTemporalFamilyRevision @ Type.) .element?: shape?)
(def (agentic-ai-lab-temporal-family-revision? value)
  (element? AgenticAILabTemporalFamilyRevision value))

(def (archive-shape? value)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot))
              '(kind identity semantic-digest family-revisions journal
                source-authenticated? action-authorized? runtime-executed? durable?))
       (eq? (.ref value 'kind) 'agentic-ai-lab.temporal-causality.family-archive.v1)
       (string? (.ref value 'identity)) (string? (.ref value 'semantic-digest))
       (list? (.ref value 'family-revisions))
       (<= 1 (length (.ref value 'family-revisions)) 128)
       (every agentic-ai-lab-temporal-family-revision? (.ref value 'family-revisions))
       (agentic-ai-lab-temporal-conclusion-journal? (.ref value 'journal))
       (every (lambda (slot) (eq? (.ref value slot) #f))
              '(source-authenticated? action-authorized? runtime-executed? durable?))))
(define-type (AgenticAILabTemporalFamilyArchive @ Type.) .element?: archive-shape?)
(def (agentic-ai-lab-temporal-family-archive? value)
  (element? AgenticAILabTemporalFamilyArchive value))
