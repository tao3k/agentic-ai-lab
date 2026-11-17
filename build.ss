#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .call .get .o)
        (only-in :std/source this-source-file)
        (only-in :std/build-script defbuild-script)
        (only-in :tao3k/yuanxu/module-system/building/build-script defmodule-build-script)
        (only-in "./init.ss" tao3k/agentic-ai-lab.init.exports))

;; Downstream packages import this public library independently of the
;; selected Module graph. Retain it through the init-owned Make projection.
(def LabBuild
  (.o (:: @ tao3k/agentic-ai-lab.init.exports)
      build: (.call tao3k/agentic-ai-lab.init.exports .yuanxu-init
               '("modules/module-authoring/interface"))))

(defmodule-build-script
  (defbuild-script (.get LabBuild std-make-spec))
  (.o))
