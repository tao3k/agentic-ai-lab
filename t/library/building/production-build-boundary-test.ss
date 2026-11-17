;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :clan/poo/object .get)
        (only-in :gerbil/expander core-import-module expander-context-id)
        (only-in :tao3k/yuanxu/module-system/building/source-closure for-each-build-module)
        (only-in :tao3k/yuanxu/module-system/source/admission call-with-module-source-operation-measurement)
        (only-in "../../../init.ss" tao3k/agentic-ai-lab.init.exports))
(export production-build-boundary-test)
(def (dependencies path)
  (cadr (memq 'depend: (call-with-input-file path read))))
(def (asp? text) (string-prefix? "github.com/tao3k/asp-gerbil-scheme@" text))
(def production-build-boundary-test
  (test-suite "Production build and optional development policy boundary"
    (test-case "the init-owned package spec includes the declared business modules without constructing scopes"
      (defvalues (spec counts)
        (call-with-module-source-operation-measurement
          (lambda () (.get tao3k/agentic-ai-lab.init.exports std-make-spec))
          accounting?: #f))
      (def targets (map (lambda (row) (if (pair? row) (cadr row) row)) spec))
      (check-equal? (and (member "modules/ai-agentic-context/interface" targets) #t) #t)
      (check-equal? (and (member "modules/temporal-causality/interface" targets) #t) #t)
      (check-equal? (hash-ref counts '(calls scope-factory) 0) 0))
    (test-case "ASP is declared only by the development package"
      (check-equal? (any asp? (dependencies "gerbil.pkg")) #f)
      (check-equal? (length (filter asp? (dependencies "dev/gerbil.pkg"))) 1))
    (test-case "the Core test facade and the Lab init have no ASP import closure"
      (def visited 0)
      (for-each
        (lambda (file)
          (for-each-build-module (core-import-module file)
            (lambda (context)
              (set! visited (+ visited 1))
              (let* ((id (expander-context-id context))
                     (name (and (symbol? id) (symbol->string id))))
                (when name
                  (begin
                    (check-equal? (string-prefix? "asp-gerbil-scheme/" name) #f)
                    (check-equal? (string-prefix? "tao3k/agentic-ai-lab/dev/" name) #f)))))))
        '(:tao3k/yuanxu/observability/testing-case "init.ss"))
      (check-equal? (> visited 0) #t))))
