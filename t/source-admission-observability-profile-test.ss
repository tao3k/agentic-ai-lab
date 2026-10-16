;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :core/observability/testing-case poo-flow-test-case)
         (only-in :std/test test-suite check-equal?)
        (only-in :clan/poo/object .o .ref)
        (only-in :poo-flow/modules/testing/source-admission
                 poo-flow-source-admission-observability-profile-prototype
                 poo-flow-source-admission-observability-profile?))

(export source-admission-observability-profile-test)

(def source-admission-observability-profile-test
  (test-suite "POO source-admission observability Profile"
    (poo-flow-test-case "module scope is declared as POO slots"
      (let (profile
            (.o (:: @ poo-flow-source-admission-observability-profile-prototype)
                (identity 'lambda-episteme/sdlc-source-admission)
                (owner 'lambda-episteme)
                (module 'sdlc)
                (emit-summary? #t)
                (emit-diagnostics? #f)))
        (check-equal?
         (poo-flow-source-admission-observability-profile? profile) #t)
        (check-equal? (.ref profile 'owner) 'lambda-episteme)
        (check-equal? (.ref profile 'module) 'sdlc)
        (check-equal? (.ref profile 'emit-diagnostics?) #f)))))
