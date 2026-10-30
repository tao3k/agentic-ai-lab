;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/mop define-type Type. element?)
        (only-in :std/list/list every))
(export AgenticAILabTemporalFamilyApplicability agentic-ai-lab-temporal-family-applicability?)
(def (shape? value)
  (and (object? value)
       (every (lambda (slot) (.slot? value slot))
              '(kind admission-digest original-source-digest current-source-digest
                status runtime-executed? source-authenticated? action-authorized?))
       (eq? (.ref value 'kind) 'agentic-ai-lab.temporal-causality.family-applicability.v1)
       (every (lambda (slot) (string? (.ref value slot)))
              '(admission-digest original-source-digest current-source-digest))
       (memq (.ref value 'status) '(current stale))
       (every (lambda (slot) (eq? (.ref value slot) #f))
              '(runtime-executed? source-authenticated? action-authorized?))))
(define-type (AgenticAILabTemporalFamilyApplicability @ Type.) .element?: shape?)
(def (agentic-ai-lab-temporal-family-applicability? value)
  (element? AgenticAILabTemporalFamilyApplicability value))
