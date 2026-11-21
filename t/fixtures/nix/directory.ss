;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Directory ownership and failure controls, independent of service publications.
(import :clan/poo/object
        (only-in :std/io/tempfile make-temporary-file-name clear-temporary-file!))
(export DirectoryFixture write-source)

(def (write-source path text)
  (create-directory* (path-directory path))
  (call-with-output-file (list path: path truncate: #t) (cut display text <>)))
(def (rollback-directory! remove-directory root cause)
  (with-catch
    (lambda (cleanup) (error "fixture preparation and rollback failed" cause cleanup))
    (lambda () (remove-directory root)))
  (raise cause))

(.def DirectoryFixture
  prefix: "lab-service-"
  .prepare: values
  .remove-directory: clear-temporary-file!
  .acquire:
  (lambda ()
    (def directory (make-temporary-file-name prefix))
    ;; Only a successfully created directory is owned by this acquisition.
    (create-directory directory)
    (with-catch (cut rollback-directory! .remove-directory directory <>)
      (lambda ()
        (def resource (.prepare (.o root: directory)))
        (unless (and (object? resource) (.slot? resource 'root)
                     (equal? (.get resource root) directory))
          (error "fixture preparation must retain its owned root"))
        resource)))
  .release: (lambda (resource) (.remove-directory (.get resource root))))
