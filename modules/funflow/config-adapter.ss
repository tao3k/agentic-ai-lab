;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: adapts module configuration into Funflow and CI/CD POO projections.
;;; Invariant: adapters reuse module contracts and do not execute workflow effects.
(import (only-in :clan/poo/object .ref)
        :tao3k/yuanxu/module-system/selection/objects
        :tao3k/yuanxu/utilities/final-projection-syntax
        :tao3k/agentic-ai-lab/modules/funflow/check-types
        :tao3k/agentic-ai-lab/modules/funflow/check-objects
        :tao3k/agentic-ai-lab/modules/funflow/config-prototypes
)

(export yuanxu-funflow-require
        yuanxu-funflow-symbol-list?
        yuanxu-funflow-optional-metadata/tail
        yuanxu-funflow-list-metadata/tail
        yuanxu-funflow-poo-check-metadata
        yuanxu-funflow-poo-check->cicd-check
        yuanxu-funflow-poo-checks->cicd-checks
        yuanxu-funflow-poo-pipeline->check-map)

(def (yuanxu-funflow-require message ok? value)
  (if ok?
    (void)
    (error message value)))

(def (yuanxu-funflow-symbol-list? values)
  (cond
   ((null? values) #t)
   ((and (pair? values)
         (symbol? (car values)))
    (yuanxu-funflow-symbol-list? (cdr values)))
   (else #f)))

(def (yuanxu-funflow-optional-metadata/tail key value tail)
  (if value
    (cons (cons key value) tail)
    tail))

(def (yuanxu-funflow-list-metadata/tail key values tail)
  (if (null? values)
    tail
    (cons (cons key values) tail)))

(def (yuanxu-funflow-poo-check-metadata check)
  (let ((dependency-refs (.ref check 'dependency-refs))
        (metadata (.ref check 'metadata)))
    (yuanxu-funflow-require
     "funflow POO check dependency-refs must be a list of symbols"
     (yuanxu-funflow-symbol-list? dependency-refs)
     dependency-refs)
    (yuanxu-funflow-require
     "funflow POO check metadata must be an alist"
     (list? metadata)
     metadata)
    (cons (cons 'source 'funflow-poo-prototype)
          (cons (cons 'check (.ref check 'check-name))
                (cons (cons 'dependency-refs dependency-refs)
                      (yuanxu-funflow-optional-metadata/tail
                       'observability
                       (.ref check 'observability)
                       (yuanxu-funflow-optional-metadata/tail
                        'durable-task-id
                        (.ref check 'durable-task-id)
                        (yuanxu-funflow-optional-metadata/tail
                         'action-class
                         (.ref check 'action-class)
                         (yuanxu-funflow-list-metadata/tail
                          'compensation-refs
                          (.ref check 'compensation-refs)
                          (yuanxu-funflow-optional-metadata/tail
                           'artifact-retention
                           (.ref check 'artifact-retention)
                           (yuanxu-funflow-list-metadata/tail
                            'observes
                            (.ref check 'observes)
                            (yuanxu-funflow-list-metadata/tail
                             'guards
                             (.ref check 'guards)
                             (yuanxu-funflow-optional-metadata/tail
                              'report
                              (.ref check 'report)
                              metadata)))))))))))))

(def (yuanxu-funflow-poo-check->cicd-check check)
  (yuanxu-funflow-require
   "funflow config object must extend funflow-check"
   (yuanxu-funflow-poo-check? check)
   check)
  (yuanxu-cicd-check
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
   (yuanxu-funflow-poo-check-metadata check)))

(def (yuanxu-funflow-poo-checks->cicd-checks checks)
  (cond
   ((null? checks) '())
   ((pair? checks)
    (cons (yuanxu-funflow-poo-check->cicd-check (car checks))
          (yuanxu-funflow-poo-checks->cicd-checks (cdr checks))))
   (else
    (error "funflow POO pipeline checks slot must be a list" checks))))

(def (yuanxu-funflow-poo-pipeline->check-map pipeline)
  (yuanxu-funflow-require
   "funflow config object must extend funflow-pipeline"
   (yuanxu-funflow-poo-pipeline? pipeline)
   pipeline)
  (let ((pipeline-name (.ref pipeline 'pipeline-name))
        (metadata (.ref pipeline 'metadata)))
    (yuanxu-funflow-require
     "funflow POO pipeline metadata must be an alist"
     (list? metadata)
     metadata)
    (yuanxu-cicd-check-map
     pipeline-name
     (yuanxu-funflow-poo-checks->cicd-checks
      (.ref pipeline 'checks))
     (yuanxu-product-field-rows/tail
      metadata
      (source 'funflow-poo-config)
      (pipeline pipeline-name)))))
