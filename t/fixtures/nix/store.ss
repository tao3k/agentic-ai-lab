;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Isolated durable-root adapter. Nix owns registration/content verification;
;;; trusted release selection owns authorization. Not a new production API.
(import :clan/poo/object
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :tao3k/yuanxu/ops/func run-script)
        (only-in :tao3k/yuanxu/ops/config Config)
        (only-in :tao3k/yuanxu/module-system/source/admission module-source-type current-module-source-observer)
        (only-in :tao3k/yuanxu/module-system/building/artifacts
          accept-build-artifact-handoff! admit-build-artifacts! invalidate-build-artifacts!))
(export publish-store! restore-selected-store! store-add store-verify)
(def (store-command arguments)
  (def command (append '("nix-store" "--store" "daemon") arguments))
  ;; Observability records the real process boundary; it never returns a
  ;; verification verdict or skips a later runtime check.
  (let (observe (current-module-source-observer))
    (when observe (observe (list 'runtime-store-process command) 1)))
  (.get (run-script (.cc Config command: command timeout: 120)
                    output-port: (current-error-port)) output))
(def (store-add directory)
  (def result (find (cut string-prefix? "/nix/store/" <>)
                   (string-split (store-command (list "--add" directory)) #\newline)))
  (unless result (error "invalid registered store response"))
  result)
(def (store-verify root)
  ;; A top-level, actual local store object; no symlink/profile or inner path.
  (unless (and (string-prefix? "/nix/store/" root)
               (not (string-index (substring root 11 (string-length root)) #\/))
               (eq? (module-source-type root) 'directory))
    (error "release root must be an exact local Nix store object" root))
  ;; Nix 2.34 verify-path queries registered metadata before hashing contents.
  ;; Keep one fresh verification at every boundary, without a duplicate process.
  (store-command (list "--verify-path" root)))
(def (accept-packet! projection libdir packet)
  (call-with-input-string
    (call-with-output-string (cut write packet <>))
    (lambda (port)
      (parameterize ((current-input-port port))
        (accept-build-artifact-handoff! projection libdir)))))
(def (publish-store! projection libdir)
  ;; The real Core supervisor supplied this retained packet on its owned pipe.
  (def packet (read))
  (unless (eof-object? (read)) (error "trailing publication input"))
  (accept-packet! projection libdir packet)
  (call-with-temporary-directory "core-issued-build"
    (lambda (directory)
      (call-with-output-file (path-expand "issuance.ss" directory)
        (lambda (port) (write packet port) (newline port)))
      (def root (store-add directory))
      (store-verify root)
      (admit-build-artifacts! (.get projection build-graph))
      root)))
(def (restore-selected-store! projection libdir selected-root candidate-root)
  ;; selected-root is supplied by trusted release selection, independently of
  ;; candidate metadata. A GC-root symlink or arbitrary valid path is not it.
  (with-catch
    (lambda (failure)
      (invalidate-build-artifacts! (.get projection build-graph))
      (raise failure))
    (lambda ()
      (unless (equal? selected-root candidate-root)
        (error "Nix release differs from selected publication"))
      (store-verify selected-root)
      (def asset (path-expand "issuance.ss" selected-root))
      (unless (eq? (module-source-type asset) 'regular)
        (error "stored Core issuance must be a regular file"))
      (def packet (call-with-input-file asset
        (lambda (port)
          (def value (read port))
          (unless (eof-object? (read port)) (error "trailing stored issuance"))
          value)))
      (accept-packet! projection libdir packet)
      (store-verify selected-root)
      (admit-build-artifacts! (.get projection build-graph)))))
