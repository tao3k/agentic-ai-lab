;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: loop governor kernel module selection.
;;; Invariant: profile owners compose this row; user-interface does not.

(import :core/module-system/selection/objects)

(export poo-flow-loop-governor-module-bundles)

;;; The loop governor module keeps policy/strategy composition enabled.
;; : (-> Unit [[PooUserModuleSelection]])
(def poo-flow-loop-governor-module-bundles
  (list
   (poo-flow-user-module-bundle
    (loop governor +strategy +policy +marlin-handoff +runtime-manifest
          +l1-report))))
