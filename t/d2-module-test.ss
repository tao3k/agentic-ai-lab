;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :clan/poo/object
        (only-in "../dev/d2/init.ss" agentic-ai-lab/dev/d2.init.exports))
(export d2-module-test)
(def D2Scope (.get agentic-ai-lab/dev/d2.init.exports modules d2))
(def Node. (.get D2Scope prototypes Node))
(def Relation. (.get D2Scope prototypes Relation))
(def Diagram. (.get D2Scope prototypes Diagram))
(def (node identity)
  (let (id-value identity) (.o (:: @ Node.) identity: id-value label: (symbol->string id-value))))
(def (edge from to)
  (let ((source from) (target to)) (.o (:: @ Relation.) from: source to: target)))
(def (view input) ((.get D2Scope infer) input))
(def d2-module-test
  (test-suite "D2 Module and ASCENT projection"
    (test-case "init exposes the module and transitive root selection"
      (let (result (view (.o (:: @ Diagram.) identity: 'sample revision: 'r1
                          nodes: (map node '(a b c isolated))
                          relations: (list (edge 'a 'b) (edge 'b 'c)) roots: '(a))))
        (check-equal? (length (.ref result 'nodes)) 3)
        (check-equal? (length (.ref result 'relations)) 2)
        (check-equal? (string? ((.get D2Scope source) result)) #t)))
    (test-case "a general graph may contain cycles"
      (let (result (view (.o (:: @ Diagram.) identity: 'cycle revision: 'r1
                          nodes: (map node '(a b))
                          relations: (list (edge 'a 'b) (edge 'b 'a)) roots: '(a))))
        (check-equal? (length (.ref result 'cycle-members)) 2)))
    (test-case "empty roots select all declared nodes"
      (let (result (view (.o (:: @ Diagram.) identity: 'all revision: 'r1 nodes: (map node '(a b)))))
        (check-equal? (length (.ref result 'nodes)) 2)))
    (test-case "undeclared endpoints and duplicate identities refuse export"
      (check-exception
       (view (.o (:: @ Diagram.) identity: 'bad revision: 'r1
                 nodes: (list (node 'a)) relations: (list (edge 'a 'missing)))) true)
      (check-exception
       (view (.o (:: @ Diagram.) identity: 'duplicate revision: 'r1
                 nodes: (list (node 'a) (node 'a)))) true))))
