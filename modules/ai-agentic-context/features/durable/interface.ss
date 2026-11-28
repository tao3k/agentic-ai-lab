;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Yuanxu Feature declaration for `(ai-agentic-context +durable)`.
;;; Owned by `ai-agentic-context`; auto-activates via Band 1 `enabled?: durable.enabled?`
;;; whenever `durable` is admitted in `yuanxu!` (vetoable by `-durable` in Band 4b).

(import (only-in :clan/poo/object .def)
        (only-in "./objects.ss" EnableContextDurable ContextDurableFeatureContract))
(export Feature)

(.def Feature
  requires: '()
  implied-modules: '(durable)
  refine: EnableContextDurable
  contract: ContextDurableFeatureContract)
