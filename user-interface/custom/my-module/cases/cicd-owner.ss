;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Boundary: focused custom CI/CD and introspection scenario owner.
;;; Invariant: scenario declarations stay separate from the full custom module
;;; facade so tests and imports do not compile every user-interface case.

(import "../profiles/all"
        "cicd"
        "funflow-cicd"
        "poo-introspection")

(export agentic-ai-lab-custom-my-module-cicd-module
        (import: "cicd")
        (import: "funflow-cicd")
        (import: "poo-introspection"))
