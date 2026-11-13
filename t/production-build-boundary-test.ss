;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :gerbil/expander core-import-module expander-context-id)
        (only-in :tao3k/yuanxu/module-system/building/source-closure for-each-build-module)
        (only-in :tao3k/yuanxu/module-system/source/admission call-with-module-source-operation-measurement)
        (rename-in (only-in "../build.ss" main) (main package-build-main)))
(export production-build-boundary-test)
(def (dependencies path)
  (cadr (memq 'depend: (call-with-input-file path read))))
(def (asp? text) (string-prefix? "github.com/tao3k/asp-gerbil-scheme@" text))
(def production-build-boundary-test
  (test-suite "Production build and optional development policy boundary"
    (test-case "default package spec selects only Temporal Causality and no business scopes"
      (defvalues (output counts)
        (call-with-module-source-operation-measurement
          (lambda () (call-with-output-string
            (lambda (port)
              (parameterize ((current-output-port port)) (package-build-main "spec")))))
          accounting?: #f))
      (def targets (map (lambda (row) (if (pair? row) (cadr row) row))
                        (call-with-input-string output read)))
      (check-equal? (and (member "modules/temporal-causality/interface" targets) #t) #t)
      (check-equal?
        (filter (lambda (target)
                  (and (string-prefix? "modules/" target)
                       (not (string-prefix? "modules/temporal-causality/" target))))
                targets)
        '())
      (check-equal? (hash-ref counts '(calls candidate-read) 0) 0)
      (check-equal? (hash-ref counts '(calls scope-factory) 0) 0))
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
                  (begin
                    (check-equal? (string-prefix? "asp-gerbil-scheme/" name) #f)
                    (check-equal? (string-prefix? "tao3k/agentic-ai-lab/dev/" name) #f)))))))
        '(:tao3k/yuanxu/observability/testing-case "build.ss"))
      (check-equal? (> visited 0) #t))))
