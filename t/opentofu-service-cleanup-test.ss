;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Source expiry, cleanup and source revalidation share one process/scope.
(import :std/test :clan/poo/object
        (only-in :yuanxu/observability/testing-case yuanxu-test-case yuanxu-test-checkpoint)
        (only-in "./qualification/opentofu/service.ss"
                 call-with-service write-source rejects? empty-state?))
(export opentofu-service-cleanup-test)

;; Source expiry refuses forward work while retaining the admitted engine for
;; cleanup. This epoch is independent of command-failure qualification.
(def opentofu-service-cleanup-test
  (test-suite "OpenTofu service failure and source lifetime"
    (yuanxu-test-case "source expiry after apply preserves destroy"
      (call-with-service
        (lambda (fixture)
          (def original (.get fixture original))
          (def config (.get fixture config))
          (def prepared (.call fixture .prepare))
          (def Null (.get prepared recipe))
          (def changed-work (.call fixture .workspace "changed-after-apply"))
          (def stale-work (.call fixture .workspace "stale-before-execution"))
          (def apply-task (.get Null tasks apply))
          (.def (Changed changed [Null])
            tasks: =>.+
            (.o apply:
              (.cc apply-task 'owner changed '.run
                (lambda ()
                  (let (applied (.call (.cc apply-task 'owner changed 'directory changed-work) .run))
                    (write-source config (string-append original "\n;; changed after apply\n"))
                    applied)))))
          (dynamic-wind void
            (lambda ()
              (displayln "PHASE source-expiry-cleanup") (force-output)
              (yuanxu-test-checkpoint 'opentofu-source-expiry-cleanup)
              (check-equal? (rejects? "stale|changed|refused"
                              (lambda () (.call Changed .run changed-work))) #t)
              (check-equal? (empty-state? changed-work) #t)
              (check-equal? (rejects? "stale|changed|refused"
                              (lambda () (.call Null .run stale-work))) #t)
              (check-equal? (directory-files stale-work) '()))
            (lambda () (write-source config original)))
          ;; Core source identity is exact bytes and resolution, not a durable
          ;; revision fence. Restore/revalidate without starting another deploy.
          ((.get Null package-current))
          ((.get Null publication context admit-current))
          (check-equal? (directory-files stale-work) '())
          (displayln "OPENTOFU-SERVICE-CLEANUP-OK"))))))
