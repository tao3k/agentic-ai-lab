;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared sandbox object owned by the sandbox module family.

(import :yuanxu/module-system/schema/interface)

(export agentic-ai-lab-shared-sandbox-object
        agentic-ai-lab-shared-module-objects)

(def agentic-ai-lab-shared-sandbox-object
  (yuanxu-module-object
   'objects.shared.sandbox
   '()
   (list
    (yuanxu-module-field-contract
     'backend YuanxuModuleSymbolType 'override 'sandbox '((scope . shared)))
    (yuanxu-module-field-contract
     'flags YuanxuModuleListType 'append '() '((scope . shared)))
    (yuanxu-module-field-contract
     'runtime-args YuanxuModuleListType 'append '() '((scope . shared))))
   '((namespace . objects.shared)
     (domain . sandbox))))

(def agentic-ai-lab-shared-module-objects
  (list agentic-ai-lab-shared-sandbox-object))
