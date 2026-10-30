;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: Funflow functional DAG objects are POO-native reports.
;;; Invariant: DAG construction is pure and never schedules or runs checks.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/modules/funflow/config-prototypes funflow-check funflow-pipeline)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :clan/poo/object .ref)
        (only-in :yuanxu/module-system/selection/objects
                 yuanxu-user-module-selection-flags)
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :agentic-ai-lab/modules/workflow/scenario/configuration/init-syntax
        (only-in :yuanxu/modules/funflow/graph-projection
                 yuanxu-funflow-check-map->functional-dag
                 yuanxu-funflow-composition-step?
                 yuanxu-funflow-composition-step->alist
                 yuanxu-funflow-dag-edge?
                 yuanxu-funflow-dag-edge->alist
                 yuanxu-funflow-functional-dag?
                 yuanxu-funflow-functional-dag->alist))

(export funflow-functional-dag-test)

;; : (-> List Symbol Object)
(def (funflow-functional-dag-alist-ref alist key)
  (match alist
    ([[(? symbol? row-key) . row-value] . rest]
     (if (eq? row-key key)
       row-value
       (funflow-functional-dag-alist-ref rest key)))
    ([_ . rest]
     (funflow-functional-dag-alist-ref rest key))
    (else #f)))

;; : (-> Unit [PooUserModuleSelection])
(def (funflow-functional-dag-selection)
  (use-module funflow
    :config
    (.def (funflow-dag/build @ funflow-check
                             check-name profile-ref command-vector
                             artifact-outputs result-protocol runtime-mode)
      check-name: 'build
      profile-ref: 'ci/build
      command-vector: '("gerbil" "build")
      artifact-outputs: '(build-log)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff)

    (.def (funflow-dag/test @ funflow-check
                            check-name profile-ref command-vector
                            artifact-outputs result-protocol runtime-mode
                            dependency-refs)
      check-name: 'test
      profile-ref: 'ci/check
      command-vector: '("gerbil" "env" "./unit-tests.ss")
      artifact-outputs: '(test-receipt)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff
      dependency-refs: '(build))

    (.def (funflow-dag/package @ funflow-check
                               check-name profile-ref command-vector
                               artifact-outputs result-protocol runtime-mode
                               dependency-refs)
      check-name: 'package
      profile-ref: 'ci/check
      command-vector: '("gerbil" "env" "./unit-tests.ss")
      artifact-outputs: '(package-receipt)
      result-protocol: '(read :lines)
      runtime-mode: 'manifest-handoff
      dependency-refs: '(test))

    (.def (funflow-dag/default @ funflow-pipeline
                               pipeline-name checks metadata)
      pipeline-name: 'default
      checks: (list funflow-dag/build
                    funflow-dag/test
                    funflow-dag/package)
      metadata: '((scenario . funflow-functional-dag)
                  (authoring-style . gerbil-poo-native)))))

;; : TestSuite
(def funflow-functional-dag-test
  (test-suite "funflow functional DAG object"
    (yuanxu-test-case "projects a POO pipeline into a POO functional DAG"
      (let* ((selection (car (funflow-functional-dag-selection)))
             (pipeline
              (funflow-functional-dag-alist-ref
               (yuanxu-user-module-selection-flags selection)
               ':workflow-pipeline))
             (dag (yuanxu-funflow-check-map->functional-dag pipeline))
             (composition-steps (.ref dag 'composition-steps))
             (first-composition-step (car composition-steps))
             (first-bind-step (car (cdddr composition-steps)))
             (edges (.ref dag 'edges))
             (first-edge (car edges))
             (row (yuanxu-funflow-functional-dag->alist dag))
             (row-composition-steps
              (funflow-functional-dag-alist-ref row 'composition-steps))
             (row-first-composition-step (car row-composition-steps))
             (row-first-bind-step (car (cdddr row-composition-steps)))
             (row-edges (funflow-functional-dag-alist-ref row 'edges))
             (row-first-edge (car row-edges)))
        (check-equal? (yuanxu-funflow-functional-dag? dag) #t)
        (check-equal? (.ref dag 'composition-style) 'arrow-kleisli)
        (check-equal? (.ref dag 'composition-step-count) 5)
        (check-equal? (.ref dag 'nodes) '(build test package))
        (check-equal? (.ref dag 'edge-count) 2)
        (check-equal? (.ref dag 'entry-nodes) '(build))
        (check-equal? (.ref dag 'terminal-nodes) '(package))
        (check-equal? (.ref dag 'ready-order) '(build test package))
        (check-equal? (.ref dag 'valid?) #t)
        (check-equal? (.ref dag 'runtime-executed) #f)
        (check-equal? (yuanxu-funflow-composition-step?
                       first-composition-step)
                      #t)
        (check-equal? (.ref first-composition-step 'step-kind)
                      'arrow-node)
        (check-equal? (.ref first-composition-step 'check-name)
                      'build)
        (check-equal? (.ref first-composition-step 'composition-style)
                      'arrow)
        (check-equal? (.ref first-bind-step 'step-kind)
                      'kleisli-bind)
        (check-equal? (.ref first-bind-step 'from) 'build)
        (check-equal? (.ref first-bind-step 'to) 'test)
        (check-equal? (.ref first-bind-step 'composition-style)
                      'kleisli)
        (check-equal? (funflow-functional-dag-alist-ref
                       (yuanxu-funflow-composition-step->alist
                        first-composition-step)
                       'kind)
                      'yuanxu.funflow.composition-step.prototype)
        (check-equal? (yuanxu-funflow-dag-edge? first-edge) #t)
        (check-equal? (.ref first-edge 'from) 'build)
        (check-equal? (.ref first-edge 'to) 'test)
        (check-equal? (funflow-functional-dag-alist-ref
                       (yuanxu-funflow-dag-edge->alist first-edge)
                       'composition-style)
                      'kleisli)
        (check-equal? (funflow-functional-dag-alist-ref row 'kind)
                      'yuanxu.funflow.functional-dag.prototype)
        (check-equal? (funflow-functional-dag-alist-ref
                       row
                       'composition-step-count)
                      5)
        (check-equal? (funflow-functional-dag-alist-ref
                       row-first-composition-step
                       'step-kind)
                      'arrow-node)
        (check-equal? (funflow-functional-dag-alist-ref
                       row-first-bind-step
                       'step-kind)
                      'kleisli-bind)
        (check-equal? (funflow-functional-dag-alist-ref row 'runtime-owner)
                      "marlin-agent-core")
        (check-equal? (funflow-functional-dag-alist-ref row-first-edge 'from)
                      'build)))))
