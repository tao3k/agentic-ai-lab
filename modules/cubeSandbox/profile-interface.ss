;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public POO-native CubeSandbox profile super object.
;;; Invariant: CubeSandbox execution remains a runtime handoff concern.

(import (only-in :clan/poo/object .o)
        :agentic-ai-lab/modules/sandbox-core/profile-interface)

(export cubeSandbox-profile)

;;; Boundary: runtime dispatch keys stay symbolic so profile lookup can compare
;;; backend families without loading CubeSandbox lifecycle modules.
;; : Symbol
(def +cubeSandbox-profile-backend-kind+ 'cube)

;;; Boundary: capabilities describe the CubeSandbox resource surface advertised
;;; to profile inheritance; lifecycle support validates concrete runtime plans.
;; : (Listof Symbol)
(def +cubeSandbox-profile-capabilities+
  '(process-run filesystem-read tmpdir))

;;; Boundary: metadata is inert POO profile evidence, not a Cube lifecycle plan.
;; : Alist
(def +cubeSandbox-profile-metadata+
  '((backend . cubeSandbox)))

;;; Boundary: CubeSandbox extends the shared sandbox profile by appending backend
;;; evidence while preserving parent metadata order.
;; : PooSandboxProfilePrototype
(def cubeSandbox-profile
  (.o (:: @ sandbox-profile)
  backend-kind: +cubeSandbox-profile-backend-kind+
  backend-ref: #f
  capabilities: +cubeSandbox-profile-capabilities+
  metadata: => (lambda (super-metadata)
                 (append super-metadata
                         +cubeSandbox-profile-metadata+))))
