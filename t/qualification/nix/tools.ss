;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; One native link of the shared closure; every invocation is a fresh process.
(import (only-in "../../../core/t/qualification/service-publication/fixtures.ss" current-service-source-root)
        (rename-in (only-in "../../../core/t/qualification/build-publication/worker.ss" main)
                   (main publication-worker))
        (rename-in (only-in "../../../core/t/qualification/build-publication/store-producer.ss" main)
                   (main store-producer))
        (rename-in (only-in "../build-publication/approved-producer.ss" main)
                   (main approved-producer)))
(export main)
(def (main role . arguments)
  ;; Caller-owned source capability follows the maintained Just working root,
  ;; never this executable's vanished compiler sandbox. Store runs in Core;
  ;; the other existing roles run in the product root.
  (parameterize ((current-service-source-root
                   (path-expand
                     (if (string=? role "store") "scenarios/gitea-postgresql"
                         "core/scenarios/gitea-postgresql"))))
    (apply (case (string->symbol role)
             ((worker) publication-worker)
             ((store) store-producer)
             ((approved) approved-producer)
             (else (error "unknown publication qualification role" role)))
           arguments)))
