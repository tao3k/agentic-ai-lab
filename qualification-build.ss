#!/usr/bin/env -S gerbil interactive
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Standard build declaration, consumed by the development gerbil build command.
;;; Init owns discovery, source guards, native Make inputs and publication.
(import (only-in :clan/poo/object .get)
        (only-in :yuanxu/module-system/building/script defbuild-script)
        (only-in "./init.ss" agentic-ai-lab.init.exports))
;; Installed libraries have the same priority as the actual test consumer.
;; This declaration owns no Case inventory, Harness, policy or result verdict.
(defbuild-script
  ((.get agentic-ai-lab.init.exports tests qualification std-make-spec))
  prefix: "agentic-ai-lab")
