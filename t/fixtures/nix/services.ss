;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Test resources only: POO acquisition/preparation/release, no runner.
(import :clan/poo/object
        (only-in :std/string/misc string-subst)
        (only-in :std/encoding/json write-json)
        (only-in :std/error Error? Error-message Error-irritants)
        (only-in "./directory.ss" DirectoryFixture write-source)
        (only-in :std/test check-equal?)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-checkpoint)
        (prefix-in :clan/poo/declarative-metadata metadata.)
        (only-in :tao3k/yuanxu/admission/publication AdmissionPublication.)
        (only-in :tao3k/yuanxu/module-system/source/link yuanxu-load-modules)
        (only-in :tao3k/yuanxu/module-system/source/admission module-source-read))
(export ServicesFixture refused)

(def (service-source-root) (path-expand "t/fixtures/nix/service-sources" (current-directory)))
(def (select-services workspace source)
  (yuanxu-test-checkpoint 'service-files-prepared)
  (def selection (yuanxu-load-modules (path-expand "init.ss" source)))
  (yuanxu-test-checkpoint 'service-selection-ready)
  (def publication (.call AdmissionPublication. .for-export selection
                     'applications/gitea-postgresql 'Application))
  (yuanxu-test-checkpoint 'service-publication-ready)
  (.cc workspace source: source selection: selection
    publication: publication))

(def (prepare-services workspace postgres-ports gitea-ports client-port null-settings?)
  (def source-root (service-source-root))
  (def root (.get workspace root))
  (write-source (path-expand "gerbil.pkg" root)
    (string-append "(package: " (symbol->string (gensym 'service-test-))
      " prelude: :tao3k/yuanxu/module-system/source/module-prelude)"))
  ;; Real maintained roles, isolated only for destructive source controls.
  (for-each
    (lambda (name ports)
      (def directory (path-expand (string-append "modules/services/" name) root))
      (for-each
        (lambda (role)
          (def filename (string-append role ".ss"))
          (def source (path-expand (string-append name "/" filename) source-root))
          (when (file-exists? source)
            (write-source (path-expand filename directory) (module-source-read source))))
        '("types" "objects" "func" "config" "interface"))
      (write-source (path-expand (string-append name ".json") directory)
        (call-with-output-string
          (lambda (out)
            (display "{" out)
            (display (if (string=? name "postgresql")
                       (if null-settings? "\"settings\":null" "\"settings\":{\"port\":5432}")
                       "\"database\":{") out)
            (unless (string=? name "postgresql")
              (when client-port
                (display "\"port\":" out)
                (if (eq? client-port 'null) (display "null" out) (write-json out client-port)))
              (display "}" out))
            (display ",\"allowed-ports\":" out)
            (write-json out (list->vector ports))
            (display "}" out)))))
    '("postgresql" "gitea") (list postgres-ports gitea-ports))
  (write-source (path-expand "modules/services/postgresql/unread.json" root) "not JSON")
  (for-each
    (lambda (role)
      (write-source
        (path-expand (string-append "modules/applications/gitea-postgresql/" role ".ss") root)
        (let (text (module-source-read (path-expand (string-append role ".ss") source-root)))
          (if (string=? role "objects")
            (string-subst (string-subst text "postgresql/config.ss" "../../services/postgresql/config.ss")
                          "gitea/config.ss" "../../services/gitea/config.ss")
            text))))
    '("types" "objects" "config" "interface"))
  (write-source (path-expand "init.ss" root)
    "(yuanxu! :test-dir \"./t\" mode: explicit (closed-package disable: #t) :services (postgresql) (gitea) (unused disable: #t) :applications (gitea-postgresql))")
  (write-source (path-expand "modules/services/unused/interface.ss" root) "(((cold")
  (select-services workspace root))

(.def (ServicesFixture @ DirectoryFixture)
  postgres-ports: '(5432 5433)
  gitea-ports: '(5432 5433)
  client-port: #f
  null-settings?: #f
  .prepare: (lambda (workspace)
              (prepare-services workspace postgres-ports gitea-ports client-port null-settings?)))

(def (cause failure)
  (if (metadata.failure? failure) (cause (metadata.failure-cause failure)) failure))
(def (refused publication parent candidate (message #f) (expected-source #f))
  (defvalues (receipt next failure) (.call publication .publish parent candidate))
  (check-equal? receipt #f)
  (check-equal? (eq? next parent) #t)
  (check-equal? (metadata.failure? failure) #t)
  (when message
    (check-equal? (and (Error? (cause failure)) (Error-message (cause failure))) message))
  (when expected-source
    (check-equal? (Error-irritants (cause failure))
                  (list (path-normalize expected-source) 'source-bytes-changed))))
