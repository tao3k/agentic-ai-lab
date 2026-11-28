#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import (only-in :clan/poo/object .get)
        (only-in :std/source this-source-file)
        (only-in :std/build-script defbuild-script)
        (only-in "./init.ss" tao3k/agentic-ai-lab.init.exports))

(defbuild-script (.get tao3k/agentic-ai-lab.init.exports CAbi __std-make-spec))
