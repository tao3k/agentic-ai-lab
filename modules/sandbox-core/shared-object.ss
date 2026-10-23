;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: shared sandbox object owned by the sandbox module family.

(import :yuanxu/module-system/schema/interface)

(export poo-flow-shared-sandbox-object
        poo-flow-shared-module-objects)

(def poo-flow-shared-sandbox-object
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

(def poo-flow-shared-module-objects
  (list poo-flow-shared-sandbox-object))
