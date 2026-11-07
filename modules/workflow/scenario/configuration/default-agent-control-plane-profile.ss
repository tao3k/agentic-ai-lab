;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Maintainer-owned advanced Profile.  Ordinary user configuration imports
;;; and composes this value without reopening its Stage slot space.

(import (only-in :clan/poo/object .def .o))
(export DefaultAgentControlPlaneProfile)

(.def DefaultAgentControlPlaneProfile
  (identity 'default-agent-control-plane)
  (stages
   (.o development:
       (.o graph: 'pull-request-agent-loop
           loop: (.o fuel: 8 exit: 'tested-change)
           proofs:
           (.o typed-state-merge: #t
               tool-arguments-match-schema: #t))
       staging:
       (.o graph: 'release-candidate-agent-loop
           loop: (.o fuel: 5 exit: 'qualified-candidate)
           proofs:
           (.o tool-permission-before-call: #t
               runtime-receipt-matches-tool-plan: #t))
       production:
       (.o graph: 'production-agent-loop
           loop: (.o fuel: 3 exit: 'accepted-result)
           proofs:
           (.o explicit-runtime-handoff: #t
               trace-covers-tool-request-call-result: #t)
           handoff: 'marlin-control-plane))))
