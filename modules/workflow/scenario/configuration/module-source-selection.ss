;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: resolve source-neutral POO selections against an ordered load path.

(import :yuanxu/modules/funflow/control-plane/failure
        :yuanxu/module-system/source/collection
        (only-in :agentic-ai-lab/modules/module-authoring/module-source-collection make-agentic-ai-lab-contribution-module-load-path agentic-ai-lab-default-module-load-path agentic-ai-lab-maintained-module-source)
        (only-in :yuanxu/module-system/source/objects
                 yuanxu-module-source-ref-metadata
                 yuanxu-module-source-ref-value)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection?
                 yuanxu-user-module-selection-key
                 yuanxu-user-module-selection-source-ref
                 yuanxu-user-module-bundles->modules))

(export agentic-ai-lab-module-selection-source-refs
        agentic-ai-lab-module-bundles-source-refs)

(def (agentic-ai-lab-module-source-ref-metadata-ref source-ref key)
  (let (entry (assq key (yuanxu-module-source-ref-metadata source-ref)))
    (and entry (cdr entry))))

(def (agentic-ai-lab-explicit-module-source-refs source-ref)
  (if (eq? (agentic-ai-lab-module-source-ref-metadata-ref source-ref 'kind)
           'custom-module-collection)
    (yuanxu-module-source-collection-interfaces
     (make-yuanxu-module-source-collection
      'user-explicit-modules
      'user
      "."
      (yuanxu-module-source-ref-value source-ref)))
    (list source-ref)))

(def (agentic-ai-lab-module-selection-source-refs load-path selection)
  (unless (and (yuanxu-module-load-path? load-path)
               (yuanxu-user-module-selection? selection))
    (error "invalid module load-path selection" load-path selection))
  (let* ((explicit (yuanxu-user-module-selection-source-ref selection))
         (located
          (if explicit
            (agentic-ai-lab-explicit-module-source-refs explicit)
            (yuanxu-module-load-path-locate
             load-path
             (yuanxu-user-module-selection-key selection)))))
    (if (pair? located)
      located
      (raise-control-plane-failure
       'module-system
       'missing-module-source
       "selected POO module was absent from the ordered module load path"
       (list
        (cons 'module-key (yuanxu-user-module-selection-key selection))
        (cons 'load-path (yuanxu-module-load-path-identity load-path)))))))

(def (agentic-ai-lab-module-bundles-source-refs load-path module-bundles)
  (foldr append
         '()
         (map (lambda (selection)
                (agentic-ai-lab-module-selection-source-refs load-path selection))
              (yuanxu-user-module-bundles->modules module-bundles))))
