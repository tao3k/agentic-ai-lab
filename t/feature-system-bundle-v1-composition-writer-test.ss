;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(export feature-system-bundle-v1-composition-writer-test-suite
        feature-system-bundle-v1-composition-writer-test)

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        :yuanxu/modules/funflow/control-plane/graph
        (only-in :yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        :yuanxu/module-system/authoring/roles
        (only-in :agentic-ai-lab/modules/module-authoring/semantic-module UserConfigSourceRole. agentic-ai-lab-user-root-module-authoring-profile)
        :yuanxu/profile-composition/selection-syntax
        :agentic-ai-lab/modules/workflow/scenario/composition-syntax
        :yuanxu/profile-composition/profile-bundle
        :agentic-ai-lab/modules/workflow/scenario/bundle-v1-projection
        :yuanxu/feature-system/bundle-v1-lowering)

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
  (yuanxu-semantic-module
   (yuanxu-semantic-identity 'test 'writer)
   profiles:
   (yuanxu-module-profiles
    (yuanxu-profile-export 'source WriterSourceProfile)
    (yuanxu-profile-export 'target WriterTargetProfile))))

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

   (yuanxu-test-case
    "arbitrary POO composition lowers with symbols and dependency edges"
    (let-values (((plan image)
                  (agentic-ai-lab-scenario-case->bundle-v1-image
                   writer-test-composition 'writer-test-bundle 3)))
      (let* ((descriptor (.ref image 'descriptor))
             (no-adapter (feature-bundle-v1-lower-compact-id
                          'adapter +feature-bundle-v1-no-adapter-id+))
             (no-projection (feature-bundle-v1-lower-compact-id
                             'projection +feature-bundle-v1-no-projection-id+))
             (no-policy (feature-bundle-v1-lower-compact-id
                         'policy 'agentic-ai-lab.policy.none)))
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
