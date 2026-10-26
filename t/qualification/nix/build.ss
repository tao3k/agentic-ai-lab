;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Build only the selected adapter import closure with the installed compiler.
(import (only-in :std/make make pkg-config-libs)
        (only-in :gerbil/expander core-import-module expander-context-id)
        (only-in :std/source this-source-file)
        (only-in :yuanxu/module-system/building/source-package register-module-build-source! register-yuanxu-build-source!)
        (only-in :yuanxu/module-system/building/source-closure for-each-build-module))
;; The compiler resolves public application imports through its package prefix.
;; Register application sources, while keeping Core and the SDK compiled.
(def root (path-normalize (path-expand "../../.." (path-directory (this-source-file)))))
(register-module-build-source! root 'agentic-ai-lab)
;; Core qualification helpers are source-owned, not installed production APIs.
(register-yuanxu-build-source! (path-expand "core" root))
(def output (path-expand "lib" (getenv "GERBIL_PATH")))
(def seen (make-hash-table-eq))
;; The existing Core traversal selects roots; std/make owns all compilation.
(def sources '())
(def (selected-source context)
  (let (identity (expander-context-id context))
    (and (symbol? identity)
      (let (name (symbol->string identity))
        (cond
         ((string=? "agentic-ai-lab/services" name) "services.ss")
         ((string=? "agentic-ai-lab/nix-contracts" name) "nix-contracts.ss")
         ((string=? "agentic-ai-lab/opentofu-contracts" name) "opentofu-contracts.ss")
         ((or (string-prefix? "agentic-ai-lab/scenarios/aws/" name)
              (string-prefix? "agentic-ai-lab/modules/nix/" name)
              (string-prefix? "agentic-ai-lab/modules/services/" name)
              (string-prefix? "agentic-ai-lab/t/qualification/build-publication/" name))
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
          ;; File imports and package imports can name the same source. Keep
          ;; one target while retaining the SDK's dependency traversal order.
          (when (and source (not (member source sources)))
            (set! sources (cons source sources))))) seen))
  ;; AWS validation consumes this public native contract without constructing
  ;; the AWS scope. Its import closure must be available in the fresh worker.
  '("scenarios/aws/types.ss" "modules/nix/objects.ss" "modules/services/opentofu/objects.ss"
    "core/t/qualification/service-publication/fixtures.ss"
    "core/t/qualification/build-publication/projection.ss"
    "core/t/qualification/build-publication/store.ss"
    "t/qualification/nix/tools.ss"))
;; std/make's output paths use the package prefix. Compile each package with
;; its real source root so SDK staleness checks inspect the emitted artifacts.
(def ordered-sources (reverse sources))
(make (map (lambda (source) (substring source 5 (string-length source)))
           (filter (cut string-prefix? "core/" <>) ordered-sources))
  srcdir: (path-expand "core" root) libdir: output prefix: "yuanxu")
(make (filter (lambda (source) (not (string-prefix? "core/" source))) ordered-sources)
  srcdir: root libdir: output prefix: "agentic-ai-lab")
;; std/make owns executable construction, dependency closure and object reuse.
;; Runtime workers remain independent processes with the existing heap limits.
;; SDK-standard pkg-config discovery supplies the foreign-library closure;
;; no Homebrew prefix or SDK build-machine path belongs in a target recipe.
(def executable-link-options
  (pkg-config-libs "libcrypto" "libssl"))
(make (list (list exe: "t/qualification/nix/tools" bin: "build-publication-tools"
                  "-ld-options" executable-link-options))
  srcdir: root libdir: output prefix: "agentic-ai-lab")
(displayln "NIX-ADAPTER-BUILD-OK")
