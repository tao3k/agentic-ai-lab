;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product-owned selection; Core prepares sources without runtime activation.
(import :yuanxu/module-system/selection/init-syntax)
(yuanxu!
  :load-modules "./core/modules" mode: explicit rename: Core
  (json-schema)
  (funflow)
  :load-modules "./modules" mode: auto
  :load-modules "./scenarios" mode: explicit rename: scenarios
  (null)
  (aws-validation)
  (aws))
