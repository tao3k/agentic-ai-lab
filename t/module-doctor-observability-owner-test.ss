;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Doctor is an Observability projection, not a separate UI/module package.
(import (only-in :core/observability/testing-case poo-flow-test-case)
        (only-in :std/test test-suite check-equal?)
        (only-in :poo-flow/modules/workflow/scenario/configuration/module-diagnostics
                 poo-flow-module-doctor
                 poo-flow-module-doctor-report-status)
        (only-in :poo-flow/modules/workflow/scenario/configuration/doctor-presentation
                 poo-flow-module-doctor-presentation-kind))

(export module-doctor-observability-owner-test)

(def module-doctor-observability-owner-test
  (test-suite "module doctor observability owner"
    (poo-flow-test-case "exports module diagnosis and presentation from one owner"
      (check-equal?
       (poo-flow-module-doctor-report-status (poo-flow-module-doctor '()))
       'ok)
      (check-equal?
       poo-flow-module-doctor-presentation-kind
       "poo-flow.modules.doctor-presentation.v1"))))
