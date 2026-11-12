;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Runtime completed-import boundaries; no timer output or semantic shortcuts.
(for-each (lambda (module)
  (displayln "IMPORT " module) (force-output)
  (eval `(import ,module))
  (displayln "IMPORT-OK " module) (force-output))
 '( :clan/poo/object
    :clan/poo/mop
    :yuanxu/object-types/contracts
    :yuanxu/module-system/schema/slot-contracts
    :yuanxu/observability/types
    :yuanxu/observability/funcs
    :yuanxu/observability/slot-debug
    :yuanxu/observability/debug
    :yuanxu/testing
    :asp-gerbil-scheme/src/build-api/core-capacity
    :yuanxu/observability/output
    :yuanxu/module-system/schema/relations
    :yuanxu/module-system/types
    :yuanxu/module-system/config
    :yuanxu/module-system/objects
    :yuanxu/module-system/authoring/roles
        (only-in :agentic-ai-lab/modules/module-authoring/semantic-module UserConfigSourceRole. agentic-ai-lab-user-root-module-authoring-profile)
    :agentic-ai-lab/modules/module-authoring/module-interface
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
    :yuanxu/testing
    :agentic-ai-lab/modules/temporal-causality/time/types
    :agentic-ai-lab/modules/temporal-causality/time/objects
    :agentic-ai-lab/modules/temporal-causality/revisions/types
    :agentic-ai-lab/modules/temporal-causality/revisions/objects
    :agentic-ai-lab/modules/temporal-causality/time/funs
    :agentic-ai-lab/modules/temporal-causality/revisions/funs
    :agentic-ai-lab/modules/temporal-causality/revisions/interface
    :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/types
    :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/objects
    :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/funs
    :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy
    :agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/interface
    :agentic-ai-lab/modules/temporal-causality/truth-maintenance/interface
    :gerbil/tools/gxtest))
(eval '(exit (gerbil/tools/gxtest#main "-v" "5" "t/temporal-support-test.ss")))
