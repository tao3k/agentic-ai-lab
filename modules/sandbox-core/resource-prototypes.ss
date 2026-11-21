;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: canonical POO resource prototypes shared by sandbox contracts.

(import (only-in :clan/poo/object .def))

(export #t)

;;; Runtime resources are modeled as a first-class POO object so backend
;;; profiles can extend concrete slots without reintroducing ad hoc alists.
;; : PooSandboxFilesystemPrototype
(.def agentic-ai-lab-runtime-filesystem-prototype
  scope: 'runtime
  materialized-by: 'runtime
  mounts: 'runtime)

;; : PooSandboxFilesystemPrototype
(.def agentic-ai-lab-runtime-volume-filesystem-prototype
  scope: 'volume
  materialized-by: 'runtime
  mounts: 'runtime)

;; : PooSandboxFilesystemPrototype
(.def agentic-ai-lab-snapshot-filesystem-prototype
  scope: 'snapshot
  snapshot: 'clone)

;; : PooSandboxResourcesPrototype
(.def agentic-ai-lab-runtime-filesystem-resources-prototype
  filesystem: agentic-ai-lab-runtime-filesystem-prototype
  cpu: 2
  memory: "4Gi")
;; : PooSandboxResourcesPrototype
(.def agentic-ai-lab-runtime-volume-resources-prototype
  filesystem: agentic-ai-lab-runtime-volume-filesystem-prototype
  cpu: 2
  memory: "4Gi")

;; : PooSandboxResourcesPrototype
(.def agentic-ai-lab-snapshot-resources-prototype
  filesystem: agentic-ai-lab-snapshot-filesystem-prototype
  cpu: 2
  memory: "4Gi")

;; : PooSandboxResourcesPrototype
(.def agentic-ai-lab-runtime-volume-ports-resources-prototype
  filesystem: agentic-ai-lab-runtime-volume-filesystem-prototype
  ports: '((scope . runtime)
           (published-by . runtime))
  cpu: 2
  memory: "4Gi")
