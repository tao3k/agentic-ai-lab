;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test test-suite test-case check-equal? check-exception)
        :core/object-syntax/path-slots
        :core/profile-composition/selection-syntax
        (only-in :core/module-system/source/objects make-poo-flow-module-local-source)
        (only-in :clan/poo/object .get .ref .ref/cached .slot?)
        (only-in :poo-flow/modules/funflow/config-adapter
                 poo-flow-funflow-poo-pipeline->check-map)
        (only-in :poo-flow/modules/workflow/objects
                 poo-flow-cicd-check-map-name poo-flow-cicd-check-map-checks
                 poo-flow-cicd-check-compensation-refs)
        (only-in :poo-flow/modules/funflow/native-scope
                 FunflowModule. Funflow make-funflow-scope)
        (only-in :poo-flow/modules/funflow/config-prototypes
                 funflow-check funflow-pipeline
                 poo-flow-funflow-poo-check? poo-flow-funflow-poo-pipeline?))
(export funflow-native-publication-test)

(def (profile scope) (.get scope profiles gerbil-scheme))
(def (check-values check slots) (map (lambda (slot) (.ref check slot)) slots))
(def (artifacts checks) (map (lambda (check) (.get check artifact-outputs)) checks))

(def funflow-native-publication-test
  (test-suite "Funflow local native publication"
    (test-case "prototypes are available without constructing a Profile"
      (def profile-demands 0)
      (.def (Scope @ FunflowModule.)
        source: (make-poo-flow-module-local-source "test/funflow")
        profiles: (begin (set! profile-demands (+ profile-demands 1))
                         (error "unexpected Profile demand")))
      (check-equal? (use-module Scope as ff (eq? (.get ff prototypes check) funflow-check)) #t)
      (check-equal? (eq? (.get Scope prototypes pipeline) funflow-pipeline) #t)
      (check-equal? profile-demands 0))

    (test-case "Profile construction leaves Check and Pipeline prototype slots lazy"
      (def check-demands 0)
      (def pipeline-demands 0)
      (.def (Scope @ FunflowModule.)
        source: (make-poo-flow-module-local-source "test/funflow")
        prototypes:
        (.o check: (begin (set! check-demands (+ check-demands 1)) funflow-check)
            pipeline: (begin (set! pipeline-demands (+ pipeline-demands 1)) funflow-pipeline)))
      (def catalog (.get Scope profiles))
      (check-equal? (.ref/cached catalog 'gerbil-scheme) #f)
      (def selected (use-module Scope as ff (.get ff profiles gerbil-scheme)))
      (check-equal? (list check-demands pipeline-demands) '(0 0))
      (check-equal? (eq? selected (profile Scope)) #t)
      (check-equal? (.get selected build check-name) 'build)
      (check-equal? (list check-demands pipeline-demands) '(1 0))
      (check-equal? (.ref/cached selected 'test) #f)
      (check-equal? (.ref/cached selected 'package) #f)
      (check-equal? (.get selected pipeline pipeline-name) 'default)
      (check-equal? (list check-demands pipeline-demands) '(1 1))
      (check-equal? (.ref/cached (.get selected pipeline) 'checks) #f))

    (test-case "source and prototype identities survive the bounded upstream view"
      (def handle (make-poo-flow-module-local-source "test/custom-funflow"))
      (def Scope (make-funflow-scope handle))
      (def view (.get Scope prototype-scope))
      (check-equal? (eq? (.get Scope source) handle) #t)
      (check-equal? (eq? (.get view source) handle) #t)
      (check-equal? (eq? (.get view prototypes) (.get Scope prototypes)) #t)
      (check-equal? (use-module view as ff (eq? (.get ff prototypes check) funflow-check)) #t)
      (.def Project funflow: (use-module Scope as ff (.o (:: @ ff))))
      (check-equal? (eq? (.get Project funflow source) handle) #t)
      (check-exception (make-funflow-scope 'not-a-source-ref) true))

    (test-case "prototype-only view fails self-Profile access without recursive loading"
      (def Scope (make-funflow-scope (make-poo-flow-module-local-source "test/self")))
      (def view (.get Scope prototype-scope))
      (check-equal? (.slot? view 'profiles) #f)
      (check-exception
        (use-module view as ff (.get ff profiles gerbil-scheme)) true)
      (check-equal? (.ref/cached Scope 'profiles) #f)
      ;; Failed forbidden lookup neither publishes a partial Profile nor poisons it.
      (check-equal? (.get Scope profiles gerbil-scheme build check-name) 'build))

    (test-case "all original Check and Pipeline defaults are published"
      (def selected (profile (make-funflow-scope
                              (make-poo-flow-module-local-source "test/defaults"))))
      (check-equal?
        (check-values (.get selected build)
          '(check-name profile-ref command-vector artifact-outputs cache-intents
            result-protocol runtime-mode durable-task-id action-class artifact-retention))
        '(build ci/build ("gerbil" "build") (build-log) (gerbil-build-cache)
          (read :lines) manifest-handoff task/build idempotent project-retained))
      (check-equal?
        (check-values (.get selected test)
          '(check-name profile-ref command-vector artifact-outputs result-protocol
            runtime-mode dependency-refs durable-task-id action-class))
        '(test ci/check ("gerbil" "env" "./unit-tests.ss") (test-receipt)
          (read :lines) manifest-handoff (build) task/test idempotent))
      (check-equal?
        (check-values (.get selected package)
          '(check-name profile-ref command-vector artifact-outputs result-protocol
            runtime-mode dependency-refs durable-task-id action-class
            compensation-refs artifact-retention))
        '(package ci/check ("gerbil" "env" "./unit-tests.ss") (dependency-graph-receipt)
          (read :lines) manifest-handoff (test) task/package compensatable
          (cleanup/package-artifacts) release-retained))
      (check-equal? (.get selected pipeline pipeline-name) 'default)
      (check-equal? (.get selected pipeline metadata)
                    '((scenario . funflow-cicd) (authoring-style . gerbil-poo-native)))
      (check-equal? (map poo-flow-funflow-poo-check? (.get selected pipeline checks)) '(#t #t #t))
      (check-equal? (poo-flow-funflow-poo-pipeline? (.get selected pipeline)) #t)
      (check-equal? (.get selected test cache-intents) '())
      (check-equal? (.get selected pipeline runtime-executed) #f))

    (test-case "four path refinements read effective Checks after the parent is cached"
      (def handle (make-poo-flow-module-local-source "test/release"))
      (def Scope (make-funflow-scope handle))
      (.def Project funflow: (use-module Scope as ff (.o (:: @ ff))))
      (def parent-pipeline (.get Project funflow profiles gerbil-scheme pipeline))
      (def parent-checks (.get parent-pipeline checks))
      (.def (Release @ Project)
        funflow.profiles.gerbil-scheme.build: =>.+
        {cache-intents: '(project-gerbil-cache) artifact-outputs: '(release-build-log)}
        funflow.profiles.gerbil-scheme.test: =>.+
        {command-vector: '("gerbil" "env" "./project-tests.ss")
         artifact-outputs: '(release-test-receipt)}
        funflow.profiles.gerbil-scheme.package: =>.+
        {command-vector: '("gerbil" "build" "release") artifact-outputs: '(release-bundle)}
        funflow.profiles.gerbil-scheme.pipeline: =>.+ {pipeline-name: 'release-ci})
      (def effective (.get Release funflow profiles gerbil-scheme))
      (def final-pipeline (.get effective pipeline))
      (def final-checks (.get final-pipeline checks))
      (check-equal? (.get final-pipeline pipeline-name) 'release-ci)
      (check-equal? (artifacts final-checks)
                    '((release-build-log) (release-test-receipt) (release-bundle)))
      (check-equal? (map eq? final-checks
                       (list (.get effective build) (.get effective test) (.get effective package)))
                    '(#t #t #t))
      (check-equal? (.get effective build cache-intents) '(project-gerbil-cache))
      (check-equal? (.get effective test command-vector) '("gerbil" "env" "./project-tests.ss"))
      (check-equal? (.get effective package command-vector) '("gerbil" "build" "release"))
      (check-equal? (.get effective package compensation-refs) '(cleanup/package-artifacts))
      (check-equal? (eq? (.get Release funflow source) handle) #t)
      (check-equal? (eq? final-checks (.get Release funflow profiles gerbil-scheme pipeline checks)) #t)
      (check-equal? (eq? parent-pipeline (.get Project funflow profiles gerbil-scheme pipeline)) #t)
      (check-equal? (eq? parent-checks (.get parent-pipeline checks)) #t)
      (check-equal? (artifacts parent-checks)
                    '((build-log) (test-receipt) (dependency-graph-receipt)))
      (.def (Sibling @ Project)
        funflow.profiles.gerbil-scheme.build: =>.+ {artifact-outputs: '(sibling-log)})
      (check-equal? (artifacts (.get Sibling funflow profiles gerbil-scheme pipeline checks))
                    '((sibling-log) (test-receipt) (dependency-graph-receipt)))
      (check-equal? (artifacts final-checks)
                    '((release-build-log) (release-test-receipt) (release-bundle))))

    (test-case "existing list adapter projects the effective child values"
      (.def Project funflow: (use-module Funflow as ff (.o (:: @ ff))))
      (def parent-checks (.get Project funflow profiles gerbil-scheme pipeline checks))
      (.def (Release @ Project)
        funflow.profiles.gerbil-scheme.build: =>.+ {artifact-outputs: '(release-build-log)}
        funflow.profiles.gerbil-scheme.test: =>.+ {artifact-outputs: '(release-test-receipt)}
        funflow.profiles.gerbil-scheme.package: =>.+ {artifact-outputs: '(release-bundle)}
        funflow.profiles.gerbil-scheme.pipeline: =>.+ {pipeline-name: 'release-ci})
      (def projected
        (poo-flow-funflow-poo-pipeline->check-map
          (.get Release funflow profiles gerbil-scheme pipeline)))
      (check-equal? (poo-flow-cicd-check-map-name projected) 'release-ci)
      (def projected-checks (poo-flow-cicd-check-map-checks projected))
      (check-equal? (artifacts projected-checks)
                    '((release-build-log) (release-test-receipt) (release-bundle)))
      (check-equal? (poo-flow-cicd-check-compensation-refs (caddr projected-checks))
                    '(cleanup/package-artifacts))
      (check-equal? (artifacts parent-checks)
                    '((build-log) (test-receipt) (dependency-graph-receipt))))

    (test-case "published Profile remains independently reusable"
      (def Base (use-module Funflow as ff (.get ff profiles gerbil-scheme)))
      (def parent-checks (.get Base pipeline checks))
      (.def (Custom @ Base) build: =>.+ {artifact-outputs: '(custom-build)})
      (check-equal? (artifacts (.get Custom pipeline checks))
                    '((custom-build) (test-receipt) (dependency-graph-receipt)))
      (check-equal? (eq? parent-checks (.get Base pipeline checks)) #t))))
