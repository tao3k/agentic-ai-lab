;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Import progress is reported only at real dependency boundaries. The outer
;;; watchdog owns both startup and idle limits; no timer emits keepalive text.
;;; ASCENT dependency order follows the compiled imports of pinned REV 964feb3e.
(for-each
 (lambda (module)
   (displayln "IMPORT " module) (force-output)
   (eval `(import ,module))
   (displayln "IMPORT-OK " module) (force-output))
 '(:clan/poo/object
   :clan/poo/mop
   :tao3k/yuanxu/object-types/contracts
   :tao3k/yuanxu/module-system/schema/slot-contracts
   :tao3k/yuanxu/utilities/product-syntax
   :tao3k/yuanxu/utilities/final-projection-syntax
   :tao3k/yuanxu/graph/types-core
   :tao3k/yuanxu/graph/types-contracts
   :tao3k/yuanxu/graph/types
   :tao3k/agentic-ai-lab/modules/temporal-causality/types
   :tao3k/agentic-ai-lab/modules/temporal-causality/objects
   :tao3k/agentic-ai-lab/modules/temporal-causality/funs
   :tao3k/agentic-ai-lab/modules/temporal-causality/time/types
   :tao3k/agentic-ai-lab/modules/temporal-causality/time/objects
   :tao3k/agentic-ai-lab/modules/temporal-causality/time/uncertainty-types
   :tao3k/agentic-ai-lab/modules/temporal-causality/time/uncertainty-objects
   :tao3k/agentic-ai-lab/modules/temporal-causality/time/uncertainty-funs
   :gerbil-ascent/core/binary-relation
   :gerbil-ascent/table/expression
   :gerbil-ascent/table/funs
   :gerbil-ascent/table/eqrel
   :gerbil-ascent/table/trrel
   :gerbil-ascent/table/provider
   :gerbil-ascent/table/storage
   :gerbil-ascent/table/func
   :gerbil-ascent/program/types
   :gerbil-ascent/program/objects
   :gerbil-ascent/program/aggregators
   :gerbil-ascent/program/syntax
   :gerbil-ascent/core/dependency-graph
   :gerbil-ascent/core/rule-semantics
   :gerbil-ascent/core/positive-plan
   :gerbil-ascent/program/planning
   :gerbil-ascent/program/scheme-checked
   :gerbil-ascent/program/scheme-snapshot
   :gerbil-ascent/program/scheme-query
   :gerbil-ascent/program/admission
   :gerbil-ascent/program/result
   :gerbil-ascent/table/access
   :gerbil-ascent/program/index
   :gerbil-ascent/program/update-selection
   :gerbil-ascent/program/reuse
   :gerbil-ascent/program/analysis
   :gerbil-ascent/program/evaluate
   :gerbil-ascent/program/scheme-admit
   :gerbil-ascent/program/session
   :gerbil-ascent/program/scheme-session
   :gerbil-ascent/program/scheme-admission
   :gerbil-ascent/program/scheme-language
   :gerbil-ascent/program/operator
   :gerbil-ascent/program/operator-change
   :gerbil-ascent/program/operator-session
   :gerbil-ascent/program/summary
   :gerbil-ascent/program/api
   :gerbil-ascent/core/binary-program
   :gerbil-ascent/candidate/closure
   :gerbil-ascent/candidate/datum
   :gerbil-ascent/candidate/types
   :gerbil-ascent/candidate/program
   :gerbil-ascent/candidate/funs
   :gerbil-ascent/candidate/provenance
   :gerbil-ascent/candidate/certificate-limits
   :gerbil-ascent/candidate/program-identity
   :gerbil-ascent/candidate/nonmembership
   :gerbil-ascent/candidate/finite-evidence
   :gerbil-ascent/candidate/stratified-proof
   :gerbil-ascent/candidate/stratified-producer
   :gerbil-ascent/candidate/checked-program
   :gerbil-ascent/temporal/graph
   :gerbil-ascent/temporal/lens
   :gerbil-ascent/interface/request
   :tao3k/agentic-ai-lab/modules/temporal-causality/ascent-exchange
   :tao3k/yuanxu/graph/algorithms
   :tao3k/agentic-ai-lab/modules/workflow/runtime/scheme-wire
   :tao3k/agentic-ai-lab/modules/workflow/runtime/temporal-family
   :tao3k/agentic-ai-lab/modules/temporal-causality/conclusions/types
   :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/types
   :tao3k/agentic-ai-lab/modules/temporal-causality/conclusions/objects
   :tao3k/agentic-ai-lab/modules/temporal-causality/conclusions/funs
   :tao3k/agentic-ai-lab/modules/temporal-causality/admission/interface
   :tao3k/agentic-ai-lab/modules/temporal-causality/applicability/types
   :tao3k/agentic-ai-lab/modules/temporal-causality/applicability/objects
   :tao3k/agentic-ai-lab/modules/temporal-causality/applicability/funs
   :tao3k/agentic-ai-lab/modules/temporal-causality/lifecycle/types
   :tao3k/agentic-ai-lab/modules/temporal-causality/lifecycle/objects
   :tao3k/agentic-ai-lab/modules/temporal-causality/lifecycle/funs
   :tao3k/agentic-ai-lab/modules/temporal-causality/lifecycle/interface
   :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/objects
   :tao3k/agentic-ai-lab/modules/workflow/runtime/temporal-admission
   :tao3k/agentic-ai-lab/modules/workflow/runtime/temporal-archive
   :tao3k/agentic-ai-lab/modules/workflow/runtime/semantic))
(displayln "MODULE-OK semantic")
(displayln "HARNESS-OK semantic-worker")
(displayln "READY") (force-output)
(let loop ()
  (let (line (read-line))
    (unless (eof-object? line)
      (displayln (tao3k/agentic-ai-lab/modules/workflow/runtime/semantic#semantic-call "temporal.solve" line))
      (force-output)
      (loop))))
(displayln "OK") (force-output)
