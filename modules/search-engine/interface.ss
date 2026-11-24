;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .def .o)
        "types.ss" "objects.ss" "funs.ss" "config.ss" "attempt.ss" "engine.ss")
(export SearchEngine
        (import: "types.ss")
        (import: "objects.ss")
        (import: "funs.ss")
        (import: "config.ss") (import: "attempt.ss") (import: "engine.ss"))

(.def SearchEngine
  identity: 'search-engine
  tags: '(search engine)
  core: (.o scope-contract: SearchEngineScope
            exports: (.o library: 'tao3k/agentic-ai-lab/modules/search-engine/interface))
  features: (.o))
