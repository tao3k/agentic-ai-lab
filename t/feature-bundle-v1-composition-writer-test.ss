;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(export feature-bundle-v1-composition-writer-test)

(import (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
         :std/test
        :clan/poo/object
        (only-in :clan/poo/mop .new TypeError?)
        (only-in :clan/poo/type Record Symbol)
        (only-in :tao3k/yuanxu/modules/funflow/scenario Scenario)
        :tao3k/yuanxu/modules/funflow/control-plane/graph
        (only-in :tao3k/yuanxu/module-system/schema/relations yuanxu-semantic-identity)
        :tao3k/yuanxu/module-system/authoring/roles
        (only-in :agentic-ai-lab/modules/module-authoring/semantic-module UserConfigSourceRole. agentic-ai-lab-user-root-module-authoring-profile)
        :tao3k/yuanxu/profile-composition/selection-syntax

        :tao3k/yuanxu/profile-composition/profile-bundle
        :tao3k/yuanxu/modules/funflow/bundle-v1
        :tao3k/yuanxu/module-system/feature/bundle-v1-lowering)

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

(def writer-test-composition
  (.new Scenario name: 'writer-test-composition
        config: (compose profiles
    (use-module WriterTestModule as writer source target)
    WriterTestScenarioProfile)))

(def feature-bundle-v1-composition-writer-test
  (test-suite
   "Bundle v1 composition writer"

   (yuanxu-test-case
    "arbitrary POO composition lowers with symbols and dependency edges"
    (let-values (((plan image)
                  (scenario->bundle-v1-image
                   writer-test-composition 'writer-test-bundle 3)))
      (let* ((descriptor (.ref image 'descriptor))
             (no-adapter (feature-bundle-v1-lower-compact-id
                          'adapter +feature-bundle-v1-no-adapter-id+))
             (no-projection (feature-bundle-v1-lower-compact-id
                             'projection +feature-bundle-v1-no-projection-id+))
             (no-policy (feature-bundle-v1-lower-compact-id
                         'policy 'yuanxu.funflow.policy.none)))
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
        (check (.ref descriptor 'bundle-epoch) => 3)
        (check (eq? plan (.ref writer-test-composition 'execution-plan)) => #t))))

   (yuanxu-test-case
    "Bundle projection uses the child's final plan after the parent is cached"
    (def parent-plan (.ref writer-test-composition 'execution-plan))
    (def child (.o (:: @ writer-test-composition) name: 'child-writer))
    (let-values (((plan image)
                  (scenario->bundle-v1-image
                   child 'child-bundle 4)))
      (check (execution-plan-flow-name plan) => 'child-writer)
      (check (eq? plan (.ref child 'execution-plan)) => #t)
      (check (eq? parent-plan (.ref writer-test-composition 'execution-plan)) => #t)
      (check (execution-plan-flow-name parent-plan) => 'writer-test-composition)))

   (yuanxu-test-case
    "Bundle projection preserves the derived Record's obligations"
    (def Restricted (Record [Scenario] marker: [Symbol constant: 'allowed]))
    (def denied (.new Restricted name: 'denied
                      config: (.ref writer-test-composition 'config)
                      marker: 'denied))
    (check-exception
     (scenario->bundle-v1-image denied 'denied-bundle 1)
     TypeError?))))
