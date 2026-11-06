;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :yuanxu/module-system/selection/init-syntax)
(yuanxu!
  :load-modules :agentic-ai-lab/init rename: Lab
  (ai-agentic-context +memory)
  :load-modules "./modules" mode: explicit rename: Consumer
  (review))
