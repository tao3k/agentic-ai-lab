;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public POO-native Docker sandbox profile super object.
;;; Invariant: container execution remains a runtime handoff concern.

(import (only-in :clan/poo/object .o)
        :agentic-ai-lab/modules/sandbox-core/profile-interface)

(export docker-sandbox-profile)

;;; Boundary: runtime dispatch keys stay symbolic so profile lookup can compare
;;; backend families without loading Docker-specific runtime modules.
;; : Symbol
(def +docker-sandbox-profile-backend-kind+ 'docker)

;;; Boundary: capabilities enumerate the sandbox resource surface advertised to
;;; profile inheritance; runtime code must validate concrete mounts later.
;; : (Listof Symbol)
(def +docker-sandbox-profile-capabilities+
  '(process-run filesystem-read filesystem-write tmpdir))

;;; Boundary: metadata is inert POO profile evidence, not an execution request.
;; : Alist
(def +docker-sandbox-profile-metadata+
  '((backend . docker-sandbox)))

;;; Boundary: Docker extends the shared sandbox profile by appending backend
;;; evidence while preserving parent metadata order.
;; : PooSandboxProfilePrototype
(def docker-sandbox-profile
  (.o (:: @ sandbox-profile)
  backend-kind: +docker-sandbox-profile-backend-kind+
  backend-ref: #f
  capabilities: +docker-sandbox-profile-capabilities+
  metadata: => (lambda (super-metadata)
                 (append super-metadata
                         +docker-sandbox-profile-metadata+))))
