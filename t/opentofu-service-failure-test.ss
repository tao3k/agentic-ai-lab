;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; A command failure retains its primary exception after real destroy.
(import :std/test :clan/poo/object
        (only-in :yuanxu/observability/testing-case yuanxu-test-case yuanxu-test-checkpoint)
        (only-in "./qualification/opentofu/service.ss" call-with-service rejects? empty-state?))
(export opentofu-service-failure-test)

;; This failure owns its own selection; another test cannot inherit its state.
(def opentofu-service-failure-test
  (test-suite "OpenTofu service command failure"
    (yuanxu-test-case "failed output propagates after destroy"
      (call-with-service
        (lambda (fixture)
          (def prepared (.call fixture .prepare))
          (def Null (.get prepared recipe))
          (def failed (.call fixture .workspace "failed-output"))
          (.def (FailedOutput @ Null)
            tasks: =>.+ (.o output: =>.+ (.o arguments: '("not-an-opentofu-command"))))
          (yuanxu-test-checkpoint 'opentofu-failed-output-cleanup)
          (check-equal? (rejects? "Ops script failed"
                          (lambda () (.call FailedOutput .run failed))) #t)
          (check-equal? (empty-state? failed) #t)
          (displayln "OPENTOFU-SERVICE-FAILURE-OK"))))))
