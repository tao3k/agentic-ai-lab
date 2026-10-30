;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Agentic AI Lab identity and default authoring policy for the Core Module Interface.
;;; Schema indexing, option vocabulary, and native construction live in Core.
(import (rename-in (only-in :yuanxu/module-system/source/interface
                            yuanxu-module-interface-prototype)
                   (yuanxu-module-interface-prototype ModuleInterface.))
        (only-in :clan/poo/object .o .ref .slot? object?)
        :yuanxu/module-system/config
        (only-in :yuanxu/module-system/authoring/roles
                 yuanxu-default-module-authoring-profile))

(export agentic-ai-lab-modules-kind
        agentic-ai-lab-brand-name
        agentic-ai-lab-brand-group
        agentic-ai-lab-scheme-owner
        agentic-ai-lab-module-system-owner
        agentic-ai-lab-module-workflow-kind
        yuanxu-module-value-catalog-kind
        agentic-ai-lab-eval-modules-result-kind
        agentic-ai-lab-module-system-presentation-kind
        agentic-ai-lab-module-interface-kind
        yuanxu-module-interface-prototype
        yuanxu-module-interface
        yuanxu-module-interface?
        (import: :yuanxu/module-system/config))

(def agentic-ai-lab-brand-name "agentic-ai-lab")
(def agentic-ai-lab-brand-group 'agentic-ai-lab)
(def agentic-ai-lab-scheme-owner "agentic-ai-lab.scheme")
(def agentic-ai-lab-module-system-owner "agentic-ai-lab.modules")

;;; Product receipt vocabulary is not a Core mechanism.
(def agentic-ai-lab-modules-kind "agentic-ai-lab.modules.v1")
(def agentic-ai-lab-module-workflow-kind "agentic-ai-lab.modules.workflow.v1")
(def yuanxu-module-value-catalog-kind "yuanxu.modules.value-catalog.v1")
(def agentic-ai-lab-eval-modules-result-kind "agentic-ai-lab.modules.eval-result.v1")
(def agentic-ai-lab-module-system-presentation-kind
  "agentic-ai-lab.modules.system-presentation.v1")
(def agentic-ai-lab-module-interface-kind "agentic-ai-lab.modules.interface.v1")

(def yuanxu-module-interface-prototype
  (.o (:: @ ModuleInterface.)
      kind: agentic-ai-lab-module-interface-kind
      id: "anonymous-poo-module-interface"
      brand-name: agentic-ai-lab-brand-name))

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
                               agentic-ai-lab-module-interface-kind)))
