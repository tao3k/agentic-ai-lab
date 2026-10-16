;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: user-owned POO Flow init entrypoint.
;;; Invariant: this file lists enabled modules only; projections live upstream.

(import :core/module-system/selection/init-syntax)

;;; Doom-style init shape: module categories and optional feature patches only.
;;; Profile binding, settings, projection, package sync, export wiring, and
;;; runtime loading are upstream concerns.
(poo-flow!
 :workflow
 (funflow
  (+cicd
   (checks +parallel +typed-receipts)
   (artifacts +export)
   (release +manual-gate)
   (webhook +server)
   (runtime +manifest-handoff)))
 (loop-engine)
 :sandbox
 (nono-sandbox +nono +doctor)
 (cubeSandbox +cube +doctor)
 :custom
 (my-module @ "./custom/my-module" +private +doctor))
