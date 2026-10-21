;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: maintained Funflow Profiles consumed by thin user compositions.
;;; Invariant: commands are inert metadata; execution remains Python-owned.

(import (only-in :clan/poo/object .def .o)
        (only-in :core/module-system/schema/relations poo-flow-semantic-identity)
        (only-in :core/module-system/authoring/roles poo-flow-semantic-module)
        (only-in :core/profile-composition/profile-bundle
                 poo-flow-module-profiles
                 poo-flow-profile-export))

(export FunflowProfileModule
        GithubCIProfile
        PythonAnyioProfile
        WheelSmokeScenarioProfile
        PythonRuntimeCIScenarioProfile)

(.def GithubCIProfile
  (identity 'github-ci)
  (name 'github-ci)
  (module 'funflow)
  (runtime-executed? #f))

(.def PythonAnyioProfile
  (identity 'python-anyio)
  (name 'python-anyio)
  (module 'funflow)
  (runtime-executed? #f))

(def FunflowProfileModule
  (poo-flow-semantic-module
   (poo-flow-semantic-identity 'poo-flow 'funflow)
   profiles:
   (poo-flow-module-profiles
    (poo-flow-profile-export 'github-ci GithubCIProfile)
    (poo-flow-profile-export 'python-anyio PythonAnyioProfile))))

(.def WheelSmokeScenarioProfile
  (identity 'wheel-smoke-scenario)
  (name 'wheel-smoke-scenario)
  (module 'funflow)
  (stages
   (.o default:
       (.o steps:
           (.o build: (.o run: '("python" "-m" "build"))
               test: (.o run: '("python" "-m" "pytest" "-q")))
           edges: (.o build-test: '(build test))))))

(.def PythonRuntimeCIScenarioProfile
  (identity 'python-runtime-ci-scenario)
  (name 'python-runtime-ci-scenario)
  (module 'funflow)
  (stages
   (.o default:
       (.o steps:
           (.o build: (.o run: '("gxpkg" "build"))
               test: (.o run: '("gxtest" "t/unit-tests.ss"))
               package: (.o run: '("tar" "cf" "artifact.tar" "build")))
           edges:
           (.o build-test: '(build test)
               test-package: '(test package))))))
