;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/type Record)
        (only-in :clan/poo/mop Type.))
(export ReviewScopeContract)
(def RefineContext (.cc Type. identity: 'review/refine .element?: procedure?))
(def ReviewScopeContract
  (.cc (Record context: [RefineContext]) identity: 'review/scope))
