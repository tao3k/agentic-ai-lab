;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate) "types.ss")
(export agentic-ai-lab-temporal-support-premise agentic-ai-lab-temporal-support)
(def (text? x) (and (string? x) (< 0 (string-length x) 257)))
(def (agentic-ai-lab-temporal-support-premise subject-value revision-value)
  (unless (and (text? subject-value) (text? revision-value))
    (error "invalid support premise identity"))
  (validate AgenticAILabTemporalSupportPremise (.o kind: 'agentic-ai-lab.temporal-causality.support-premise
      subject-identity: subject-value revision-identity: revision-value)))
(def (agentic-ai-lab-temporal-support id-value conclusion-value proof-value premises-value parents-value)
  (unless (and (text? id-value) (text? conclusion-value) (text? proof-value))
    (error "invalid support identity"))
  (validate AgenticAILabTemporalSupport (.o kind: 'agentic-ai-lab.temporal-causality.support
      identity: id-value conclusion-identity: conclusion-value proof-identity: proof-value
      premises: premises-value conclusion-premises: parents-value)))
