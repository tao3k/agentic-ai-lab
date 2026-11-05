;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Standard development consumer; init owns the selected Module source closure.
(import :std/build-script :clan/poo/object
        (only-in "./init.ss" agentic-ai-lab/dev/d2.init.exports))
(defbuild-script ((.get agentic-ai-lab/dev/d2.init.exports std-make-spec) '()))
