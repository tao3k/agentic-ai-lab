;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO Flow identity and default authoring policy for the Core Module Interface.
;;; Schema indexing, option vocabulary, and native construction live in Core.
(import (rename-in (only-in :yuanxu/module-system/source/interface
                            yuanxu-module-interface-prototype)
                   (yuanxu-module-interface-prototype ModuleInterface.))
        (only-in :clan/poo/object .o .ref .slot? object?)
        :yuanxu/module-system/config
        (only-in :yuanxu/module-system/authoring/roles
                 yuanxu-default-module-authoring-profile))

(export poo-flow-modules-kind
        poo-flow-brand-name
        poo-flow-brand-group
        poo-flow-scheme-owner
        poo-flow-module-system-owner
        poo-flow-module-workflow-kind
        yuanxu-module-value-catalog-kind
        poo-flow-eval-modules-result-kind
        poo-flow-module-system-presentation-kind
        poo-flow-module-interface-kind
        yuanxu-module-interface-prototype
        yuanxu-module-interface
        yuanxu-module-interface?
        (import: :yuanxu/module-system/config))

(def poo-flow-brand-name "poo-flow")
(def poo-flow-brand-group 'poo-flow)
(def poo-flow-scheme-owner "poo-flow.scheme")
(def poo-flow-module-system-owner "poo-flow.modules")

;;; Product receipt vocabulary is not a Core mechanism.
(def poo-flow-modules-kind "poo-flow.modules.v1")
(def poo-flow-module-workflow-kind "poo-flow.modules.workflow.v1")
(def yuanxu-module-value-catalog-kind "yuanxu.modules.value-catalog.v1")
(def poo-flow-eval-modules-result-kind "poo-flow.modules.eval-result.v1")
(def poo-flow-module-system-presentation-kind
  "poo-flow.modules.system-presentation.v1")
(def poo-flow-module-interface-kind "poo-flow.modules.interface.v1")

(def yuanxu-module-interface-prototype
  (.o (:: @ ModuleInterface.)
      kind: poo-flow-module-interface-kind
      id: "anonymous-poo-module-interface"
      brand-name: poo-flow-brand-name))

(def (yuanxu-module-interface interface-id-value schema-object metadata-value
                                authoring: (authoring-value
                                            (yuanxu-default-module-authoring-profile)))
  (make-module-interface yuanxu-module-interface-prototype
                         interface-id-value schema-object metadata-value
                         authoring-value))

(def (yuanxu-module-interface? value)
  (and (object? value)
       (.slot? value 'kind)
       (yuanxu-module-kind=? (.ref value 'kind)
                               poo-flow-module-interface-kind)))
