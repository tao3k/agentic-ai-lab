;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Local configuration ownership; shared protocols belong to the package kernel.
(import (only-in :clan/poo/type Record String)
        (only-in :agentic-ai-lab/nix-contracts
                 NixSourceContract NixFlakeSourceContract NixScopeContract))
(export NixConfigContract NixSourceContract NixFlakeSourceContract NixScopeContract)
(def NixConfigContract
  (Record nix: (list String) instantiate: (list String)
          realize: (list String) source-checker: (list String)))
