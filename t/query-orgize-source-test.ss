;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :std/test check check-exception test-suite)
        (only-in :clan/poo/object .o .ref)
        :yuanxu/poo-clos/interface
        :poo-flow/modules/query/objects
        :poo-flow/modules/query/results/funs
        :poo-flow/modules/query/orgize-source)

(export query-orgize-source-test)

(def org-source
  "#+SEQ_TODO: WAIT | DONE\n* WAIT α\n* DONE β\n")

(def (row-field row field)
  (let loop ((cells (.ref row 'cells)))
    (cond ((null? cells) (error "missing result field" field))
          ((eq? (.ref (car cells) 'field) field)
           (.ref (car cells) 'value))
          (else (loop (cdr cells))))))

(def query-orgize-source-test
  (test-suite "Orgize source Elements under canonical POO Flow Query"
    (yuanxu-test-case "one source produces a source-bound open headline row"
      (let* ((observation (poo-flow-query-orgize-open-headlines org-source))
             (query (.ref observation 'query))
             (result (.ref observation 'result-set))
             (row (car (.ref result 'rows))))
        (check (poo-flow-query-orgize-source-observation? observation) => #t)
        (check (.ref result 'result-count) => 1)
        (check (row-field row 'title) => "WAIT α")
        (check (row-field row 'todo-type) => "todo")
        (check (row-field row 'byte-start) => 24)
        (check (row-field row 'byte-end) => 34)
        (check (row-field row 'source-sha256)
               => (.ref observation 'source-sha256))
        (check (.ref query 'semantic-revision)
               => (.ref observation 'source-sha256))
        (check (.ref (.ref observation 'admission) 'accepted?) => #t)
        (check (.ref observation 'session-admitted?) => #f)
        (check (.ref observation 'action-authority?) => #f)
        (check (poo-flow-query-orgize-source-observation?
                (poo-flow-query-orgize-open-headlines-replay
                 org-source observation)) => #t)))
    (yuanxu-test-case "current bytes, not a declared digest, drive replay"
      (let ((observation (poo-flow-query-orgize-open-headlines org-source)))
        (check-exception
         (poo-flow-query-orgize-open-headlines-replay
          "#+SEQ_TODO: WAIT | DONE\n* DONE α\n* DONE β\n"
          observation)
         true)
        (check-exception
         (poo-flow-query-orgize-open-headlines (.o kind: 'forged-graph))
         true)))
    (yuanxu-test-case "a self-consistent forged row fails source replay"
      (let* ((observation (poo-flow-query-orgize-open-headlines org-source))
             (query (.ref observation 'query))
             (result (.ref observation 'result-set))
             (row (car (.ref result 'rows)))
             (forged-row
              (poo-flow-query-result-row
               (.ref row 'identity)
               (list (poo-flow-query-result-cell
                      'source-sha256 (.ref observation 'source-sha256))
                     (poo-flow-query-result-cell 'byte-start 24)
                     (poo-flow-query-result-cell 'byte-end 34)
                     (poo-flow-query-result-cell 'title "Forged")
                     (poo-flow-query-result-cell 'todo-type "todo"))))
             (forged-set
              (poo-flow-query-result-set
               (.ref result 'identity) (.ref query 'result-contract)
               (.ref query 'identity) (.ref query 'version)
               (.ref query 'semantic-revision) (list forged-row) #t)))
        (check-exception
         (poo-flow-query-orgize-open-headlines-replay
          org-source (.o (:: @ observation) result-set: forged-set))
         true)))
    (yuanxu-test-case "an altered canonical Query predicate fails replay"
      (let* ((observation (poo-flow-query-orgize-open-headlines org-source))
             (query (.ref observation 'query))
             (program (.ref query 'program))
             (done-predicate
              (.o (:: @ GraphSyntaxEquals.)
                  left: (.o (:: @ GraphSyntaxProperty.)
                            binding: 'h property: 'todoType)
                  right: (.o (:: @ GraphSyntaxLiteral.)
                             literal-kind: 'string value: "done")))
             (changed-program
              (.o (:: @ program) where: done-predicate))
             (changed-query
              (.o (:: @ query) program: changed-program)))
        (check-exception
         (poo-flow-query-orgize-open-headlines-replay
          org-source (.o (:: @ observation) query: changed-query))
         true)))))
