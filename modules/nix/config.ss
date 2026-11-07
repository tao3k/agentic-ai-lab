;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import (only-in :clan/poo/object .def)
        (only-in :std/source this-source-file))
(export NixConfig)
(.def NixConfig
  nix: "nix"
  instantiate: "nix-instantiate"
  realize: "nix-store"
  source-checker: (path-expand "source-inputs.nix" (path-directory (this-source-file))))
