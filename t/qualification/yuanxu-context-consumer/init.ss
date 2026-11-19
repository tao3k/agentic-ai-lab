;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :tao3k/yuanxu/module-system/selection/init-syntax)
(yuanxu!
  :load-modules "../../../modules/ai-agentic-context" mode: explicit mount: Lab
  (ai-agentic-context @ "../../../modules/ai-agentic-context" +memory)
  :load-modules "./modules" mode: explicit mount: Consumer
  (review))
