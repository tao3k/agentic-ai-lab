;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test (only-in "./scenario" main)
        (rename-in (only-in "../temporal-physical-native/model-scenario" main) (main physical-main)))
(export temporal-model-native-load-test)
(def temporal-model-native-load-test
  (test-suite "ASP model scenario entry"
    (test-case "native entry exists without running a paid batch"
      (check-equal? (procedure? main) #t)
      (check-equal? (procedure? physical-main) #t))))
