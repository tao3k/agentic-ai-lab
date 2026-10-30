;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :std/test test-suite check-equal?)
        (only-in :clan/poo/object .get .ref .all-slots .ref/cached)
        (only-in :yuanxu/observability/testing-case yuanxu-test-case)
        (only-in :yuanxu/module-system/interface yuanxu-load-modules)
        (only-in :agentic-ai-lab/init agentic-ai-lab.init.exports))
(export module-directory-entry-test)
(def module-directory-entry-test
  (test-suite "Product init uses the Core source entry without a runtime Loader"
    (yuanxu-test-case "compiled declaration and source preparation agree"
      (let (view (yuanxu-load-modules "./init.ss"))
        (check-equal? (.get view context intent mode) 'auto)
        (check-equal?
          (map (lambda (window) (.get window mount)) (.get view context intent windows))
          '(Core modules scenarios))
        (for-each
          (lambda (mount)
            (check-equal? (.all-slots (.ref agentic-ai-lab.init.exports mount))
                          (.all-slots (.ref (.get view modules) mount))))
          '(Core modules scenarios))
        (check-equal? (.ref/cached view 'selected-graph) #f)
        (check-equal? (.ref/cached view 'build-graph) #f)
        (check-equal? (.ref/cached (.get agentic-ai-lab.init.exports Core funflow) 'scope) #f)
        ((.get view admit-current))))))
