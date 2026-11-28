;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Search declarations are report-only and execute only in consumer runtimes.
(import (only-in :clan/poo/object .ref .slot? object?)
        (only-in :clan/poo/type define-type Type.))
(export SearchEngineScope +agentic-ai-lab-search-schema+)

(def +agentic-ai-lab-search-schema+ 'agentic-ai-lab.search-framework.v1)

(define-type (SearchEngineScope @ Type.)
  identity: 'search-engine/scope
  .element?: (lambda (value)
               (and (object? value)
                    (.slot? value 'library)
                    (eq? (.ref value 'library) 'tao3k/agentic-ai-lab/modules/search-engine/interface))))
