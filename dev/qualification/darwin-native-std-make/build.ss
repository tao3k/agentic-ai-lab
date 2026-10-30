#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; One native std/make target. Keep this fixture independent of the tap and
;;; downstream build frameworks so the receipt measures Gerbil itself.

(import :std/build-script)

(defbuild-script '("probe.ss"))
