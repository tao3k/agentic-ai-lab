;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :tao3k/yuanxu/module-system/selection/init-syntax yuanxu!))

;; This consumer builds the public Lab package and the Funflow libraries
;; imported by the wheel projection in one native compiler input context.
(yuanxu!
  :load-modules "./modules" mode: explicit :test-dir "./t"
  (temporal-causality)
  :load-modules "./core/modules" mode: explicit rename: Core :test-dir "./t"
  (funflow))
