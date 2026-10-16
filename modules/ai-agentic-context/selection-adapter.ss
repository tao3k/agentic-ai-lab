;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Concrete AI capability decoration after Core selection admission.
(import (only-in :clan/poo/object .o .ref)
        (only-in :poo-flow/modules/ai-agentic-context/config poo-flow-ai-agentic-context-module)
        (only-in :poo-flow/modules/workflow/scenario/configuration/selection-policy poo-flow-product-use-module))
(export poo-flow-modules-system-use-module/ai)
(def (poo-flow-modules-system-use-module/ai module flags)
  (let (selections (poo-flow-product-use-module module flags))
    (if (eq? module 'ai-agentic-context)
      (let* ((descriptor (poo-flow-ai-agentic-context-module (if (memq '+memory flags) #t #f)))
             (manifest (.ref (.ref descriptor 'config) 'feature-manifest)))
        (map (lambda (selection)
               (.o (:: @ selection) module-descriptor: descriptor feature-manifest: manifest)) selections))
      selections)))
