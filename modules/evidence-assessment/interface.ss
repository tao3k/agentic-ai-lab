;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "funs.ss" "config.ss")
(export EvidenceAssessment
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss"))

(.def EvidenceAssessment
  identity: 'evidence-assessment
  tags: '(evidence assessment reasoning)
  core: (.o scope-contract: EvidenceAssessmentScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/evidence-assessment/interface))
  features: (.o))
