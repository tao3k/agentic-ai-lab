;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: aggregate Funflow config checks in one Gerbil loader.

(import "./funflow-config-pipeline-direct-test"
        "./funflow-config-pipeline-downstream-test"
        "./funflow-config-pipeline-error-test")

(import :std/test)

(export funflow-config-pipeline-test)

(def funflow-config-pipeline-test
  (test-suite "Funflow config pipeline"
    funflow-config-pipeline-direct-test
    funflow-config-pipeline-downstream-test
    funflow-config-pipeline-error-test))
