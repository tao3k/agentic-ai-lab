;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Internal support shared by semantic tool-core object owners.

(import (only-in :clan/poo/object .ref)
        :agentic-ai-lab/modules/session/objects)

(export agentic-ai-lab-tool-field-rows
        agentic-ai-lab-tool-slot
        agentic-ai-lab-tool-ref?
        agentic-ai-lab-tool-symbol-list?
        agentic-ai-lab-tool-alist?
        agentic-ai-lab-tool-valid-sandbox-profile-ref?)

(def (agentic-ai-lab-tool-field-rows . rows)
  rows)

(def (agentic-ai-lab-tool-slot object key default-value)
  (with-catch
   (lambda (_failure) default-value)
   (lambda ()
     (.ref object key))))

(def (agentic-ai-lab-tool-ref? value)
  (symbol? value))

(def (agentic-ai-lab-tool-symbol-list? values)
  (and (list? values)
       (agentic-ai-lab-session-every? symbol? values)))

(def (agentic-ai-lab-tool-alist? value)
  (list? value))

(def (agentic-ai-lab-tool-valid-sandbox-profile-ref? sandbox-required?
                                               sandbox-profile-ref)
  (or (not sandbox-required?)
      (symbol? sandbox-profile-ref)))
