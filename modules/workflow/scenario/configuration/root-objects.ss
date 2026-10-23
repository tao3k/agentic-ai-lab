;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: module-system POO objects for downstream user declarations.
;;; Invariant: root user-interface files never own object contracts.

(import :yuanxu/module-system/schema/interface
        :poo-flow/modules/sandbox-core/shared-object)

(export poo-flow-user-interface-shared-sandbox-object
        poo-flow-user-interface-root-module-objects)

(def poo-flow-user-interface-shared-sandbox-object
  (yuanxu-module-object
   'objects.user-interface.shared.sandbox
   (list poo-flow-shared-sandbox-object)
   (list
    (yuanxu-module-field-contract
     'flags YuanxuModuleListType 'append '(doctor) '((scope . user-interface))))
   '((namespace . objects.user-interface)
     (domain . sandbox)
     (inherits . objects.shared.sandbox))))

(def poo-flow-user-interface-root-module-objects
  (list poo-flow-user-interface-shared-sandbox-object))
