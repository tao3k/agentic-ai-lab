;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .cc)
        (only-in :clan/poo/type Object)
        (only-in :clan/poo/type Record)
        (only-in "../../dependency.ss" GitOpsRevisionedBinding GitOpsDependencyName GitOpsSelectionReader))
(export GitOpsWorkBinding GitOpsWorkScope)

(def GitOpsWorkBinding
  (.cc (Record [GitOpsRevisionedBinding] work: [GitOpsDependencyName])
       identity: 'gitops/work-binding))
(def GitOpsWorkScope
  (.cc (Record work-prototype: [Object] work-dependency: [GitOpsSelectionReader])
       identity: 'gitops/work-scope))
