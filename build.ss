#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :tao3k/yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  (register-module-build-source! (path-directory (this-source-file)) 'tao3k/agentic-ai-lab))

(import (only-in :std/source this-source-file)
        (only-in :std/build-script defbuild-script)
        (only-in :clan/poo/object .get)
        (only-in :tao3k/yuanxu/module-system/building/products current-build-module-roots)
        (only-in "./init.ss" tao3k/agentic-ai-lab.init.exports))
(export main)

(defbuild-script
  ;; Compiled Lab interfaces refer to the package prelude by name.
  (cons "prelude"
    (parameterize ((current-build-module-roots '(temporal-causality)))
      (.get tao3k/agentic-ai-lab.init.exports std-make-spec))))
