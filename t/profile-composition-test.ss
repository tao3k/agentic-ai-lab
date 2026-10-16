;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test check-equal? check-exception test-suite)
        (only-in :clan/poo/object .all-slots .def .o .ref object?)
        (only-in :clan/poo/mop element?)
        (only-in :poo-flow/modules/workflow/control-plane/plan execution-plan? execution-plan-nodes)
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        (only-in :core/module-system/authoring/roles poo-flow-semantic-module)
        :core/profile-composition/selection-syntax
        :poo-flow/modules/workflow/scenario/composition-syntax
        :core/profile-composition/profile-bundle)

(export profile-composition-test)

(.def BoundedProfile
  (identity 'bounded))

(def NativeProfileModule
  (poo-flow-semantic-module
   (poo-flow-semantic-identity 'test 'native-profile-module)
   profiles:
   (poo-flow-module-profiles
    (poo-flow-profile-export 'bounded BoundedProfile))))

(.def BaseStageProfile
  (identity 'base-stage)
  (stages
   (.o production:
       (.o graph: 'base-graph
           proofs: (.o base-proof: #t)))))

(.def (ReviewedStageProfile @ BaseStageProfile)
  (identity 'reviewed-stage)
  (stages =>.+
          (.o production: =>.+
              (.o proofs: =>.+
                  (.o review-proof: #t)))))

(.def DataStageProfile
  (identity 'data-stage)
  (stages (.o preview: 'maintained-preview)))

(user-composition native-composition
  (compose profiles
    (use-module NativeProfileModule bounded)
    ReviewedStageProfile
    DataStageProfile))

(def profile-composition-test
  (test-suite
   "native POO Profile composition"
   (poo-flow-test-case "Stage space and nested Stage values inherit through slot algebra"
     (let* ((stage-space (.ref native-composition 'stages))
            (production (.ref stage-space 'production))
            (proofs-value (.ref production 'proofs)))
       (check-equal? (object? stage-space) #t)
       (check-equal? (.all-slots stage-space) '(preview production))
       (check-equal? (.ref production 'graph) 'base-graph)
       (check-equal? (.ref proofs-value 'base-proof) #t)
       (check-equal? (.ref proofs-value 'review-proof) #t)
       (check-equal? (.ref stage-space 'preview) 'maintained-preview)))
   (poo-flow-test-case "ordinary data Stage values and advanced POO values share one Contract"
     (check-equal? (element? PooFlowStageSpace
                            (.ref native-composition 'stages))
                   #t)
     (check-exception
      (poo-flow-profile-bundle '() '() '() '() '() '()
                               (.o invalid: (lambda () #t))
                               '() '())
      true))
   (poo-flow-test-case "closed composition projects one canonical plan"
     (let (plan (.ref native-composition 'execution-plan))
       (check-equal? (execution-plan? plan) #t)
       (check-equal? (length (execution-plan-nodes plan)) 3)))))
