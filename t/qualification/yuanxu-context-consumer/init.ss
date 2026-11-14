;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :tao3k/yuanxu/module-system/selection/init-syntax)
(yuanxu!
  :test-dir "./t"
  :load-modules "../../../modules/ai-agentic-context" mode: explicit rename: Lab
  (ai-agentic-context @ "../../../modules/ai-agentic-context" +memory)
  :load-modules "./modules" mode: explicit rename: Consumer
  (review))
