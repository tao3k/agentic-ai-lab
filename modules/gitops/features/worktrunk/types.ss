;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .cc)
        (only-in :clan/poo/type Object)
        (only-in :clan/poo/type Record)
        (only-in "../../dependency.ss" GitOpsRevisionedBinding GitOpsDependencyName GitOpsSelectionReader))
(export GitOpsWorkTrunkBinding GitOpsWorkTrunkScope)

(def GitOpsWorkTrunkBinding
  (.cc (Record [GitOpsRevisionedBinding] worktrunk: [GitOpsDependencyName])
       identity: 'gitops/worktrunk-binding))
(def GitOpsWorkTrunkScope
  (.cc (Record worktrunk-prototype: [Object] worktrunk-dependency: [GitOpsSelectionReader])
       identity: 'gitops/worktrunk-scope))
