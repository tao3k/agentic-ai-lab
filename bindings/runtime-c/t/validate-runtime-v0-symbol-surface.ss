;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Runtime-C test owner: compare one observed symbol list with the canonical
;;; runtime-v0 manifest and emit a machine-readable admission receipt.

(import :gerbil/runtime/gambit
        (only-in :clan/poo/object .ref)
        (only-in :std/list/walist walist)
        (only-in :std/encoding/json json->string)
        :agentic-ai-lab/modules/workflow/qualification/runtime-symbol-manifest)

(export main)

;;; File boundary: the actual symbol surface is read once into an immutable
;;; list before the manifest verifier receives it.
;; : (-> Path [String])
(def (read-lines path)
  (call-with-input-file
   path
   (lambda (port)
     (let loop ((lines '()))
       (let (line (read-line port))
         (if (eof-object? line) (reverse lines)
             (loop (cons line lines))))))))

;;; Command boundary: one explicit entrypoint owns argument validation,
;;; verification receipt rendering, and the final process decision.
;; : (-> [String] Void)
(def (main . args)
  (unless (= (length args) 2)
      (displayln "usage: gxi bindings/runtime-c/t/validate-runtime-v0-symbol-surface.ss MANIFEST.json ACTUAL.txt")
    (exit 64))
  (let* ((manifest (agentic-ai-lab-runtime-symbol-manifest-read-file (car args)))
         (receipt
          (agentic-ai-lab-runtime-symbol-manifest-verify
           manifest
           (read-lines (cadr args)))))
    (display
     (json->string
      (walist
       (list
        (cons "schema" (.ref receipt 'schema))
        (cons "schemaVersion" (.ref receipt 'schema-version))
        (cons "accepted" (.ref receipt 'accepted?))
        (cons "abi" (.ref receipt 'abi))
        (cons "expectedSymbols" (.ref receipt 'expected-symbols))
        (cons "actualSymbols" (.ref receipt 'actual-symbols))
        (cons "forbiddenSymbols" (.ref receipt 'forbidden-symbols))
        (cons "diagnostics"
              (map symbol->string (.ref receipt 'diagnostics)))))))
    (newline)
    (exit (if (.ref receipt 'accepted?) 0 1))))
