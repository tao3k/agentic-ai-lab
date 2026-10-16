;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO Flow identity and default authoring policy for the Core Module Interface.
;;; Schema indexing, option vocabulary, and native construction live in Core.
(import (only-in :clan/poo/object .o .ref .slot? object?)
        :core/module-system/config
        (only-in :poo-flow/modules/module-authoring/semantic-module
                 poo-flow-default-module-authoring-profile))

(export poo-flow-modules-kind
        poo-flow-brand-name
        poo-flow-brand-group
        poo-flow-scheme-owner
        poo-flow-module-system-owner
        poo-flow-module-workflow-kind
        poo-flow-module-value-catalog-kind
        poo-flow-eval-modules-result-kind
        poo-flow-module-system-presentation-kind
        poo-flow-module-interface-kind
        poo-flow-module-import-kind
        poo-flow-module-import-source-ref-kind
        poo-flow-module-import-local-source-kind
        poo-flow-module-interface-prototype
        poo-flow-module-interface
        poo-flow-module-interface?
        (import: :core/module-system/config))

(def poo-flow-brand-name "poo-flow")
(def poo-flow-brand-group 'poo-flow)
(def poo-flow-scheme-owner "poo-flow.scheme")
(def poo-flow-module-system-owner "poo-flow.modules")

;;; Product receipt vocabulary is not a Core mechanism.
(def poo-flow-modules-kind "poo-flow.modules.v1")
(def poo-flow-module-workflow-kind "poo-flow.modules.workflow.v1")
(def poo-flow-module-value-catalog-kind "poo-flow.modules.value-catalog.v1")
(def poo-flow-eval-modules-result-kind "poo-flow.modules.eval-result.v1")
(def poo-flow-module-system-presentation-kind
  "poo-flow.modules.system-presentation.v1")
(def poo-flow-module-interface-kind "poo-flow.modules.interface.v1")
(def poo-flow-module-import-kind "poo-flow.modules.import.v1")
(def poo-flow-module-import-source-ref-kind
  "poo-flow.modules.import.source-ref.v1")
(def poo-flow-module-import-local-source-kind
  "poo-flow.modules.import.local-source.v1")

(def poo-flow-module-interface-prototype
  (.o kind: poo-flow-module-interface-kind
      id: "anonymous-poo-module-interface"
      brand-name: poo-flow-brand-name
      schemas: (.o)
      (schema-index
       (poo-flow-module-interface-schema-index schemas))
      authoring: (poo-flow-default-module-authoring-profile)
      metadata: '()))

(def (poo-flow-module-interface interface-id-value schema-object metadata-value
                                authoring: (authoring-value
                                            (poo-flow-default-module-authoring-profile)))
  (make-module-interface poo-flow-module-interface-prototype
                         interface-id-value schema-object metadata-value
                         authoring-value))

(def (poo-flow-module-interface? value)
  (and (object? value)
       (.slot? value 'kind)
       (poo-flow-module-kind=? (.ref value 'kind)
                               poo-flow-module-interface-kind)))
