;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: adapts module configuration into Funflow and CI/CD POO projections.
;;; Invariant: adapters reuse module contracts and do not execute workflow effects.
(import (only-in :clan/poo/object .ref)
        :core/module-system/selection/objects
        :core/utilities/final-projection-syntax
        :poo-flow/modules/workflow/types
        :poo-flow/modules/workflow/objects
        :poo-flow/modules/funflow/config-prototypes
        :poo-flow/modules/workflow/funs)

(export poo-flow-funflow-require
        poo-flow-funflow-symbol-list?
        poo-flow-funflow-optional-metadata/tail
        poo-flow-funflow-list-metadata/tail
        poo-flow-funflow-poo-check-metadata
        poo-flow-funflow-poo-check->cicd-check
        poo-flow-funflow-poo-checks->cicd-checks
        poo-flow-funflow-poo-pipeline->check-map)

(def (poo-flow-funflow-require message ok? value)
  (if ok?
    (void)
    (error message value)))

(def (poo-flow-funflow-symbol-list? values)
  (cond
   ((null? values) #t)
   ((and (pair? values)
         (symbol? (car values)))
    (poo-flow-funflow-symbol-list? (cdr values)))
   (else #f)))

(def (poo-flow-funflow-optional-metadata/tail key value tail)
  (if value
    (cons (cons key value) tail)
    tail))

(def (poo-flow-funflow-list-metadata/tail key values tail)
  (if (null? values)
    tail
    (cons (cons key values) tail)))

(def (poo-flow-funflow-poo-check-metadata check)
  (let ((dependency-refs (.ref check 'dependency-refs))
        (metadata (.ref check 'metadata)))
    (poo-flow-funflow-require
     "funflow POO check dependency-refs must be a list of symbols"
     (poo-flow-funflow-symbol-list? dependency-refs)
     dependency-refs)
    (poo-flow-funflow-require
     "funflow POO check metadata must be an alist"
     (list? metadata)
     metadata)
    (cons (cons 'source 'funflow-poo-prototype)
          (cons (cons 'check (.ref check 'check-name))
                (cons (cons 'dependency-refs dependency-refs)
                      (poo-flow-funflow-optional-metadata/tail
                       'observability
                       (.ref check 'observability)
                       (poo-flow-funflow-optional-metadata/tail
                        'durable-task-id
                        (.ref check 'durable-task-id)
                        (poo-flow-funflow-optional-metadata/tail
                         'action-class
                         (.ref check 'action-class)
                         (poo-flow-funflow-list-metadata/tail
                          'compensation-refs
                          (.ref check 'compensation-refs)
                          (poo-flow-funflow-optional-metadata/tail
                           'artifact-retention
                           (.ref check 'artifact-retention)
                           (poo-flow-funflow-list-metadata/tail
                            'observes
                            (.ref check 'observes)
                            (poo-flow-funflow-list-metadata/tail
                             'guards
                             (.ref check 'guards)
                             (poo-flow-funflow-optional-metadata/tail
                              'report
                              (.ref check 'report)
                              metadata)))))))))))))

(def (poo-flow-funflow-poo-check->cicd-check check)
  (poo-flow-funflow-require
   "funflow config object must extend funflow-check"
   (poo-flow-funflow-poo-check? check)
   check)
  (poo-flow-cicd-check
   (.ref check 'check-name)
   (.ref check 'profile-ref)
   (.ref check 'command-vector)
   (.ref check 'input-bindings)
   (.ref check 'config-sources)
   (.ref check 'artifact-outputs)
   (.ref check 'cache-intents)
   (.ref check 'secret-requirements)
   (.ref check 'result-protocol)
   (.ref check 'runtime-mode)
   (poo-flow-funflow-poo-check-metadata check)))

(def (poo-flow-funflow-poo-checks->cicd-checks checks)
  (cond
   ((null? checks) '())
   ((pair? checks)
    (cons (poo-flow-funflow-poo-check->cicd-check (car checks))
          (poo-flow-funflow-poo-checks->cicd-checks (cdr checks))))
   (else
    (error "funflow POO pipeline checks slot must be a list" checks))))

(def (poo-flow-funflow-poo-pipeline->check-map pipeline)
  (poo-flow-funflow-require
   "funflow config object must extend funflow-pipeline"
   (poo-flow-funflow-poo-pipeline? pipeline)
   pipeline)
  (let ((pipeline-name (.ref pipeline 'pipeline-name))
        (metadata (.ref pipeline 'metadata)))
    (poo-flow-funflow-require
     "funflow POO pipeline metadata must be an alist"
     (list? metadata)
     metadata)
    (poo-flow-cicd-check-map
     pipeline-name
     (poo-flow-funflow-poo-checks->cicd-checks
      (.ref pipeline 'checks))
     (poo-flow-product-field-rows/tail
      metadata
      (source 'funflow-poo-config)
      (pipeline pipeline-name)))))
