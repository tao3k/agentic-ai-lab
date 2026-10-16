;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: CI/CD downstream sandbox profile declarations.
;;; Invariant: standalone module; it does not execute workflows.

(import :poo-flow/modules/workflow/scenario/configuration/init-syntax)

(export poo-flow-custom-my-module-cicd-module)

(def poo-flow-custom-my-module-cicd-module
  (let ((check-capabilities
       '(process-run filesystem-read tmpdir))
      (build-capabilities
       '(process-run filesystem-read filesystem-write tmpdir cache-mount))
      (check-metadata
       '((intent . ci-check)
         (scope . cicd)
         (stage . check)))
      (build-metadata
       '((intent . ci-build)
         (scope . cicd)
         (stage . build)
         (artifacts . export)))
      (release-metadata
       '((intent . cd-release)
         (scope . cicd)
         (stage . release)
         (manual-gate . required)))
      (promote-metadata
       '((intent . artifact-promote)
         (scope . cicd)
         (stage . promote)
         (artifacts . consume))))
  (use-module nono-sandbox
    (binding native-ffi)

    (.def (ci/check @ nono-sandbox-profile)
      network: (deny-network)
      capabilities: check-capabilities
      resources: =>.+ readonly-project-workspace-resources
      metadata: => (lambda (super-metadata)
                     (append super-metadata check-metadata)))

    (.def (ci/build @ ci/check)
      network: (allowlisted-network "github.com" "crates.io")
      capabilities: build-capabilities
      resources: =>.+ readwrite-project-workspace-resources
      metadata: => (lambda (super-metadata)
                     (append super-metadata build-metadata)))

    (.def (cd/release @ ci/build)
      network: (allowlisted-network "github.com" "ghcr.io")
      resources: =>.+ readwrite-project-workspace-resources
      metadata: => (lambda (super-metadata)
                     (append super-metadata release-metadata)))

    (.def (cicd/artifact-promote @ ci/build)
      network: (allowlisted-network "artifact-store.internal" "github.com")
      resources: =>.+ readwrite-project-workspace-resources
      metadata: => (lambda (super-metadata)
                     (append super-metadata promote-metadata))))))
