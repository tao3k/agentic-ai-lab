;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Concrete AI capability decoration after Core selection admission.
(import (only-in :clan/poo/object .o .ref)
        (only-in :agentic-ai-lab/modules/ai-agentic-context/config agentic-ai-lab-ai-agentic-context-module)
        (only-in :agentic-ai-lab/modules/workflow/scenario/configuration/selection-policy agentic-ai-lab-product-use-module))
(export agentic-ai-lab-modules-system-use-module/ai)
(def (agentic-ai-lab-modules-system-use-module/ai module flags)
  (let (selections (agentic-ai-lab-product-use-module module flags))
    (if (eq? module 'ai-agentic-context)
      (let* ((descriptor (agentic-ai-lab-ai-agentic-context-module (if (memq '+memory flags) #t #f)))
             (manifest (.ref (.ref descriptor 'config) 'feature-manifest)))
        (map (lambda (selection)
               (.o (:: @ selection) module-descriptor: descriptor feature-manifest: manifest)) selections))
      selections)))
