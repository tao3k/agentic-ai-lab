;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: sandbox user-interface config keeps an owner-local benchmark.
;;; Invariant: benchmark payloads live under t/; user-interface declarations
;;; stay POO-native and never realize sandbox descriptors.

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
         (only-in :std/test
                 check-equal?
                 test-suite)
        (only-in :asp-gerbil-scheme/benchmark-api
                 benchmark-fixture-contract-pass?
                 benchmark-receipt-pass?
                 benchmark-run/result)
        (only-in :clan/poo/object .ref)
        "../user-interface-fixtures.ss"
        :agentic-ai-lab/modules/workflow/scenario/configuration/interface
        :agentic-ai-lab/modules/workflow/scenario/configuration/profile-config
        :agentic-ai-lab/modules/agent-sandbox/config)

(export user-interface-sandbox-config-performance-test)

;; : String
(def user-interface-sandbox-config-fixture-path
  "t/scenarios/performance/user-interface-sandbox-config/benchmark.ss")

;; : Alist
(def user-interface-sandbox-config-fixture
  (call-with-input-file user-interface-sandbox-config-fixture-path read))

;; : (-> Alist Symbol MaybeValue)
(def (user-interface-sandbox-config-ref row key)
  (let (entry (assoc key row))
    (and entry (cdr entry))))

;; : (-> Alist Void)
(def (user-interface-sandbox-config-display-receipt receipt)
  (display "[agentic-ai-lab-benchmark] user-interface-sandbox-config ")
  (write receipt)
  (newline)
  (force-output))

;; : (-> Alist)
(def (user-interface-sandbox-config-summary)
  (let* ((presentation
          (agentic-ai-lab-default-sandbox-profile-presentation))
         (nono-profile
          (agentic-ai-lab-sandbox-profile-by-name
           agentic-ai-lab-default-sandbox-profiles
           'agent/nono))
         (cube-profile
          (agentic-ai-lab-sandbox-profile-by-name
           agentic-ai-lab-default-sandbox-profiles
           'agent/cube))
         (docker-profile
          (agentic-ai-lab-sandbox-profile-by-name
           agentic-ai-lab-default-sandbox-profiles
           'agent/docker)))
    (list
     (cons 'profile-count (.ref presentation 'profile-count))
     (cons 'profile-names agentic-ai-lab-default-sandbox-profile-names)
     (cons 'nono-feature?
           (yuanxu-user-config-feature?
            test-agentic-ai-lab-user-config
            'sandbox
            'nono-sandbox
            '+nono
            '+doctor))
     (cons 'cube-feature?
           (yuanxu-user-config-feature?
            test-agentic-ai-lab-user-config
            'sandbox
            'cubeSandbox
            '+cube
            '+doctor))
     (cons 'docker-feature?
           (yuanxu-user-config-feature?
            test-agentic-ai-lab-user-config
            'sandbox
            'docker-sandbox
            '+docker
            '+doctor))
     (cons 'backend-kinds
           (list
            (agentic-ai-lab-sandbox-profile-backend-kind nono-profile)
            (agentic-ai-lab-sandbox-profile-backend-kind cube-profile)
            (agentic-ai-lab-sandbox-profile-backend-kind docker-profile)))
     (cons 'nono-resource-policy-count
           (length (agentic-ai-lab-sandbox-profile-resource-policy nono-profile)))
     (cons 'descriptor-realized? (.ref presentation 'descriptor-realized?))
     (cons 'runtime-executed (.ref presentation 'runtime-executed))
     (cons 'benchmark-surface 't/scenarios/performance)
     (cons 'user-interface-benchmark-payload? #f))))

;; : TestSuite
(def user-interface-sandbox-config-performance-test
  (test-suite "user-interface sandbox config performance"
    (yuanxu-test-case "keeps sandbox config projection inside benchmark contract"
      (let-values (((receipt summary)
                    (benchmark-run/result
                     user-interface-sandbox-config-fixture
                     user-interface-sandbox-config-summary)))
        (check-equal?
         (benchmark-fixture-contract-pass?
          user-interface-sandbox-config-fixture)
         #t)
        (check-equal?
         (user-interface-sandbox-config-ref summary 'profile-count)
         3)
        (check-equal?
         (user-interface-sandbox-config-ref summary 'profile-names)
         '(agent/nono agent/cube agent/docker))
        (check-equal?
         (user-interface-sandbox-config-ref summary 'nono-feature?)
         #t)
        (check-equal?
         (user-interface-sandbox-config-ref summary 'cube-feature?)
         #t)
        (check-equal?
         (user-interface-sandbox-config-ref summary 'docker-feature?)
         #t)
        (check-equal?
         (user-interface-sandbox-config-ref summary 'backend-kinds)
         '(nono cube docker))
        (check-equal?
         (user-interface-sandbox-config-ref
          summary
          'nono-resource-policy-count)
         4)
        (check-equal?
         (user-interface-sandbox-config-ref summary 'descriptor-realized?)
         #f)
        (check-equal?
         (user-interface-sandbox-config-ref summary 'runtime-executed)
         #f)
        (check-equal?
         (user-interface-sandbox-config-ref summary 'benchmark-surface)
         't/scenarios/performance)
        (check-equal?
         (user-interface-sandbox-config-ref
          summary
          'user-interface-benchmark-payload?)
         #f)
        (user-interface-sandbox-config-display-receipt receipt)
        (check-equal? (benchmark-receipt-pass? receipt) #t)))))
