;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :clan/poo/object "./types.ss" "./objects.ss"
        (only-in :agentic-ai-lab/modules/services/opentofu/objects agentic-ai-lab-opentofu-provider-from-directory))
(export null-scope)
(def (null-scope directory)
  (def selected-provider (agentic-ai-lab-opentofu-provider-from-directory directory))
  (unless (eq? (.get selected-provider status) 'ready)
    (error "Null provider package build required" directory))
  (def baseline Scenario)
  (.o Scenario: (.cc baseline 'provider selected-provider)
      provider: selected-provider
      types: (.o Scenario: (null-admission
                 (.get selected-provider types resources null_resource value-type)))))
