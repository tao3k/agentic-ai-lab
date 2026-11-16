;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in :std/source this-source-file)
        (only-in "../../harness/run-lab-tests.ss" admit-lab-test-layout!)
        (only-in "../../../init.ss" tao3k/agentic-ai-lab.init.exports))
(export lab-loader-ownership-test)
(def tests-root (path-normalize (path-expand "../.." (path-directory (this-source-file)))))

(def lab-loader-ownership-test
  (test-suite "Lab init-owned downstream test publication"
    (test-case "declared owners discover their exact qualification files without running them"
      (def root tests-root)
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
      ;; The same Core contract runs before the default Lab Harness roster.
      (check (admit-lab-test-layout!) ? pair?))
    (test-case "adapter module suites use their declared Loader owners"
      (def root tests-root)
      (def (legacy-adapter-test? name)
        (and (string-suffix? "-test.ss" name)
             (or (string-prefix? "nix-" name) (string-prefix? "opentofu-" name))))
      (check-equal? (filter legacy-adapter-test? (directory-files root)) '()))
    (test-case "legacy qualification is reserved for retained evidence and consumer fixtures"
      (def root (path-expand "qualification" tests-root))
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
