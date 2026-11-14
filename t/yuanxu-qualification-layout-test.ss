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
      (def (test-files directory)
        (def path (path-expand directory root))
        (map (cut path-expand <> path) (directory-files path)))
      (check-equal? (list-sort string<? (.get selected spec))
        (list-sort string<?
          (append (test-files "yanxu/modules/nix")
                  (test-files "yanxu/modules/services/opentofu"))))
      (check (member (path-expand "yanxu/modules/services/opentofu/deployment-test.ss" root)
                     (.get selected spec)) ? pair?)
      (check-equal? (eq? (.get selected admit-current) (.get selected source admit-current)) #t)
      (for-each (lambda (name) (check-equal? (.slot? selected name) #f))
                '(.run .compile execution))
      ((.get selected admit-current))
      (check-equal? (eq? (.ref/cached selected 'selected-graph) graph-before) #t))
    (test-case "Loader owners publish all Lab module test files"
      (def root (path-normalize (path-expand ".." (path-directory (this-source-file)))))
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
      (def (test-files directory)
        (def paths
          (map (lambda (name)
                 (def path (path-expand name directory))
                 (cons path (file-info-type (file-info path #f))))
               (directory-files directory)))
        (def (test-file? entry)
          (and (eq? (cdr entry) 'regular)
               (string-suffix? "-test.ss" (car entry))))
        (for-each (lambda (entry)
                    (unless (or (eq? (cdr entry) 'directory) (test-file? entry))
                      (error "Lab loader test trees admit only regular *-test.ss files" (car entry))))
                  paths)
        (append (map car (filter test-file? paths))
                (foldr append '()
                  (map (lambda (entry) (test-files (car entry)))
                       (filter (lambda (entry) (eq? (cdr entry) 'directory)) paths)))))
      (def owners (.get context loader-roots))
      (def files (test-files (path-expand "t/yanxu" root)))
      (def qualification (.get tao3k/agentic-ai-lab.init.exports tests qualification))
      (def selected (.call qualification .select owners))
      ((.get selected admit-current))
      (def directories (map path-directory files))
      (for-each (lambda (owner)
                  (check (member (path-directory (path-expand "test.ss" (owner-test-directory owner)))
                                 directories) ? pair?))
                owners)
      (check-equal? (list-sort string<? (.get selected spec))
                    (list-sort string<? files)))
    (test-case "adapter module suites use their declared Loader owners"
      (def root (path-directory (this-source-file)))
      (def (legacy-adapter-test? name)
        (and (string-suffix? "-test.ss" name)
             (or (string-prefix? "nix-" name) (string-prefix? "opentofu-" name))))
      (check-equal? (filter legacy-adapter-test? (directory-files root)) '()))
    (test-case "legacy qualification is reserved for retained evidence and consumer fixtures"
      (def root (path-expand "qualification" (path-directory (this-source-file))))
      (def (legacy-suites directory prefix)
        (foldr append '()
          (map (lambda (name)
                 (def path (path-expand name directory))
                 (def relative (string-append prefix name))
                 (cond
                   ((eq? (file-info-type (file-info path #f)) 'directory)
                    (legacy-suites path (string-append relative "/")))
                   ((string-suffix? "-test.ss" name) (list relative))
                   (else '())))
               (directory-files directory))))
      (check-equal? (list-sort string<? (legacy-suites root ""))
        '("temporal-current-source/runtime-test.ss"
          "yuanxu-deployment-consumer/t/yanxu/Lab/services/opentofu/runtime-test.ss")))))
