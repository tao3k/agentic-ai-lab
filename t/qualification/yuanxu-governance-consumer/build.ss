#!/usr/bin/env gxi
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :std/source this-source-file)
        (only-in :tao3k/yuanxu/module-system/building/source-closure package-library-spec)
        (only-in :std/build-script defbuild-script)
        (only-in "./init.ss" std-make-spec))
(export main)
(def application-spec
  (package-library-spec (path-directory (this-source-file)) 'yuanxu-governance-consumer '("main.ss")))
(defbuild-script (append std-make-spec application-spec))
