;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product-owned selection; Core prepares sources without runtime activation.
(import :tao3k/yuanxu/module-system/selection/init-syntax)
(yuanxu!
  :load-modules "./core/modules" mode: explicit rename: Core
  (json-schema)
  (funflow)
  :load-modules "./modules" mode: auto
  (governance)
  (ai-agentic-context +memory)
  (my-module @ "./user-interface/custom/my-module")
  :load-modules "./scenarios" mode: explicit rename: scenarios
  (null)
  (aws-validation)
  (aws)
  (developer @ "./user-interface/scenarios/developer")
  :load-modules "./profiles" mode: explicit rename: Profiles
  (sandbox)
  (langchain @ "./user-interface/profiles/langchain")
  (langgraph @ "./user-interface/profiles/langgraph")
  (crewai @ "./user-interface/profiles/crewai")
  (tool-calling @ "./user-interface/profiles/tool-calling"))
