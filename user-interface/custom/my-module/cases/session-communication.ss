;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream session communication case.
;;; Invariant: communication rows are report-only; Scheme does not deliver
;;; messages, mutate sessions, or open runtime channels.

(import :agentic-ai-lab/modules/session/syntax)

(export agentic-ai-lab-custom-my-module-session-communication-case)

(def agentic-ai-lab-custom-my-module-session-communication-case
  (agentic-ai-lab-session-cases
  (session-case custom-session-communication-case
    (metadata (source . user-interface)
              (case . session-communication))
    (objects
     (root-build-channel
      (session-communication-channel custom/project
        channel/root-build
        (relation parent-child)
        (sessions custom/root-session custom/build-session)
        (agents agent/root agent/build)
        (messages request)
        (delivery receipt-only)
        (metadata (source . user-interface)
                  (case . session-communication)
                  (communication-ledger-ref . runtime/custom-communication-ledger)
                  (durable-policy-ref . durable/custom-project))))
     (build-root-channel
      (session-communication-channel custom/project
        channel/build-root
        (relation child-parent)
        (sessions custom/build-session custom/root-session)
        (agents agent/build agent/root)
        (messages result)
        (delivery receipt-only)
        (metadata (source . user-interface)
                  (case . session-communication)
                  (communication-ledger-ref . runtime/custom-communication-ledger)
                  (durable-policy-ref . durable/custom-project))))
     (build-audit-channel
      (session-communication-channel custom/project
        channel/build-audit
        (relation sibling)
        (sessions custom/build-session custom/audit-session)
        (agents agent/build agent/audit)
        (messages artifact)
        (delivery declared-channel-only)
        (metadata (source . user-interface)
                  (case . session-communication)
                  (communication-ledger-ref . runtime/custom-communication-ledger)
                  (durable-policy-ref . durable/custom-project))))
     (audit-release-channel
      (session-communication-channel custom/project
        channel/audit-release
        (relation cross-root)
        (sessions custom/audit-session custom/release-session)
        (agents agent/audit agent/release)
        (messages receipt)
        (delivery explicit-project-root)
        (metadata (source . user-interface)
                  (case . session-communication)
                  (communication-ledger-ref . runtime/custom-communication-ledger)
                  (durable-policy-ref . durable/custom-project))))
     (parent-child
      (session-communication custom/project
        (relation parent-child)
        (roots custom/root-session custom/root-session)
        (sessions custom/root-session custom/build-session)
        (agents agent/root agent/build)
        (channel channel/root-build)
        (message request
                 ((summary . "run build checks")
                  (artifact-ref . request/current)))
        (delivery receipt-only)
        (metadata (source . user-interface)
                  (case . session-communication)
                  (communication-ledger-ref . runtime/custom-communication-ledger)
                  (durable-policy-ref . durable/custom-project))))
     (child-parent
      (session-communication custom/project
        (relation child-parent)
        (roots custom/root-session custom/root-session)
        (sessions custom/build-session custom/root-session)
        (agents agent/build agent/root)
        (channel channel/build-root)
        (message result
                 ((summary . "build checks completed")
                  (receipt-ref . receipt/build-result)))
        (delivery receipt-only)
        (metadata (source . user-interface)
                  (case . session-communication)
                  (communication-ledger-ref . runtime/custom-communication-ledger)
                  (durable-policy-ref . durable/custom-project))))
     (sibling
      (session-communication custom/project
        (relation sibling)
        (roots custom/root-session custom/root-session)
        (sessions custom/build-session custom/audit-session)
        (agents agent/build agent/audit)
        (channel channel/build-audit)
        (message artifact
                 ((artifact . build-report)
                  (visibility . declared-channel)))
        (delivery declared-channel-only)
        (metadata (source . user-interface)
                  (case . session-communication)
                  (communication-ledger-ref . runtime/custom-communication-ledger)
                  (durable-policy-ref . durable/custom-project))))
     (cross-root
      (session-communication custom/project
        (relation cross-root)
        (roots custom/root-session custom/release-root)
        (sessions custom/audit-session custom/release-session)
        (agents agent/audit agent/release)
        (channel channel/audit-release)
        (message receipt
                 ((receipt . release-gate)
                  (approval . pending)))
        (delivery explicit-project-root)
        (metadata (source . user-interface)
                  (case . session-communication)
                  (communication-ledger-ref . runtime/custom-communication-ledger)
                  (durable-policy-ref . durable/custom-project)))))
    (rows)
    (row-groups
     (session-communication-channel-rows root-build-channel
                                         build-root-channel
                                         build-audit-channel
                                         audit-release-channel)
     (session-communication-rows parent-child child-parent sibling cross-root)))))
