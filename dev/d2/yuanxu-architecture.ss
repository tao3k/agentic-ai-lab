;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; The host supplies its renderer to independent Core architecture facts.
(import :clan/poo/object
        (only-in "./init.ss" agentic-ai-lab/dev/d2.init.exports)
        (only-in "../../core/dev/d2/architecture.ss" architecture-diagrams))
(export main)

(def (main (output "core/dev/d2/20-module-loading"))
  ((.get agentic-ai-lab/dev/d2.init.exports std-make-spec) '())
  (def d2 (.get agentic-ai-lab/dev/d2.init.exports modules d2))
  ;; ASCENT owns endpoint validation, reachability and selected visual rows.
  ;; Core declares facts only; the published serializer consumes derived rows.
  (def sources
    (map (lambda (diagram)
      (cons (.get diagram identity) ((.get d2 source) ((.get d2 infer) diagram))))
      (architecture-diagrams d2)))
  ((.get agentic-ai-lab/dev/d2.init.exports admit-current))
  (create-directory* output)
  (for-each (lambda (source)
    (def file (path-expand (string-append "20.24-" (symbol->string (car source)) ".d2") output))
    (call-with-output-file (list path: file truncate: #t)
      (lambda (port) (display (cdr source) port)))
    (displayln "D2 " file)) sources))
