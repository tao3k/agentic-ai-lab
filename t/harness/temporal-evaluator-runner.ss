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
   :core/types
   :core/module-system/schema/slot-contracts
   :core/utilities/product-syntax
   :core/utilities/final-projection-syntax
   :core/graph/types-core
   :core/graph/types-contracts
   :core/graph/types
   :poo-flow/modules/temporal-causality/types
   :poo-flow/modules/temporal-causality/objects
   :poo-flow/modules/temporal-causality/funs
   :poo-flow/modules/temporal-causality/time/types
   :poo-flow/modules/temporal-causality/time/objects
   :poo-flow/modules/temporal-causality/time/uncertainty-types
   :poo-flow/modules/temporal-causality/time/uncertainty-objects
   :poo-flow/modules/temporal-causality/time/uncertainty-funs
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
   :poo-flow/modules/temporal-causality/time/types
   :poo-flow/modules/temporal-causality/time/objects
   :poo-flow/modules/temporal-causality/time/funs
   :poo-flow/modules/temporal-causality/revisions/types
   :poo-flow/modules/temporal-causality/revisions/objects
   :poo-flow/modules/temporal-causality/revisions/funs
   :poo-flow/modules/temporal-causality/revisions/interface
   :poo-flow/modules/temporal-causality/truth-maintenance/support/types
   :poo-flow/modules/temporal-causality/truth-maintenance/support/objects
   :poo-flow/modules/temporal-causality/truth-maintenance/support/funs
   :poo-flow/modules/temporal-causality/truth-maintenance/support/policy
   :poo-flow/modules/temporal-causality/truth-maintenance/support/interface
   :poo-flow/modules/temporal-causality/truth-maintenance/support/policy-host
   :poo-flow/modules/temporal-causality/evaluator/positive-proof
   :poo-flow/modules/temporal-causality/evaluator/fact
   :poo-flow/modules/temporal-causality/evaluator/binding
   :poo-flow/modules/temporal-causality/evaluator/rule
   :poo-flow/modules/temporal-causality/evaluator/derivation
   :poo-flow/modules/temporal-causality/evaluator/proof-host
   :poo-flow/modules/temporal-causality/evaluator/interface
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
