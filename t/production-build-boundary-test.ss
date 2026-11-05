;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/error Error? Error-message)
        (only-in :gerbil/expander core-import-module expander-context-id)
        (only-in :yuanxu/module-system/building/source-closure for-each-build-module)
        (only-in :yuanxu/module-system/source/objects
                 yuanxu-module-source-ref-value yuanxu-module-source-ref-metadata)
        (only-in :agentic-ai-lab/modules/module-authoring/source-registry
                 agentic-ai-lab-module-system-source-refs)
        (only-in "../build-spec.ss" agentic-ai-lab-build-spec agentic-ai-lab-public-build-roots)
        (only-in :clan/poo/object .get)
        (only-in "../init.ss" agentic-ai-lab.init.exports))
(export production-build-boundary-test)
(def (dependencies path)
  (cadr (memq 'depend: (call-with-input-file path read))))
(def (asp? text) (string-prefix? "github.com/tao3k/asp-gerbil-scheme@" text))
(def production-build-boundary-test
  (test-suite "Production build and optional development policy boundary"
    (test-case "init owns selection and is not a library build root"
      (check-equal? (member "init.ss" agentic-ai-lab-public-build-roots) #f)
      ;; Obtaining the compiler projection remains inert; invoking it belongs
      ;; to the build entry, with the original selected-source admission.
      (check-equal? (procedure? (.get agentic-ai-lab.init.exports std-make-spec)) #t))
    (test-case "library roots preserve the real front end without bootstrapping application selection"
      ;; Derive the old query from the REAL publisher, not a copied registry.
      ;; This test imports it; the production build-spec no longer does.
      (def front-ends
        (map yuanxu-module-source-ref-value
          (filter (lambda (source)
                    (not (eq? (cdr (assq 'entrypoint-role
                                        (yuanxu-module-source-ref-metadata source)))
                              'interface)))
                  (agentic-ai-lab-module-system-source-refs))))
      (check-equal? (length front-ends) 1)
      (check-equal? (take agentic-ai-lab-public-build-roots (length front-ends)) front-ends)
      (for-each-build-module (core-import-module "build-spec.ss")
        (lambda (context)
          (check-equal? (and (memq (expander-context-id context)
                            '(agentic-ai-lab/modules/module-authoring/source-registry
                              agentic-ai-lab/modules/module-authoring/module-source-collection
                              agentic-ai-lab/modules/module-authoring/source-policy)) #t) #f))))
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
        '(:yuanxu/observability/testing-case "build-spec.ss"))
      (check-equal? (> visited 0) #t))
    (test-case "runtime dependency DFS rejects a development namespace before producing targets"
      (call-with-temporary-directory "build-boundary-"
        (lambda (directory)
          (def source (path-expand "fixture.ss" directory))
          ;; Synthetic namespace only: the real compiler creates the context.
          (call-with-output-file source
            (lambda (port)
              (display "package: agentic-ai-lab/dev\n(export value)\n(def value 1)\n" port)))
          (check-exception (agentic-ai-lab-build-spec (list source))
            (lambda (failure)
              (and (Error? failure)
                   (equal? (Error-message failure) "production build imports a development module")))))))))
