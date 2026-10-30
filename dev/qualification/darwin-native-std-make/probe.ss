;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Keep the native fixed-cost probe free of external imports. Dependency
;;; freshness is a separate Scenario; mixing it here can turn every repetition
;;; into a compile and makes a warm std/make comparison invalid.

(export std-make-one-target-probe)

(def (std-make-one-target-probe)
  'ready)
