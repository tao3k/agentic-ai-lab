;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Exercise the installed Orgize dependency through POO Flow's POO surface.
(import (only-in :clan/poo/object .o .ref)
        :poo-flow/modules/query/semantic/orgize-interface
        (only-in :orgize/bindings/c/orgize orgize-c-round-trip))
(export run-orgize-runtime-reuse-test)

(def (run-orgize-runtime-reuse-test)
  (let* ((graph
          (make-org-element-graph-view
           (list (.o id: 0 parent: #f kind: "org-data" title: #f)
                 (.o id: 1 parent: 0 kind: "headline" title: "Evidence"))
           (lambda (record) (.ref record 'id))
           (lambda (record) (.ref record 'parent))
           (lambda (record) (.ref record 'kind))
           (lambda (record name) (.ref record (string->symbol name)))))
         (query (make-org-element-query "headline" "title" "Evidence"))
         (assertion
          (make-org-contract-assertion
           "evidence-title" 'error query
           (make-org-contract-expectation 'exactly 1)))
         (result (org-contract-evaluate-assertion assertion graph 0)))
    (unless (and (= (org-contract-result-matched-count result) 1)
                 (org-contract-result-passed? result)
                 (= (orgize-c-round-trip) 0))
      (error "installed Orgize runtime and C ABI diverged"))
    #t))
