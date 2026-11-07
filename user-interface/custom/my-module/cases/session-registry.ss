;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: downstream session registry case.
;;; Invariant: registry rows describe project/root/child address space only;
;;; Scheme does not retain live runtime state.

(import :agentic-ai-lab/modules/session/syntax)

(export agentic-ai-lab-custom-my-module-session-registry-case)

(def agentic-ai-lab-custom-my-module-session-registry-case
  (agentic-ai-lab-session-cases
  (session-case custom-session-registry-case
    (metadata (source . user-interface)
              (case . session-registry))
    (objects
     (root-session
      (session custom/root-session
        (chunk request user
               "Coordinate build, audit, and release sessions.")
        (lineage root)
        (placement agent/nono)
        (metadata (source . user-interface)
                  (case . session-registry))))
     (build-session
      (session custom/build-session
        (chunk build assistant
               "Run build verification.")
        (lineage child-agent custom/root-session)
        (placement agent/nono)))
     (audit-session
      (session custom/audit-session
        (chunk audit assistant
               "Audit build verification.")
        (lineage child-agent custom/root-session)
        (placement agent/nono)))
     (root-entry
      (session-registry-entry root-session
        (agent agent/root)
        (channels channel/root-build channel/audit-root)
        (policies
         (isolation ((mode . root)))
         (durable ((policy-id . durable/custom-project)
                   (valid? . #t))))
        (metadata (source . user-interface)
                  (case . session-registry))))
     (build-entry
      (session-registry-entry build-session
        (agent agent/build)
        (channels channel/build-root channel/build-audit)
        (policies
         (context ((allowed-session-refs . (custom/root-session))))
         (history ((allowed-records . (record/last-failure))))
         (sharing ((project-workspace
                     (access . read)
                     (accounting . custom/root-session))))
         (resource ((capability-refs . (project-workspace build-cache))))
         (durable ((policy-id . durable/custom-project)
                   (valid? . #t))))))
     (audit-entry
      (session-registry-entry audit-session
        (agent agent/audit)
        (channels channel/build-audit channel/audit-root)
        (policies
         (context ((allowed-session-refs . (custom/root-session
                                            custom/build-session))))
         (history ((allowed-records . (record/last-failure))))
         (sharing ((project-workspace
                     (access . read)
                     (accounting . custom/root-session))))
         (resource ((capability-refs . (project-workspace))))
         (durable ((policy-id . durable/custom-project)
                   (valid? . #t))))))
     (registry
      (session-registry custom/project
        (roots custom/root-session)
        (children custom/build-session custom/audit-session)
        (active custom/root-session)
        (entries root-entry build-entry audit-entry)
        (metadata (source . user-interface)
                  (case . session-registry)))))
    (rows registry))))
