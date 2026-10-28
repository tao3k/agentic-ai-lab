#!/usr/bin/env -S gerbil interactive
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Standard executable declaration consumed by the official package build.
(import (only-in :clan/poo/object .get)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "./init.ss" agentic-ai-lab.init.exports)
        (only-in "./build-spec.ss" agentic-ai-lab-context-test-demand))
;; Support compilation has its own native expander epoch. This fresh compiler
;; sees the same installed interfaces as a later independent test consumer.
(defbuild-script
  ((.get (agentic-ai-lab-context-test-demand agentic-ai-lab.init.exports) std-make-spec))
  prefix: "agentic-ai-lab")
