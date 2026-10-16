;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; POO Flow maintained source roots and precedence, not collection mechanics.
(import :core/module-system/source/collection
        (only-in :poo-flow/modules/module-authoring/source-policy
                 PooFlowModuleStylePolicy))
(export poo-flow-maintained-module-source poo-flow-default-module-load-path
        make-poo-flow-contribution-module-load-path)

(def poo-flow-maintained-module-source
  (make-poo-flow-module-source-collection
   'poo-flow-maintained 'poo-flow "." "modules"
   style-policy: PooFlowModuleStylePolicy))

(def (make-poo-flow-contribution-module-load-path identity-value
                                                  source-root-value)
  ;; A selected contribution owns its module names. Its source must win a
  ;; collision with a maintained module of the same name.
  (make-poo-flow-module-load-path
   identity-value
   (cons (make-poo-flow-contribution-module-source
          identity-value source-root-value style-policy: PooFlowModuleStylePolicy)
         (poo-flow-module-load-path-collections
          poo-flow-default-module-load-path))))

(def poo-flow-default-module-load-path
  (make-poo-flow-module-load-path
   'poo-flow-default
   (list poo-flow-maintained-module-source)))
