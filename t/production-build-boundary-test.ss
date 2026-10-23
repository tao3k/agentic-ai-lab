;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/error Error? Error-message)
        (only-in :gerbil/expander core-import-module expander-context-id)
        (only-in :yuanxu/module-system/building/source-closure for-each-build-module)
        (only-in "../build-spec.ss" agentic-ai-lab-library-spec))
(export production-build-boundary-test)
(def (dependencies path)
  (cadr (memq 'depend: (call-with-input-file path read))))
(def (asp? text) (string-prefix? "github.com/tao3k/asp-gerbil-scheme@" text))
(def production-build-boundary-test
  (test-suite "Production build and optional development policy boundary"
    (test-case "ASP is declared only by the development package"
      (check-equal? (any asp? (dependencies "gerbil.pkg")) #f)
      (check-equal? (length (filter asp? (dependencies "dev/gerbil.pkg"))) 1))
    (test-case "the actual Core test facade and build projector have no ASP import closure"
      (def visited 0)
      (for-each
        (lambda (file)
          (for-each-build-module (core-import-module file)
            (lambda (context)
              (set! visited (+ visited 1))
              (let* ((id (expander-context-id context))
                     (name (and (symbol? id) (symbol->string id))))
                (when name
                  (check-equal? (string-prefix? "asp-gerbil-scheme/" name) #f))))))
        '("testing-api.ss" "build-spec.ss"))
      (check-equal? (> visited 0) #t))
    (test-case "native dependency DFS rejects a development namespace before producing targets"
      (call-with-temporary-directory "build-boundary-"
        (lambda (directory)
          (def source (path-expand "fixture.ss" directory))
          ;; Synthetic namespace only: the real compiler creates the context.
          (call-with-output-file source
            (lambda (port)
              (display "package: agentic-ai-lab/dev\n(export value)\n(def value 1)\n" port)))
          (check-exception (agentic-ai-lab-library-spec (list source))
            (lambda (failure)
              (and (Error? failure)
                   (equal? (Error-message failure) "production build imports a development module")))))))))
