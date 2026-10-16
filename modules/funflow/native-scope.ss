;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Local native publication. SourceRef is metadata, never authentication.
(import (only-in :clan/poo/object .def .o)
        (only-in :core/module-system/source/objects
                 make-poo-flow-module-local-source poo-flow-module-source-ref?)
        (only-in :poo-flow/modules/funflow/config-prototypes
                 funflow-check funflow-pipeline)
        (only-in :poo-flow/modules/funflow/profiles/gerbil-scheme
                 make-gerbil-scheme-ci-profile))
(export FunflowModule. Funflow make-funflow-scope)

(.def FunflowModule.
  source: #f

  prototypes:
  (.o check: funflow-check
      pipeline: funflow-pipeline)

  ;; Shared-slot capture is native POO: values come from the outer receiver.
  ;; This view deliberately has no profiles slot and no publishing parent.
  prototype-scope:
  (.o (source) (prototypes))

  profiles:
  (.o gerbil-scheme:
      (make-gerbil-scheme-ci-profile prototype-scope)))

(def (make-funflow-scope source-handle)
  (unless (poo-flow-module-source-ref? source-handle)
    (error "Funflow local publication requires a SourceRef" source-handle))
  (.o (:: @ FunflowModule.)
    source: source-handle))

(def Funflow
  (make-funflow-scope
    (make-poo-flow-module-local-source "modules/funflow")))
