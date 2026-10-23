;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Development/package injection only; no provider pin, fetch or source registry.
(import :clan/poo/object)
(export Config OpenTofuProviderConfig)

(.def Config
  ;; Supplied upstream as a native Nix Source, never a per-provider registry.
  source: #f
  ;; A maintained final-package flake names its demand input here. Without one,
  ;; legacy expressions/functions retain their existing argument boundary.
  selection-input: #f
  ;; Declared but inactive recipes do not demand packages. Build derives its
  ;; demand from this tree rather than maintaining a second configuration.
  services: (.o opentofu: (.o Null: #f))
  artifact: (getenv "AGENTIC_AI_LAB_OPENTOFU_ARTIFACT" #f))

;; A provider leaf is created from the collection; it has no environment input.
(.def OpenTofuProviderConfig
  provider-artifact: #f)
