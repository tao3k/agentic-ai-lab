;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Product-specific restricted root authoring policy; shared roles live in Core.
(import (only-in :clan/poo/object .o)
        (only-in :clan/poo/mop validate)
        (only-in :yuanxu/module-system/types ModuleSourceRoleContract ModuleAuthoringProfileContract)
        (only-in :yuanxu/module-system/authoring/roles
                 ConfigSourceRole. yuanxu-default-module-authoring-profile))
(export UserConfigSourceRole. agentic-ai-lab-user-root-module-authoring-profile)

;;; The ordinary user root is deliberately narrower than a maintained module's
;;; config.ss.  It selects maintained values and never reopens the advanced
;;; POO object layer; vertical owners retain that layer in their own Profiles.
(def UserConfigSourceRole.
  (validate ModuleSourceRoleContract
    (.o (:: @ ConfigSourceRole.)
        identity: 'user-config
        recommended-forms: '(user-composition compose use-module)
        forbidden-root-forms:
        '(.def .o stage graph loop prove handoff provider runtime)
        recursive-root-forms?: #t
        forbidden-imports:
        '(:clan/poo/mop
          :yuanxu/poo-clos/interface)
        forbidden-forms:
        '(poo-clos-class
          poo-clos-generic-function
          poo-clos-method
          poo-clos-method-bundle
          .defmethod-bundle)
        forbid-raw-behavior-hooks?: #t
        forbid-raw-query-initializers?: #t
        freedom: 'maintained-value-composition-only)))
(def (agentic-ai-lab-user-root-module-authoring-profile)
  (validate ModuleAuthoringProfileContract
    (.o (:: @ (yuanxu-default-module-authoring-profile))
        config: UserConfigSourceRole.)))
