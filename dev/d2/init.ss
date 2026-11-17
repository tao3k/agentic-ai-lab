;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Development selection only. Module semantics stay in modules/d2.
(import :tao3k/yuanxu/module-system/selection/init-syntax)
(yuanxu! :load-modules "." mode: explicit rename: modules
  (d2 @ "../../modules/d2"))
