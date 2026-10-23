;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Declarative Module publication; the admitted source wrapper owns imports.
(.def Nix
  identity: 'nix
  core:
  (.o requires: (.o)
      scope-contract: NixScopeContract
      exports:
      (.o config: NixConfig
          types: (.o Source: NixSourceContract
                     FlakeSource: NixFlakeSourceContract)
          prototypes: (.o Source: (.cc NixSource. 'config config)
                          FlakeSource: (.cc NixFlakeSource. 'config config))
          source-inputs: poo-flow-nix-source-inputs
          admit-generation: poo-flow-nix-admit-generation))
  features: (.o))
