;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Product-owned selection; Core prepares sources without runtime activation.
(import :tao3k/yuanxu/module-system/selection/init-syntax)
(yuanxu!
  :build-roots ("modules/module-authoring/interface")
  :load-modules "./modules" mode: auto export: ModulesSource :test-dir "./t"
  (ai-agentic-context +memory)
  (gitops +worktrunk)
  (my-module @ "./user-interface/custom/my-module")
  :load-modules "./modules/c-abi" mode: auto mount: CAbi
  :load-modules "./scenarios" mode: explicit mount: scenarios :test-dir "./t"
  (null)
  (aws-validation)
  (aws)
  (developer @ "./user-interface/scenarios/developer")
  :load-modules "./profiles" mode: explicit mount: Profiles :test-dir "./t"
  (sandbox)
  (langchain @ "./user-interface/profiles/langchain")
  (langgraph @ "./user-interface/profiles/langgraph")
  (crewai @ "./user-interface/profiles/crewai")
  (tool-calling @ "./user-interface/profiles/tool-calling")
  :load-modules (from: :tao3k/yuanxu/init ModulesSource)
  mode: explicit mount: YuanxuModules
  (json-schema)
  (funflow))
