;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
(import :std/test :agentic-ai-lab/bindings/nix-c-api/binding "./cases.ss" "./flake-cases.ss")
(export embedding-test flake-test)
(def embedding-test
  (nix-api-suite call-with-nix-session session-query session-calls))
(def flake-test
  (flake-api-suite call-with-flake-session session-query session-calls))
