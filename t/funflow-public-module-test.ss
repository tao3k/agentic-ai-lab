;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :std/test test-suite check-equal?)
        (only-in :core/observability/testing-case
                 poo-flow-test-case)
        (only-in :poo-flow/modules/funflow/interface
                 poo-flow-funflow-workflow-agreement
                 Funflow FunflowModule. make-funflow-scope)
        (rename-in (only-in :poo-flow/modules/funflow/native-scope Funflow)
                   (Funflow canonical-Funflow))
        (only-in :clan/poo/object object?)
        (only-in :core/poo-clos/interface
                 poo-clos-generic-function))

(export funflow-public-module-test)

(def funflow-public-module-test
  (test-suite "Funflow top-level module ownership"
    (poo-flow-test-case "native publication is the same object through the public interface"
      (check-equal? (eq? Funflow canonical-Funflow) #t)
      (check-equal? (object? FunflowModule.) #t)
      (check-equal? (procedure? make-funflow-scope) #t))
    (poo-flow-test-case "functional interface remains callable"
      (check-equal? (procedure? poo-flow-funflow-workflow-agreement) #t))
    (poo-flow-test-case "POO CLOS remains directly importable from Core"
      (check-equal? (procedure? poo-clos-generic-function) #t))))
