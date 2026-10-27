;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Preserve the published Suite; shared fixtures have their own owner.
;;; Compiler units register every original Case into this native lifecycle.
(import :std/test
        (only-in "./qualification/context-temporal/evaluator/cases-1.ss" register-evaluator-cases-1!)
        (only-in "./qualification/context-temporal/evaluator/cases-2.ss" register-evaluator-cases-2!)
        (only-in "./qualification/context-temporal/evaluator/cases-3.ss" register-evaluator-cases-3!)
        (only-in "./qualification/context-temporal/evaluator/cases-4.ss" register-evaluator-cases-4!)
        (only-in "./qualification/context-temporal/evaluator/cases-5.ss" register-evaluator-cases-5!)
        (only-in "./qualification/context-temporal/evaluator/cases-6.ss" register-evaluator-cases-6!)
        (only-in "./qualification/context-temporal/evaluator/cases-7.ss" register-evaluator-cases-7!)
        (only-in "./qualification/context-temporal/evaluator/cases-8.ss" register-evaluator-cases-8!))
(export temporal-evaluator-test)

(def temporal-evaluator-test
  (test-suite "original evaluator positive proof admission"
    (register-evaluator-cases-1!)
    (register-evaluator-cases-2!)
    (register-evaluator-cases-3!)
    (register-evaluator-cases-4!)
    (register-evaluator-cases-5!)
    (register-evaluator-cases-6!)
    (register-evaluator-cases-7!)
    (register-evaluator-cases-8!)))
