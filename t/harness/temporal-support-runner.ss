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
    :tao3k/yuanxu/types/contracts
    :tao3k/yuanxu/module-system/schema/slot-contracts
    :tao3k/yuanxu/observability/types
    :tao3k/yuanxu/observability/funcs
    :tao3k/yuanxu/observability/slot-debug
    :tao3k/yuanxu/observability/debug
    :tao3k/yuanxu/testing
    :asp-gerbil-scheme/src/build-api/core-capacity
    :tao3k/yuanxu/observability/output
    :tao3k/yuanxu/module-system/schema/relations
    :tao3k/yuanxu/module-system/types
    :tao3k/yuanxu/module-system/config
    :tao3k/yuanxu/module-system/objects
    :tao3k/yuanxu/module-system/authoring/roles
        (only-in :tao3k/agentic-ai-lab/modules/module-authoring/semantic-module UserConfigSourceRole. agentic-ai-lab-user-root-module-authoring-profile)
    :tao3k/agentic-ai-lab/modules/module-authoring/module-interface
    :tao3k/yuanxu/object/syntax
    :tao3k/yuanxu/utilities/product-syntax
    :tao3k/yuanxu/utilities/final-projection-syntax
    :tao3k/yuanxu/module-system/source/objects
    :tao3k/yuanxu/module-system/source/imports
    :tao3k/yuanxu/module-system/selection/flags
    :tao3k/yuanxu/module-system/selection/objects
    :tao3k/yuanxu/profile-composition/user-profile
    :tao3k/yuanxu/utilities/functional
    :tao3k/yuanxu/profile-composition/policy
    :tao3k/yuanxu/testing
    :tao3k/agentic-ai-lab/modules/temporal-causality/time/types
    :tao3k/agentic-ai-lab/modules/temporal-causality/time/objects
    :tao3k/agentic-ai-lab/modules/temporal-causality/revisions/types
    :tao3k/agentic-ai-lab/modules/temporal-causality/revisions/objects
    :tao3k/agentic-ai-lab/modules/temporal-causality/time/funs
    :tao3k/agentic-ai-lab/modules/temporal-causality/revisions/funs
    :tao3k/agentic-ai-lab/modules/temporal-causality/revisions/interface
    :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/types
    :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/objects
    :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/funs
    :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/policy
    :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/support/interface
    :tao3k/agentic-ai-lab/modules/temporal-causality/truth-maintenance/interface
    :gerbil/tools/gxtest))
(eval '(exit (gerbil/tools/gxtest#main "-v" "5" "t/temporal-support-test.ss")))
