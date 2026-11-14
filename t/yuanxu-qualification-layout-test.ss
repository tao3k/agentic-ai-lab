;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in :std/source this-source-file)
        (only-in :tao3k/yuanxu/module-system/source/directory module-directory-context)
        (only-in :tao3k/yuanxu/module-system/source/objects yuanxu-module-source-ref-metadata)
        (only-in "../init.ss" tao3k/agentic-ai-lab.init.exports))
(export yuanxu-qualification-layout-test)

(def yuanxu-qualification-layout-test
  (test-suite "Lab qualification layout"
    (test-case "declared owners discover their exact qualification files without running them"
      (def root (path-directory (this-source-file)))
      (def qualification (.get tao3k/agentic-ai-lab.init.exports tests qualification))
      (def owners '(tao3k/agentic-ai-lab/modules/nix/interface
                    tao3k/agentic-ai-lab/modules/services/opentofu/interface))
      (def selected (.call qualification .select owners))
      (def graph-before (.ref/cached selected 'selected-graph))
      (check-equal? (eq? (.call selected .select owners) selected) #t)
      (check-equal? (.get selected spec)
        (map (cut path-expand <> root)
             '("yanxu/modules/nix/flake-source-test.ss"
               "yanxu/modules/services/opentofu/module-scope-test.ss"
               "yanxu/modules/services/opentofu/publication-test.ss"
               "yanxu/modules/services/opentofu/service-contract-test.ss")))
      (check-equal? (eq? (.get selected admit-current) (.get selected source admit-current)) #t)
      (for-each (lambda (name) (check-equal? (.slot? selected name) #f))
                '(.run .compile execution))
      ((.get selected admit-current))
      (check-equal? (eq? (.ref/cached selected 'selected-graph) graph-before) #t))
    (test-case "every selected leaf has an owned qualification test directory"
      (def root (path-expand ".." (path-directory (this-source-file))))
      (def context
        (module-directory-context (path-expand "init.ss" root)
          (lambda (_) (error "layout discovery must leave publications cold"))
          publication-prepares-source?: #t))
      (def locate (.get context locate))
      (def (owner-test-directory owner)
        (def metadata (yuanxu-module-source-ref-metadata (locate owner)))
        (path-expand
          (string-append (cdr (assq 'test-dir metadata)) "/yanxu/"
                         (symbol->string (cdr (assq 'namespace-mount metadata))) "/"
                         (symbol->string (cdr (assq 'declaration-id metadata))))
          root))
      (def (test-directories directory)
        (def paths
          (map (lambda (name)
                 (def path (path-expand name directory))
                 (cons path (file-info-type (file-info path #f))))
               (directory-files directory)))
        (def (test-file? entry)
          (and (eq? (cdr entry) 'regular)
               (string-suffix? "-test.ss" (car entry))))
        (append (if (ormap test-file? paths) (list directory) '())
                (foldr append '()
                  (map (lambda (entry) (test-directories (car entry)))
                       (filter (lambda (entry) (eq? (cdr entry) 'directory)) paths)))))
      (check-equal?
        (list-sort string<? (test-directories (path-expand "t/yanxu" root)))
        (list-sort string<? (map owner-test-directory (.get context loader-roots)))))))
