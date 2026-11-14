;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :tao3k/yuanxu/module-system/source/declaration .def)
        "types.ss" "objects.ss" "funs.ss" "config.ss" "time/interface.ss"
        "revisions/interface.ss" "truth-maintenance/interface.ss"
        "conclusions/interface.ss" "trajectory/interface.ss" "impact/interface.ss"
        "evidence/interface.ss" "candidates/types.ss" "candidates/objects.ss" "candidates/funs.ss" "admission/interface.ss"
        "applicability/interface.ss" "lifecycle/interface.ss")
(export (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss")
        (import: "time/interface.ss")
        (import: "revisions/interface.ss")
        (import: "truth-maintenance/interface.ss")
        (import: "conclusions/interface.ss")
        (import: "trajectory/interface.ss" "impact/interface.ss"
                 "evidence/interface.ss" "candidates/types.ss" "candidates/objects.ss" "candidates/funs.ss" "admission/interface.ss"
                 "applicability/interface.ss" "lifecycle/interface.ss"))

(.def TemporalCausality
  identity: 'temporal-causality
  tags: '(temporal causality)
  core:
  (.o scope-contract: TemporalCausalityScopeContract
      exports:
      (.o structural-impact-analyze: agentic-ai-lab-structural-impact-analyze
          causal-event-graph: agentic-ai-lab-causal-event-graph
          causal-trajectory-assess: agentic-ai-lab-causal-trajectory-assess
          causal-trajectory-assessment-digest: agentic-ai-lab-causal-trajectory-assessment-digest
          causal-cut: agentic-ai-lab-causal-cut
          temporal-causal-classify: agentic-ai-lab-temporal-causal-classify
          temporal-model: agentic-ai-lab-temporal-model
          temporal-overlapping-model: agentic-ai-lab-temporal-overlapping-model
          temporal-model-replay: agentic-ai-lab-temporal-model-replay
          temporal-model-classify: agentic-ai-lab-temporal-model-classify))
  features: (.o))
