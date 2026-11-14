;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; One compiler unit; service selection and admission use production Core.
(import :clan/poo/object :std/build-script
        (only-in :tao3k/yuanxu/module-system/source/admission module-source-read)
        (only-in :tao3k/yuanxu/module-system/building/artifacts current-build-output-directory))
(export probe-projection probe-build write-artifact-bytes)
(def (probe-projection selection root identity)
  (def graph (.get selection build-graph))
  (def source (path-expand "probe.ss" root))
  (def original (module-source-read source))
  (.o build-graph: graph compiler-identities: (list identity)
      source-inputs: (append (.get graph compiler-inputs) (list (cons source original)))
      admit-current:
      (lambda ()
        ((.get graph compiler-current))
        (unless (equal? original (module-source-read source))
          (error "probe source changed")))))
(def (probe-build root lib)
  (let ((this-source-file (lambda () (path-expand "build.ss" root))))
    (defbuild-script '("probe") libdir: (or (current-build-output-directory) lib)
      bindir: (path-expand "bin" lib) parallelize: 1 optimize: #f)
    main))


;; Inject byte changes without also changing Gerbil freshness metadata. Restoring
;; bytes restores the original artifact; negative tests must still reject the
;; corrupt contents even when file times match the issued snapshot.
(def (write-artifact-bytes path data)
  (def previous (and (file-exists? path) (file-info path #f)))
  (call-with-output-file (list path: path truncate: #t)
    (lambda (port) (write-subu8vector data 0 (u8vector-length data) port)))
  (when previous
    (file-last-access-and-modification-times-set! path
      (file-info-last-access-time previous) (file-info-last-modification-time previous))))
