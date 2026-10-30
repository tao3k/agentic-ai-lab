#!/usr/bin/env -S gerbil interactive
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Standard build declaration, consumed by the development gerbil build command.
;;; Init owns discovery, source guards, native Make inputs and publication.
;; Register the actual package source before an independent adapter prefix
;; discovers imports. The existing gateway verifies gerbil.pkg ownership.
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  (let ((root (path-normalize (path-directory (this-source-file))))
        (paths (load-path)))
    (register-module-build-source! root 'agentic-ai-lab)
    ;; Source registration authenticates the fallback package. Preparation
    ;; must retain the consumer's installed-library priority, rather than
    ;; accidentally recompiling native dependencies as private test support.
    (set-load-path!
      (if (member root (map path-normalize paths))
        paths
        (append paths (list root))))))

(import (only-in :clan/poo/object .get)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "./init.ss" agentic-ai-lab.init.exports))
;; Installed libraries have the same priority as the actual test consumer.
;; This declaration owns no Case inventory, Harness, policy or result verdict.
(defbuild-script
  ((.get agentic-ai-lab.init.exports tests qualification std-make-spec))
  prefix: "agentic-ai-lab")
