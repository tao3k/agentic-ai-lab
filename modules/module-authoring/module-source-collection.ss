;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; POO Flow maintained source roots and precedence, not collection mechanics.
(import (only-in :clan/poo/object .o)
        :yuanxu/module-system/source/collection
        (only-in :poo-flow/modules/module-authoring/source-policy
                 PooFlowModuleStylePolicy))
(export poo-flow-maintained-module-source poo-flow-maintained-integration-directories poo-flow-default-module-load-path
        make-poo-flow-contribution-module-load-path)

(def poo-flow-maintained-integration-directories
  '("building" "evidence-assessment" "module-authoring" "testing" "workflow"))

(def poo-flow-maintained-module-source
  (.o (:: @ (make-yuanxu-module-source-collection
   'poo-flow-maintained 'poo-flow "." "modules"
   style-policy: PooFlowModuleStylePolicy))
      excluded-directories: poo-flow-maintained-integration-directories))

(def (make-poo-flow-contribution-module-load-path identity-value
                                                  source-root-value)
  ;; A selected contribution owns its module names. Its source must win a
  ;; collision with a maintained module of the same name.
  (make-yuanxu-module-load-path
   identity-value
   (cons (make-yuanxu-contribution-module-source
          identity-value source-root-value style-policy: PooFlowModuleStylePolicy)
         (yuanxu-module-load-path-collections
          poo-flow-default-module-load-path))))

(def poo-flow-default-module-load-path
  (make-yuanxu-module-load-path
   'poo-flow-default
   (list poo-flow-maintained-module-source)))
