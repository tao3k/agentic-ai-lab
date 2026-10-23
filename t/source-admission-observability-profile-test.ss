;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test test-suite check-equal?)
        (only-in :clan/poo/object .o .ref)
        (only-in :agentic-ai-lab/dev/modules/testing/source-admission
                 agentic-ai-lab-source-admission-observability-profile-prototype
                 agentic-ai-lab-source-admission-observability-profile?))

(export source-admission-observability-profile-test)

(def source-admission-observability-profile-test
  (test-suite "POO source-admission observability Profile"
    (yuanxu-test-case "module scope is declared as POO slots"
      (let (profile
            (.o (:: @ agentic-ai-lab-source-admission-observability-profile-prototype)
                (identity 'lambda-episteme/sdlc-source-admission)
                (owner 'lambda-episteme)
                (module 'sdlc)
                (emit-summary? #t)
                (emit-diagnostics? #f)))
        (check-equal?
         (agentic-ai-lab-source-admission-observability-profile? profile) #t)
        (check-equal? (.ref profile 'owner) 'lambda-episteme)
        (check-equal? (.ref profile 'module) 'sdlc)
        (check-equal? (.ref profile 'emit-diagnostics?) #f)))))
