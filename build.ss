#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (for-syntax
          (only-in :std/source this-source-file)
          (only-in :yuanxu/module-system/building/source-package register-module-build-source!)))
(begin-syntax
  (register-module-build-source! (path-directory (this-source-file)) 'agentic-ai-lab))

(import (only-in :clan/poo/object .get)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "./init.ss" agentic-ai-lab.init.exports)
        (only-in "./build-spec.ss" agentic-ai-lab-build-spec))

;; The selected init owns source lowering; the SDK owns Make and dispatch.
(def modules-spec (.get agentic-ai-lab.init.exports std-make-spec))
(defbuild-script (modules-spec (agentic-ai-lab-build-spec)))
