;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Import progress is reported only at real dependency boundaries. The outer
;;; watchdog owns both startup and idle limits; no timer emits keepalive text.
;;; ASCENT dependency order follows the compiled imports of pinned REV 964feb3e.
(def imported-modules (make-hash-table))
(for-each
 (lambda (module)
   (displayln "IMPORT " module) (force-output)
   (eval `(import ,module))
   (hash-put! imported-modules module #t)
   (displayln "IMPORT-OK " module) (force-output))
 '(:clan/poo/object
   :clan/poo/mop
   :yuanxu/object-types/contracts
   :yuanxu/module-system/schema/slot-contracts
   :yuanxu/utilities/product-syntax
   :yuanxu/utilities/final-projection-syntax
   :yuanxu/graph/types-core
   :yuanxu/graph/types-contracts
   :yuanxu/graph/types
   :agentic-ai-lab/modules/temporal-causality/types
   :agentic-ai-lab/modules/temporal-causality/objects
   :agentic-ai-lab/modules/temporal-causality/funs
   :agentic-ai-lab/modules/temporal-causality/time/types
   :agentic-ai-lab/modules/temporal-causality/time/objects
   :agentic-ai-lab/modules/temporal-causality/time/uncertainty-types
   :agentic-ai-lab/modules/temporal-causality/time/uncertainty-objects
   :agentic-ai-lab/modules/temporal-causality/time/uncertainty-funs
   :gerbil-ascent/core/binary-relation
   :gerbil-ascent/table/expression
   :gerbil-ascent/table/funs
   :gerbil-ascent/table/eqrel
   :gerbil-ascent/table/trrel
   :gerbil-ascent/table/provider
   :gerbil-ascent/table/storage
   :gerbil-ascent/table/interface
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
   :gerbil-ascent/program/interface
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
   :gerbil-ascent/candidate/reasoning
   :gerbil-ascent/temporal/graph
   :gerbil-ascent/temporal/lens
   :gerbil-ascent/interface/request
   :agentic-ai-lab/modules/temporal-causality/time/types
   :agentic-ai-lab/modules/temporal-causality/time/objects
   :agentic-ai-lab/modules/temporal-causality/time/funs
   :agentic-ai-lab/modules/temporal-causality/revisions/types
   :agentic-ai-lab/modules/temporal-causality/revisions/objects
   :agentic-ai-lab/modules/temporal-causality/revisions/funs
   :agentic-ai-lab/modules/temporal-causality/revisions/interface
   :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/types
   :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/objects
   :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/funs
   :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy
   :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/interface
   :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy-host
   :agentic-ai-lab/modules/temporal-causality/evaluator/positive-proof
   :agentic-ai-lab/modules/temporal-causality/evaluator/fact
   :agentic-ai-lab/modules/temporal-causality/evaluator/binding
   :agentic-ai-lab/modules/temporal-causality/evaluator/rule
   :agentic-ai-lab/modules/temporal-causality/evaluator/derivation
   :agentic-ai-lab/modules/temporal-causality/evaluator/proof-host
   :agentic-ai-lab/modules/temporal-causality/evaluator/interface
   :gerbil/tools/gxtest))
;;; Resolve the Context/Orgize closure with the compiler's real dependency order.
;;; No timer emits progress and no hand-written parser dependency list is kept.
(eval '(import :gerbil/compiler/driver :gerbil/expander))
(eval '(let* ((ctx (import-module "modules/ai-agentic-context/session-host.ss"))
       (deps (gxc#find-runtime-module-deps ctx)))
  (for-each (lambda (dep)
    (let* ((id (expander-context-id dep))
           (name (if (symbol? id) (symbol->string id) id)))
      (unless (or (and (>= (string-length name) 7) (equal? (substring name 0 7) "gerbil/"))
                  (member #\~ (string->list name)))
        (let (module (string->symbol (string-append ":" name)))
          (unless (hash-get imported-modules module)
            (displayln "CONTEXT-IMPORT " module) (force-output)
            (eval `(import ,module))
            (hash-put! imported-modules module #t)
            (displayln "CONTEXT-IMPORT-OK " module) (force-output)))))) deps)))
(eval '(exit (gerbil/tools/gxtest#main "-v" "5" "t/temporal-evaluator-test.ss")))
