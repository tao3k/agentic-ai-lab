#!/usr/bin/env -S gerbil interactive
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Official package preparation of the existing init-owned qualification.
;;; No Suite, Harness, compiler inventory or execution verdict lives here.
(import (only-in :clan/poo/object .get)
        (only-in :std/source this-source-file)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "../../../init.ss" agentic-ai-lab.init.exports))
(def root (path-expand "../../.." (path-directory (this-source-file))))
(def qualifications (.get agentic-ai-lab.init.exports tests qualification))
;; Keep the same installed-library priority and root/prefix as native tests.
;; Init supplies discovery, source checks, Make inputs and signed publication.
(defbuild-script ((.get qualifications std-make-spec))
  srcdir: root prefix: "agentic-ai-lab")
