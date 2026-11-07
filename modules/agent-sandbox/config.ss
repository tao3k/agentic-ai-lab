(import (only-in "func.ss" agentic-ai-lab-sandbox-profile-names agenticAiLabSandboxProfilesPresentation))
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user-facing agent sandbox profile declarations.
;;; Invariant: profiles are inert data until a runtime bridge consumes them.

(import (only-in :clan/poo/object .o .ref object<-alist)
        (only-in :clan/poo/mop element?)
        :agentic-ai-lab/modules/agent-sandbox/profile
        :agentic-ai-lab/modules/agent-sandbox/profile-contract
        :agentic-ai-lab/modules/agent-sandbox/projection-syntax
        :agentic-ai-lab/modules/sandbox-core/profile-support/policy
        :yuanxu/utilities/final-projection-syntax)

(export agentic-ai-lab-sandbox-profile-kind
        AgenticAILabSandboxProfileContract
        agentic-ai-lab-sandbox-profile-contract-admitted?
        agentic-ai-lab-sandbox-profile-type-contract->alist
        agentic-ai-lab-require-sandbox-profile-contract!
        agentic-ai-lab-sandbox-profiles-presentation-kind
        agentic-ai-lab-sandbox-profile
        agentic-ai-lab-sandbox-profiles
        agentic-ai-lab-sandbox-profile-config
        agentic-ai-lab-default-sandbox-profiles
        agentic-ai-lab-default-sandbox-profile-names
        agentic-ai-lab-default-sandbox-profile-presentation)

(import :agentic-ai-lab/modules/agent-sandbox/config-form-support)
;;; Bass-style profile rows are just data recipes. The macro is deliberately a
;;; thin syntax bridge; semantic state lives in the POO profile object slots.
;; agentic-ai-lab-sandbox-profile
;;   : (-> Symbol SandboxProfileForm... PooSandboxProfile)
;;   | contract: expands one profile row into inert POO data only
;;   | doc m%
;;       `agentic-ai-lab-sandbox-profile` expands one named inert profile recipe.
;;
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profile agent/nono
;;         (backend nono)
;;         (network deny-by-default))
;;       ;; => POO profile recipe, not a runtime request
;;       ```
;;     %
(defrules agentic-ai-lab-sandbox-profile ()
  ((_ name form ...)
   (agentic-ai-lab-sandbox-profile-config 'name '(form ...))))

;; agentic-ai-lab-sandbox-profiles
;;   : (-> SandboxProfileRow... [PooSandboxProfile])
;;   | contract: preserves declaration order for agent/tool presentation
;;   | doc m%
;;       `agentic-ai-lab-sandbox-profiles` preserves profile declaration order.
;;
;;       # Examples
;;
;;       ```scheme
;;       (agentic-ai-lab-sandbox-profiles
;;         (agent/nono (backend nono))
;;         (agent/cube (backend cubeSandbox cube-local)))
;;       ;; => ordered profile recipes
;;       ```
;;     %
(defrules agentic-ai-lab-sandbox-profiles ()
  ((_)
   '())
  ((_ (name form ...) profile-clause ...)
   (cons (agentic-ai-lab-sandbox-profile name form ...)
         (agentic-ai-lab-sandbox-profiles profile-clause ...))))

;;; Built-in sandbox profiles are upstream defaults, not user init content. A
;;; downstream project can select or override them later without owning backend
;;; policy recipes in its root configuration file.
;; : PooSandboxProfileList
;; | PooSandboxProfileList = [PooSandboxProfile]
(def agentic-ai-lab-default-sandbox-profiles
  (agentic-ai-lab-sandbox-profiles
   (agent/nono
    (backend nono)
    (network deny-by-default)
    (capabilities process-run filesystem-read filesystem-write tmpdir)
    (resources (filesystem
                (scope . project-workspace)
                (paths
                 ((role . project-workspace)
                  (source . ".")
                  (project-marker . "gerbil.pkg")
                  (mode . read-write)))
                (access . read-write))
               (cpu . 2)
               (memory . "4Gi")
               (timeout-ms . 300000))
    (metadata (intent . coding-agent) (risk . high-demand)))
   (agent/cube
    (backend cube cube-local)
    (network allowlisted "github.com" "crates.io")
    (capabilities process-run filesystem-read cache-mount)
    (resources (filesystem
                (scope . snapshot)
                (snapshot . clone)
                (access . read-only))
               (cpu . 4)
               (memory . "8Gi")
               (timeout-ms . 600000))
    (metadata (intent . ci-agent) (risk . hermetic)))
   (agent/docker
    (backend docker docker-local)
    (network allowlisted "ghcr.io" "docker.io")
    (capabilities process-run filesystem-read filesystem-write tmpdir)
    (resources (filesystem
                (scope . volume)
                (materialized-by . runtime)
                (mounts . runtime)
                (access . read-write))
               (cpu . 2)
               (memory . "4Gi")
               (timeout-ms . 300000))
    (metadata (intent . container-agent) (risk . image-runtime)))))

(def agentic-ai-lab-default-sandbox-profile-names
  (agentic-ai-lab-sandbox-profile-names agentic-ai-lab-default-sandbox-profiles))

;;; Default profile presentation is a stable upstream receipt for downstream
;;; user interfaces that should not duplicate nono/cube policy recipes.
;; : (-> Unit POOObject)
(def (agentic-ai-lab-default-sandbox-profile-presentation)
  (agenticAiLabSandboxProfilesPresentation agentic-ai-lab-default-sandbox-profiles))
