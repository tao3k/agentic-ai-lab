;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in "./init.ss" yuanxu-context-consumer.init.exports)
        (only-in :clan/poo/object .get)
        (only-in :std/error Error? Error-irritants Error-message))
(export main)
(def (main)
  (def failure
    (with-catch values
      (lambda () (.get yuanxu-context-consumer.init.exports Consumer review) #f)))
  (unless (and (Error? failure)
               (equal? (Error-message failure) "Module Feature Contract rejected scope")
               (memq 'agentic-ai-lab/modules/ai-agentic-context/interface (Error-irritants failure))
               (memq 'agentic-ai-lab/modules/ai-agentic-context/interface/memory (Error-irritants failure)))
    (error "expected a qualified Feature Contract rejection" failure))
  (displayln "LAB-CONTEXT-REFUSAL-OK owner=ai-agentic-context feature=memory"))
