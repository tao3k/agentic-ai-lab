;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module-system POO objects for downstream user declarations.
;;; Invariant: root user-interface files never own object contracts.

(import :yuanxu/module-system/schema/interface
        :agentic-ai-lab/modules/sandbox-core/shared-object)

(export agentic-ai-lab-user-interface-shared-sandbox-object
        agentic-ai-lab-user-interface-root-module-objects)

(def agentic-ai-lab-user-interface-shared-sandbox-object
  (yuanxu-module-object
   'objects.user-interface.shared.sandbox
   (list agentic-ai-lab-shared-sandbox-object)
   (list
    (yuanxu-module-field-contract
     'flags YuanxuModuleListType 'append '(doctor) '((scope . user-interface))))
   '((namespace . objects.user-interface)
     (domain . sandbox)
     (inherits . objects.shared.sandbox))))

(def agentic-ai-lab-user-interface-root-module-objects
  (list agentic-ai-lab-user-interface-shared-sandbox-object))
