;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Public POO facade. Verified intermediates remain inside the private kernel.
(import (prefix-in "private/rule-kernel.ss" kernel.))
(export AgenticAILabTemporalRuleProgram agentic-ai-lab-temporal-rule-relation
        agentic-ai-lab-temporal-rule-variable agentic-ai-lab-temporal-rule-literal
        agentic-ai-lab-temporal-rule-atom agentic-ai-lab-temporal-rule
        agentic-ai-lab-temporal-rule-program agentic-ai-lab-temporal-rule-correspondence-from-ascent
        agentic-ai-lab-temporal-rule-correspondence-replay
        agentic-ai-lab-temporal-rule-program-ascent-query)

;;; Keep the established runtime bindings for already compiled consumers.
(def AgenticAILabTemporalRuleProgram kernel.AgenticAILabTemporalRuleProgram)
(def agentic-ai-lab-temporal-rule-relation kernel.agentic-ai-lab-temporal-rule-relation)
(def agentic-ai-lab-temporal-rule-variable kernel.agentic-ai-lab-temporal-rule-variable)
(def agentic-ai-lab-temporal-rule-literal kernel.agentic-ai-lab-temporal-rule-literal)
(def agentic-ai-lab-temporal-rule-atom kernel.agentic-ai-lab-temporal-rule-atom)
(def agentic-ai-lab-temporal-rule kernel.agentic-ai-lab-temporal-rule)
(def agentic-ai-lab-temporal-rule-program kernel.agentic-ai-lab-temporal-rule-program)
(def agentic-ai-lab-temporal-rule-correspondence-from-ascent kernel.agentic-ai-lab-temporal-rule-correspondence-from-ascent)
(def agentic-ai-lab-temporal-rule-correspondence-replay kernel.agentic-ai-lab-temporal-rule-correspondence-replay)
(def agentic-ai-lab-temporal-rule-program-ascent-query kernel.agentic-ai-lab-temporal-rule-program-ascent-query)
