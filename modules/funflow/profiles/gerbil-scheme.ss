;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Native default Profile construction, with no import of the publishing scope.
(import :core/profile-composition/selection-syntax
        (only-in :clan/poo/object .o .get))
(export make-gerbil-scheme-ci-profile)

(def (make-gerbil-scheme-ci-profile prototype-scope)
  (use-module prototype-scope as ff
    (.o
      build:
      (.o (:: @ (.get ff prototypes check))
        check-name: 'build
        profile-ref: 'ci/build
        command-vector: '("gerbil" "build")
        artifact-outputs: '(build-log)
        cache-intents: '(gerbil-build-cache)
        result-protocol: '(read :lines)
        runtime-mode: 'manifest-handoff
        durable-task-id: 'task/build
        action-class: 'idempotent
        artifact-retention: 'project-retained)

      test:
      (.o (:: @ (.get ff prototypes check))
        check-name: 'test
        profile-ref: 'ci/check
        command-vector: '("gerbil" "env" "./unit-tests.ss")
        artifact-outputs: '(test-receipt)
        result-protocol: '(read :lines)
        runtime-mode: 'manifest-handoff
        dependency-refs: '(build)
        durable-task-id: 'task/test
        action-class: 'idempotent)

      package:
      (.o (:: @ (.get ff prototypes check))
        check-name: 'package
        profile-ref: 'ci/check
        command-vector: '("gerbil" "env" "./unit-tests.ss")
        artifact-outputs: '(dependency-graph-receipt)
        result-protocol: '(read :lines)
        runtime-mode: 'manifest-handoff
        dependency-refs: '(test)
        durable-task-id: 'task/package
        action-class: 'compensatable
        compensation-refs: '(cleanup/package-artifacts)
        artifact-retention: 'release-retained)

      pipeline:
      (.o (:: @ (.get ff prototypes pipeline))
        pipeline-name: 'default
        checks: (list build test package)
        metadata: '((scenario . funflow-cicd)
                    (authoring-style . gerbil-poo-native))))))
