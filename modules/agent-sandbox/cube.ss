;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Owner: CubeSandbox profile alignment lives in this backend module.
;;; Boundary: core provides schema, task, envelope, and adapter protocols.
;;; Import contract: users opt in through =:agentic-ai-lab/modules/agent-sandbox/cube=.
;;; Runtime contract: this module emits profile data only.
;;; Runtime contract: Cube API calls stay behind Marlin runtime commands.
;;; Runtime contract: remote snapshot lifecycle stays out of Scheme.
;;; Policy evidence: tests should import this module when they assert Cube defaults.

(import :agentic-ai-lab/modules/agent-sandbox/profile
        :agentic-ai-lab/modules/agent-sandbox/projection-syntax
        :agentic-ai-lab/modules/agent-sandbox/cube-interface)

(export make-cube-agent-sandbox-profile-descriptor
        make-cube-agent-sandbox-profile
        (import: :agentic-ai-lab/modules/agent-sandbox/cube-interface))

;;; Cube profiles model remote or clustered KVM-backed sandboxes. The ordinary
;;; helper form keeps backend defaults explicit and avoids macro-only evidence.
;; : (forall (o) (-> BackendRef [o] AgentSandboxProfileDescriptor))
;; : (-> BackendRef [Alist] AgentSandboxProfileDescriptor)
(def (make-cube-agent-sandbox-profile-descriptor backend-ref . maybe-options)
  (make-agent-sandbox-backend-profile-descriptor
   'cube-profile
   'cube
   backend-ref
   '((mode . egress-filtered))
   '((filesystem . snapshot)
     (isolation . kvm)
     (api . e2b-compatible))
   '((filesystem
      (scope . snapshot)
      (snapshot . clone))
     (snapshot . clone)
     (resume . supported))
   (lambda (profile-ref)
     (agent-sandbox-field-rows
      (backend 'cube)
      (template profile-ref)))
   (if (null? maybe-options) '() (car maybe-options))))

;;; Boundary: make cube agent sandbox profile is the policy-visible edge for
;;; sandbox behavior, keeping validation, lookup, or projection
;;; responsibilities centralized for callers.
;; : (-> BackendRef [Alist] AgentSandboxBackendProfile)
(def (make-cube-agent-sandbox-profile backend-ref . maybe-options)
  (agent-sandbox-profile-descriptor->profile
   (make-cube-agent-sandbox-profile-descriptor
    backend-ref
    (if (null? maybe-options) '() (car maybe-options)))))
