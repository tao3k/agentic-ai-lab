;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: resolve source-neutral POO selections against an ordered load path.

(import :poo-flow/modules/workflow/control-plane/failure
        :core/module-system/source/collection
        (only-in :poo-flow/modules/module-authoring/module-source-collection make-poo-flow-contribution-module-load-path poo-flow-default-module-load-path poo-flow-maintained-module-source)
        (only-in :core/module-system/source/objects
                 poo-flow-module-source-ref-metadata
                 poo-flow-module-source-ref-value)
        (only-in :core/module-system/selection/objects
                 poo-flow-user-module-selection?
                 poo-flow-user-module-selection-key
                 poo-flow-user-module-selection-source-ref
                 poo-flow-user-module-bundles->modules))

(export poo-flow-module-selection-source-refs
        poo-flow-module-bundles-source-refs)

(def (poo-flow-module-source-ref-metadata-ref source-ref key)
  (let (entry (assq key (poo-flow-module-source-ref-metadata source-ref)))
    (and entry (cdr entry))))

(def (poo-flow-explicit-module-source-refs source-ref)
  (if (eq? (poo-flow-module-source-ref-metadata-ref source-ref 'kind)
           'custom-module-collection)
    (poo-flow-module-source-collection-interfaces
     (make-poo-flow-module-source-collection
      'user-explicit-modules
      'user
      "."
      (poo-flow-module-source-ref-value source-ref)))
    (list source-ref)))

(def (poo-flow-module-selection-source-refs load-path selection)
  (unless (and (poo-flow-module-load-path? load-path)
               (poo-flow-user-module-selection? selection))
    (error "invalid module load-path selection" load-path selection))
  (let* ((explicit (poo-flow-user-module-selection-source-ref selection))
         (located
          (if explicit
            (poo-flow-explicit-module-source-refs explicit)
            (poo-flow-module-load-path-locate
             load-path
             (poo-flow-user-module-selection-key selection)))))
    (if (pair? located)
      located
      (raise-control-plane-failure
       'module-system
       'missing-module-source
       "selected POO module was absent from the ordered module load path"
       (list
        (cons 'module-key (poo-flow-user-module-selection-key selection))
        (cons 'load-path (poo-flow-module-load-path-identity load-path)))))))

(def (poo-flow-module-bundles-source-refs load-path module-bundles)
  (foldr append
         '()
         (map (lambda (selection)
                (poo-flow-module-selection-source-refs load-path selection))
              (poo-flow-user-module-bundles->modules module-bundles))))
