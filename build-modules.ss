;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; The catalog is eligible for explicit --modules requests. build.ss supplies
;;; an empty root request for installation, using the same build projection.
(import :tao3k/yuanxu/module-system/selection/init-syntax)
(yuanxu! source: "./modules" mode: auto)
