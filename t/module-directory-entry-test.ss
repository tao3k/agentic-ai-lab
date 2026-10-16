;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :std/test test-suite check-equal?)
        (only-in :clan/poo/object .get)
        (only-in :core/observability/testing-case poo-flow-test-case)
        :core/module-system/interface
        (only-in :poo-flow/init poo-flow-module-init))
(export module-directory-entry-test)
(def module-directory-entry-test
  (test-suite "Product init uses the Core source entry without a runtime Loader"
    (poo-flow-test-case "compiled declaration and source preparation agree"
      (let (view (poo-flow-load-modules "./init.ss"))
        (check-equal? (.get poo-flow-module-init mode) 'auto)
        (check-equal? (.get view context intent mode) (.get poo-flow-module-init mode))
        (check-equal? (.get view context intent root) (.get poo-flow-module-init root))
        (check-equal? (.get view selected-records) '())
        ((.get view admit-current))))))
