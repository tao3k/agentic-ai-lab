;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def .o .cc)
        (only-in "./config.ss" NixConfig)
        (only-in "./types.ss" NixScopeContract NixConfigContract NixSourceContract NixFlakeSourceContract)
        (only-in "./objects.ss" NixSource. NixFlakeSource. agentic-ai-lab-nix-admit-generation)
        (only-in "./func.ss" agentic-ai-lab-nix-source-inputs))
(export Nix)

(.def (Nix @ [] config)
  config: NixConfig
  identity: 'nix
  tags: '(package-management)
  core:
  (.o scope-contract: NixScopeContract
      admissions: (.o Config: (.o export-path: '(config) contract-path: '(types Config)))
      exports:
      (.o config: NixConfig
          types: (.o Config: NixConfigContract
                     Source: NixSourceContract
                     FlakeSource: NixFlakeSourceContract)
          prototypes: (.o Config: NixConfigContract
                     Source: (.cc NixSource. 'config config)
                          FlakeSource: (.cc NixFlakeSource. 'config config))
          source-inputs: agentic-ai-lab-nix-source-inputs
          admit-generation: agentic-ai-lab-nix-admit-generation))
  features: (.o))
