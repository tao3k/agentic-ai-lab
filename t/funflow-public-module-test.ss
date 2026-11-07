;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test test-suite check-equal?)
        (only-in :yuanxu/observability/testing-case
                 yuanxu-test-case)
        (only-in :yuanxu/modules/funflow/graph-projection
                 yuanxu-funflow-workflow-agreement)
        (only-in :yuanxu/modules/funflow/objects FunflowModule. Job. Task.)
        (only-in :clan/poo/object object?)
        (only-in :yuanxu/poo-clos/interface
                 poo-clos-generic-function))

(export funflow-public-module-test)

(def funflow-public-module-test
  (test-suite "Funflow top-level module ownership"
    (yuanxu-test-case "Funflow public prototypes are owned by Core"
      (check-equal? (object? FunflowModule.) #t)
      (check-equal? (object? Job.) #t)
      (check-equal? (object? Task.) #t))
    (yuanxu-test-case "functional interface remains callable"
      (check-equal? (procedure? yuanxu-funflow-workflow-agreement) #t))
    (yuanxu-test-case "POO CLOS remains directly importable from Core"
      (check-equal? (procedure? poo-clos-generic-function) #t))))
