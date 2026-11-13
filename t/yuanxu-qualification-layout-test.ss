;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in :std/source this-source-file)
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
               "yanxu/modules/services/opentofu/publication-test.ss"
               "yanxu/modules/services/opentofu/service-contract-test.ss")))
      (check-equal? (eq? (.get selected admit-current) (.get selected source admit-current)) #t)
      (for-each (lambda (name) (check-equal? (.slot? selected name) #f))
                '(.run .compile execution))
      ((.get selected admit-current))
      (check-equal? (eq? (.ref/cached selected 'selected-graph) graph-before) #t))))
