;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: checked-out official contribution source collections.
;;; Invariant: Git submodule gitlinks own revisions and .gitmodules owns URLs;
;;; this module only exposes the packages root for identity-driven discovery.

(import (only-in :poo-flow/modules/module-authoring/source-policy PooFlowModuleStylePolicy)
        :core/module-system/source/collection
        :poo-flow/modules/module-authoring/module-source-collection)

(export poo-flow-official-contribution-sources
        poo-flow-official-contribution-load-path)

(def poo-flow-official-contribution-sources
  (list
   (make-poo-flow-contribution-root-module-source
    'poo-flow-official-contributions "packages"
    style-policy: PooFlowModuleStylePolicy)))

(def poo-flow-official-contribution-load-path
  (extend-poo-flow-module-load-path
   poo-flow-default-module-load-path
   'poo-flow-with-official-contributions
   poo-flow-official-contribution-sources))
