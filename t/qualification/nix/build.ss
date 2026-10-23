;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Build only the selected adapter import closure with the installed compiler.
(import (only-in :std/make make pkg-config-libs)
        (only-in :gerbil/expander core-import-module expander-context-id)
        (only-in :std/source this-source-file)
        (only-in :yuanxu/module-system/building/source-package register-module-build-source!)
        (only-in :yuanxu/module-system/building/source-closure for-each-build-module))
;; The compiler resolves public application imports through its package prefix.
;; Register application sources, while keeping Core and the SDK compiled.
(def root (path-expand "../../.." (path-directory (this-source-file))))
(register-module-build-source! root 'agentic-ai-lab)
(def output (path-expand "lib" (getenv "GERBIL_PATH")))
(def seen (make-hash-table-eq))
;; The existing Core traversal selects roots; std/make owns all compilation.
(def sources '())
(def (selected-source context)
  (let (identity (expander-context-id context))
    (and (symbol? identity)
      (let (name (symbol->string identity))
        (cond
         ((or (string-prefix? "agentic-ai-lab/modules/nix/" name)
              (string-prefix? "agentic-ai-lab/modules/services/" name))
          (string-append
            (substring name (string-length "agentic-ai-lab/") (string-length name)) ".ss"))
         ((or (string-prefix? "yuanxu/t/qualification/service-publication/" name)
              (string-prefix? "yuanxu/t/qualification/build-publication/" name))
          (string-append "core/" (substring name 7 (string-length name)) ".ss"))
         (else #f))))))
(for-each
  (lambda (relative)
    (for-each-build-module (core-import-module (path-expand relative root))
      (lambda (context)
        (let (source (selected-source context))
          (when source
            (set! sources (cons source sources))))) seen))
  '("modules/nix/objects.ss" "modules/services/opentofu/objects.ss"
    "core/t/qualification/service-publication/fixtures.ss"
    "core/t/qualification/build-publication/projection.ss"
    "core/t/qualification/build-publication/store.ss"))
(make (reverse sources) srcdir: root libdir: output)
;; std/make owns executable construction, dependency closure and object reuse.
;; Runtime workers remain independent processes with the existing heap limits.
;; SDK-standard pkg-config discovery supplies the foreign-library closure;
;; no Homebrew prefix or SDK build-machine path belongs in a target recipe.
(def executable-link-options
  (pkg-config-libs "libcrypto" "libssl"))
(make (map (lambda (target)
             (list exe: (car target) bin: (cadr target)
                   "-ld-options" executable-link-options))
        '(("core/t/qualification/build-publication/worker" "build-publication-worker")
          ("core/t/qualification/build-publication/store-producer" "build-store-producer")
          ("t/qualification/build-publication/approved-producer" "build-approved-producer")))
  srcdir: root libdir: output)
(displayln "NIX-ADAPTER-BUILD-OK")
