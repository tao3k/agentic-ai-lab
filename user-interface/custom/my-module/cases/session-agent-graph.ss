;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream multi-agent session graph case.
;;; Invariant: this is declarative graph/registry data; message delivery,
;;; providers, tools, and sandbox runtime stay behind Marlin handoff.

(import :agentic-ai-lab/modules/session/syntax)

(export agentic-ai-lab-custom-my-module-session-agent-graph-case)

(def agentic-ai-lab-custom-my-module-session-agent-graph-case
  (agentic-ai-lab-session-cases
  (session-case custom-session-agent-graph-case
    (metadata (source . user-interface)
              (case . session-agent-graph))
    (objects
     (root-session
      (session custom/root-session
        (chunk request user
               "Coordinate build and audit sub-agents.")
        (lineage root)
        (placement agent/nono)
        (metadata (source . user-interface)
                  (case . session-agent-graph))))
     (build-session
      (session custom/build-session
        (chunk build assistant
               "Run the report-only build verification branch.")
        (lineage child-agent custom/root-session)
        (placement agent/nono)
        (metadata (agent . build-agent))))
     (audit-session
      (session custom/audit-session
        (chunk audit assistant
               "Audit the build result through a declared channel.")
        (lineage child-agent custom/root-session)
        (placement agent/nono)
        (metadata (agent . audit-agent))))
     (build-node
      (session-agent-node agent/build
        (project custom/project)
        (root custom/root-session)
        (parent custom/root-session)
        (system custom/build-system)
        (input custom/root-session)
        (output custom/build-session)
        (peers custom/audit-session)
        (channels channel/build-audit)
        (model policy/build-agent-model)
        (prompt policy/build-agent-prompt)
        (tools policy/build-agent-tools)
        (hook-tools policy/pre-check-hook-tools)
        (resources policy/build-agent-resources)
        (durable durable/custom-project)
        (tool-refs read-workspace-file run-build-command)
        (memory session/memory)
        (sandbox agent/nono)
        (role builder)
        (result agentic-ai-lab.session.agent.build-result.v1)))
     (audit-node
      (session-agent-node agent/audit
        (project custom/project)
        (root custom/root-session)
        (parent custom/root-session)
        (system custom/audit-system)
        (input custom/build-session)
        (output custom/audit-session)
        (peers custom/build-session)
        (channels channel/build-audit channel/audit-root)
        (model policy/audit-agent-model)
        (prompt policy/audit-agent-prompt)
        (tools policy/audit-agent-tools)
        (hook-tools policy/pre-check-hook-tools)
        (resources policy/audit-agent-resources)
        (durable durable/custom-project)
        (tool-refs read-workspace-file)
        (memory session/memory)
        (sandbox agent/nono)
        (role auditor)
        (result agentic-ai-lab.session.agent.audit-result.v1)))
     (root-entry
      (session-registry-entry root-session
        (agent agent/root)
        (channels channel/audit-root)
        (policies (isolation root))))
     (build-entry
      (session-agent-node-registry-entry build-node build-session))
     (audit-entry
      (session-agent-node-registry-entry audit-node audit-session))
     (registry
      (session-registry custom/project
        (roots custom/root-session)
        (children custom/build-session custom/audit-session)
        (active custom/root-session)
        (entries root-entry build-entry audit-entry)))
     (build-audit-channel
      (session-communication-channel custom/project
        channel/build-audit
        (relation sibling)
        (sessions custom/build-session custom/audit-session)
        (agents agent/build agent/audit)
        (messages artifact)
        (delivery declared-channel-only)
        (metadata (source . user-interface)
                  (case . session-agent-graph))))
     (audit-root-channel
      (session-communication-channel custom/project
        channel/audit-root
        (relation child-parent)
        (sessions custom/audit-session custom/root-session)
        (agents agent/audit agent/root)
        (messages receipt)
        (delivery receipt-only)
        (metadata (source . user-interface)
                  (case . session-agent-graph))))
     (build-audit-message
      (session-communication custom/project
        (relation sibling)
        (roots custom/root-session custom/root-session)
        (sessions custom/build-session custom/audit-session)
        (agents agent/build agent/audit)
        (channel channel/build-audit)
        (message artifact ((artifact . build-report)))
        (delivery declared-channel-only)
        (metadata (source . user-interface)
                  (case . session-agent-graph))))
     (audit-root-message
      (session-communication custom/project
        (relation child-parent)
        (roots custom/root-session custom/root-session)
        (sessions custom/audit-session custom/root-session)
        (agents agent/audit agent/root)
        (channel channel/audit-root)
        (message receipt ((receipt . audit-result)))
        (delivery receipt-only)
        (metadata (source . user-interface)
                  (case . session-agent-graph))))
     (graph
      (session-agent-graph custom/project
                           custom/root-session
                           (list build-node audit-node)
                           (list root-session
                                 build-session
                                 audit-session)
                           registry
                           (list build-audit-message
                                 audit-root-message)
                           (list
                            (cons 'source 'user-interface)
                            (cons 'case 'session-agent-graph)
                            (cons 'communication-channel-receipts
                                  (list build-audit-channel
                                        audit-root-channel))))))
    (rows registry graph build-audit-channel audit-root-channel
          build-audit-message audit-root-message)
    (row-groups
     (session-communication-channel-rows build-audit-channel
                                         audit-root-channel)
     (session-communication-rows build-audit-message
                                 audit-root-message)))))
