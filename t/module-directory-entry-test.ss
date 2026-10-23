;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :std/test test-suite check-equal?)
        (only-in :clan/poo/object .get)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        :yuanxu/module-system/interface
        (only-in :agentic-ai-lab/init yuanxu-module-init))
(export module-directory-entry-test)
(def module-directory-entry-test
  (test-suite "Product init uses the Core source entry without a runtime Loader"
    (yuanxu-test-case "compiled declaration and source preparation agree"
      (let (view (yuanxu-load-modules "./init.ss"))
        (check-equal? (.get yuanxu-module-init mode) 'auto)
        (check-equal? (.get view context intent mode) (.get yuanxu-module-init mode))
        (check-equal? (.get view context intent root) (.get yuanxu-module-init root))
        (check-equal? (.get view selected-records) '())
        ((.get view admit-current))))))
