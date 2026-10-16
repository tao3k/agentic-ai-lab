;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(export feature-system-bundle-v1-composition-writer-test-suite
        feature-system-bundle-v1-composition-writer-test)

(import (only-in :core/observability/testing-case poo-flow-test-case)
         :std/test
        :clan/poo/object
        :poo-flow/modules/workflow/control-plane/plan
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        :core/module-system/authoring/roles
        (only-in :poo-flow/modules/module-authoring/semantic-module UserConfigSourceRole. poo-flow-user-root-module-authoring-profile)
        :core/profile-composition/selection-syntax
        :poo-flow/modules/workflow/scenario/composition-syntax
        :core/profile-composition/profile-bundle
        :poo-flow/modules/workflow/scenario/bundle-v1-projection
        :core/feature-system/bundle-v1-lowering)

(.def WriterSourceProfile
  (identity 'source)
  (kind 'interface)
  (scope 'evidence)
  (guard '(all provenance attribution)))

(.def WriterTargetProfile
  (identity 'target)
  (kind 'authority)
  (scope 'action)
  (guard '(all verified authority)))

(def WriterTestModule
  (poo-flow-semantic-module
   (poo-flow-semantic-identity 'test 'writer)
   profiles:
   (poo-flow-module-profiles
    (poo-flow-profile-export 'source WriterSourceProfile)
    (poo-flow-profile-export 'target WriterTargetProfile))))

(.def WriterTestScenarioProfile
  (identity 'writer-test-flow)
  (stages
   (.o writer-test-flow:
       (.o guard: '(all (receipt source) (authority human))
           steps: (.o source: #t target: #t)
           edges: (.o source-target: '(source target))))))

(user-composition writer-test-composition
  (compose profiles
    (use-module WriterTestModule as writer source target)
    WriterTestScenarioProfile))

(def feature-system-bundle-v1-composition-writer-test-suite
  (test-suite
   "Bundle v1 composition writer"

   (poo-flow-test-case
    "arbitrary POO composition lowers with symbols and dependency edges"
    (let-values (((plan image)
                  (poo-flow-scenario-case->bundle-v1-image
                   writer-test-composition 'writer-test-bundle 3)))
      (let* ((descriptor (.ref image 'descriptor))
             (no-adapter (feature-bundle-v1-lower-compact-id
                          'adapter +feature-bundle-v1-no-adapter-id+))
             (no-projection (feature-bundle-v1-lower-compact-id
                             'projection +feature-bundle-v1-no-projection-id+))
             (no-policy (feature-bundle-v1-lower-compact-id
                         'policy 'poo-flow.policy.none)))
        (check (.ref image 'accepted?) => #t)
        (check (length (execution-plan-nodes plan)) => 4)
        (check (length (.ref descriptor 'symbol-rows)) => 7)
        (check
         (length
          (filter (lambda (symbol)
                    (= (.ref symbol 'symbol-kind) 2))
                  (.ref descriptor 'symbol-rows)))
         => 3)
        (check (length (.ref descriptor 'component-rows)) => 4)
        (check (length (.ref descriptor 'edge-rows)) => 4)
        (check
         (length
          (filter (lambda (component)
                    (not (feature-bundle-v1-compact-id=?
                          (.ref component 'policy-id)
                          no-policy)))
                  (.ref descriptor 'component-rows)))
         => 3)
        (for-each
         (lambda (component)
           (check
            (feature-bundle-v1-compact-id=?
             (.ref component 'adapter-id)
             no-adapter)
            => #t)
           (check
            (feature-bundle-v1-compact-id=?
             (.ref component 'projection-id)
             no-projection)
            => #t))
         (.ref descriptor 'component-rows))
        (check (.ref descriptor 'bundle-epoch) => 3))))))

(def feature-system-bundle-v1-composition-writer-test
  feature-system-bundle-v1-composition-writer-test-suite)
