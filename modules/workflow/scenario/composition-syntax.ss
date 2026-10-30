;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product syntax for declaring one stable Scenario composition root.

(import (only-in :agentic-ai-lab/modules/workflow/scenario/profile-root
                 agentic-ai-lab-profile-bundle-root))

(export user-composition)

(defsyntax (user-composition stx)
  (syntax-case stx ()
    ((_ composition-name composition-expression)
     (identifier? #'composition-name)
     (syntax/loc stx
       (def composition-name
         (agentic-ai-lab-profile-bundle-root
          'composition-name
          composition-expression))))
    (_
     (raise-syntax-error
      #f
      "user-composition expects one identifier and one value expression"
      stx))))
