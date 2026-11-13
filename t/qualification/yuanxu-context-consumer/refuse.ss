;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in "./init.ss" yuanxu-context-consumer.init.exports)
        (only-in :clan/poo/object .get)
        (only-in :tao3k/yuanxu/module-system/source/publication admit-module-value!)
        (only-in :tao3k/agentic-ai-lab/modules/ai-agentic-context/types ContextMemoryScopeContract)
        (only-in :std/error Error? Error-irritants Error-message))
(export main)
(def (main)
  (def failure
    (with-catch values
      (lambda ()
        (def exports yuanxu-context-consumer.init.exports)
        (def refined ((.get exports Consumer review context) (.get exports Lab ai-agentic-context)))
        (with-catch
          (lambda (cause)
            (error "Module Feature Contract rejected scope"
                   'tao3k/agentic-ai-lab/modules/ai-agentic-context/interface
                   'tao3k/agentic-ai-lab/modules/ai-agentic-context/interface/memory cause))
          (lambda () (admit-module-value! ContextMemoryScopeContract refined #f)))
        #f)))
  (unless (and (Error? failure)
               (equal? (Error-message failure) "Module Feature Contract rejected scope")
               (memq 'tao3k/agentic-ai-lab/modules/ai-agentic-context/interface (Error-irritants failure))
               (memq 'tao3k/agentic-ai-lab/modules/ai-agentic-context/interface/memory (Error-irritants failure)))
    (error "expected a qualified Feature Contract rejection" failure))
  (displayln "LAB-CONTEXT-REFUSAL-OK owner=ai-agentic-context feature=memory"))
