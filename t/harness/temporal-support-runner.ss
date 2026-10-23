;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Native completed-import boundaries; no timer output or semantic shortcuts.
(for-each (lambda (module)
  (displayln "IMPORT " module) (force-output)
  (eval `(import ,module))
  (displayln "IMPORT-OK " module) (force-output))
 '( :clan/poo/object
    :clan/poo/mop
    :yuanxu/types
    :yuanxu/module-system/schema/slot-contracts
    :yuanxu/observability/types
    :yuanxu/observability/funcs
    :yuanxu/observability/slot-debug
    :yuanxu/observability/debug
    :yuanxu/observability/testing-case
    :asp-gerbil-scheme/src/build-api/core-capacity
    :asp-gerbil-scheme/src/testing/import-footprint-reader
    :asp-gerbil-scheme/src/testing/extension
    :asp-gerbil-scheme/testing-api
    :yuanxu/observability/output
    :poo-flow/dev/modules/testing/testing-extension
    :yuanxu/module-system/schema/relations
    :yuanxu/module-system/types
    :yuanxu/module-system/config
    :yuanxu/module-system/objects
    :yuanxu/module-system/authoring/roles
        (only-in :poo-flow/modules/module-authoring/semantic-module UserConfigSourceRole. poo-flow-user-root-module-authoring-profile)
    :poo-flow/modules/module-authoring/module-interface
    :yuanxu/object-family/syntax
    :yuanxu/utilities/product-syntax
    :yuanxu/utilities/final-projection-syntax
    :yuanxu/module-system/source/objects
    :yuanxu/module-system/source/imports
    :yuanxu/module-system/selection/flags
    :yuanxu/module-system/selection/objects
    :yuanxu/profile-composition/user-profile
    :yuanxu/utilities/functional
    :yuanxu/profile-composition/policy
    :poo-flow/testing-api
    :poo-flow/modules/temporal-causality/time/types
    :poo-flow/modules/temporal-causality/time/objects
    :poo-flow/modules/temporal-causality/revisions/types
    :poo-flow/modules/temporal-causality/revisions/objects
    :poo-flow/modules/temporal-causality/time/funs
    :poo-flow/modules/temporal-causality/revisions/funs
    :poo-flow/modules/temporal-causality/revisions/interface
    :poo-flow/modules/temporal-causality/truth-maintenance/support/types
    :poo-flow/modules/temporal-causality/truth-maintenance/support/objects
    :poo-flow/modules/temporal-causality/truth-maintenance/support/funs
    :poo-flow/modules/temporal-causality/truth-maintenance/support/policy
    :poo-flow/modules/temporal-causality/truth-maintenance/support/interface
    :poo-flow/modules/temporal-causality/truth-maintenance/interface
    :gerbil/tools/gxtest))
(eval '(exit (gerbil/tools/gxtest#main "-v" "5" "t/temporal-support-test.ss")))
