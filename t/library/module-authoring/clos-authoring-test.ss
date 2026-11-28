;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .o)
        (only-in :std/test test-suite check check-equal?)
        (only-in :tao3k/yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :tao3k/yuanxu/module-system/observability/presentation
                 yuanxu-poo-slot-authoring-datum-observations
                 yuanxu-poo-slot-authoring-diagnostics))
(export poo-clos-authoring-test)

(def poo-clos-authoring-test
  (test-suite "Yuanxu authoring policy for CLOS forms"
    (yuanxu-test-case "the source gate rejects the observed lazy self-slot leak shape"
      (let (diagnostics
            (yuanxu-poo-slot-authoring-diagnostics
             (yuanxu-poo-slot-authoring-datum-observations
              'poo-clos
              '(def (operator status-name)
                 (.o status: status)))))
        (check (pair? diagnostics) => #t)
        (check-equal? (cdr (assoc 'code (car diagnostics)))
                      'poo-slot-initializer-shadows-slot)
        (check-equal? (cdr (assoc 'slot (car diagnostics))) 'status)))))
