;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: packaged Python runtime projection smoke value.
;;; This file is included as one expression by the Bazel/Python projection
;;; adapters.  Root declaration belongs to user configuration; adapters project
;;; the same ProfileBundle value without introducing a top-level binding.

(agentic-ai-lab-profile-bundle-root
 'wheel-smoke
  (compose profiles
    (use-module FunflowProfileModule as ff github-ci python-anyio)
    WheelSmokeScenarioProfile))
