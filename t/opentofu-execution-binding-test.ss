;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Pure Task preflight must precede publication and protect checked receivers.
(import :std/test :clan/poo/object
        (only-in :std/error Error? Error-message)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :agentic-ai-lab/modules/services/opentofu/execution NullExecution.))
(export opentofu-execution-binding-test)

;; The publication stub counts boundary calls; no process or artifact is built.
;; Real Provider authority and cleanup are checked by the service suites.
(def opentofu-execution-binding-test
  (test-suite "OpenTofu Task publication binding"
    (yuanxu-test-case "forward and cleanup command overrides refuse before approval"
      (def admissions 0)
      (def selected-provider (.o))
      (.def (Base base [NullExecution.])
        provider: selected-provider command: '("selected-tofu")
        publication:
        (.o value: base
            .publish: (lambda (_previous candidate)
                        (set! admissions (+ admissions 1))
                        (values #f candidate #f))))
      ;; Force the parent's method before deriving either rejected receiver.
      (.get Base .run)
      (.def (WrongTask @ Base)
        tasks: =>.+ (.o output: =>.+ (.o command: '("false"))))
      (.def (WrongCleanup @ Base)
        tasks: =>.+ (.o destroy: =>.+ (.o command: '("false"))))
      (for-each
        (lambda (recipe)
          (check-exception (.call recipe .run ".")
            (lambda (error)
              (and (Error? error)
                   (equal? (Error-message error)
                     "OpenTofu Task must use the selected execution and engine")))))
        (list WrongTask WrongCleanup))
      (check-equal? admissions 0))
    (yuanxu-test-case "a different validated receiver receives its own Task check"
      (def admissions 0)
      (def selected-provider (.o))
      (.def (Base base [NullExecution.])
        provider: selected-provider command: '("selected-tofu")
        publication: (.o value: base))
      (.def (Checked @ Base)
        tasks: =>.+ (.o output: =>.+ (.o command: '("false"))))
      (.def (Input @ Base)
        publication:
        (.cc (.get Base publication) '.publish
          (lambda (_previous _candidate)
            (set! admissions (+ admissions 1))
            (values #f Checked #f))))
      (check-exception (.call Input .run ".")
        (lambda (error)
          (and (Error? error)
               (equal? (Error-message error)
                 "OpenTofu Task must use the selected execution and engine"))))
      (check-equal? admissions 1))))
