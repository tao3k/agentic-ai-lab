;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: public POO-native nono sandbox profile super object.
;;; Invariant: native nono execution remains outside profile authoring.

(import (only-in :clan/poo/object .o)
        :agentic-ai-lab/modules/sandbox-core/profile-interface)

(export nono-sandbox-profile)

;;; Boundary: runtime dispatch keys stay symbolic so profile lookup can compare
;;; backend families without loading native nono runtime modules.
;; : Symbol
(def +nono-sandbox-profile-backend-kind+ 'nono)

;;; Boundary: capabilities describe the nono resource surface advertised to
;;; profile inheritance; native ABI checks happen at runtime handoff.
;; : (Listof Symbol)
(def +nono-sandbox-profile-capabilities+
  '(process-run filesystem-read tmpdir))

;;; Boundary: metadata is inert POO profile evidence, not a native call plan.
;; : Alist
(def +nono-sandbox-profile-metadata+
  '((backend . nono-sandbox)))

;;; Boundary: nono extends the shared sandbox profile by appending backend
;;; evidence while preserving parent metadata order.
;; : PooSandboxProfilePrototype
(def nono-sandbox-profile
  (.o (:: @ sandbox-profile)
  backend-kind: +nono-sandbox-profile-backend-kind+
  backend-ref: #f
  capabilities: +nono-sandbox-profile-capabilities+
  metadata: => (lambda (super-metadata)
                 (append super-metadata
                         +nono-sandbox-profile-metadata+))))
