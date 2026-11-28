;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public inert sandbox profile, request, and resource objects.

(import "profile.ss" "request.ss" "resource.ss"
        (only-in :clan/poo/object .def .get .ref)
        (only-in "types.ss" agentic-ai-lab-sandbox-profile-kind SandboxProfilesScopeContract)
        (only-in "func.ss" normalize-sandbox-profile agenticAiLabSandboxProfilesPresentation))
(export (import: "profile.ss")
        (import: "request.ss")
        (import: "resource.ss"))
;; Reusable business defaults. A Profile's Config overrides these ordinary
;; slots; it never selects another parser or module loading mechanism.
(.def SandboxProfile.
  kind: agentic-ai-lab-sandbox-profile-kind
  name: 'default
  backend-kind: 'nono
  backend-ref: 'nono
  network-policy: '(deny-by-default)
  capabilities: '(process filesystem tmpdir)
  resource-policy: '()
  metadata: '((declared-by . module-config) (runtime-executed . #f)))

(.def (SandboxProfiles. @ (.get SandboxProfilesScopeContract proto) config profiles)
  profiles: (map (lambda (value) (normalize-sandbox-profile SandboxProfile. value))
                 (.ref config 'profiles))
  preview: (agenticAiLabSandboxProfilesPresentation profiles))
(export SandboxProfile. SandboxProfiles.)
